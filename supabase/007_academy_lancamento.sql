-- FourLab Academy · lançamento: acesso imediato, membros fundadores, aula inaugural ao vivo e chat
insert into public.academy_config values ('fundador_ate', '2026-11-08 00:00:00-03') on conflict (chave) do update set valor = excluded.valor;

create or replace function public.academy_fundador_aberto() returns boolean
language sql stable security definer set search_path = public as $$
  select now() < (select valor::timestamptz from academy_config where chave = 'fundador_ate')
$$;

-- cadastro entra aprovado; quem se cadastra até o prazo recebe o número de fundador
create or replace function public.academy_handle_signup() returns trigger
language plpgsql security definer set search_path = public as $$
declare num int;
begin
  if coalesce(new.raw_user_meta_data->>'app','') <> 'academy' then return new; end if;
  if academy_fundador_aberto() then
    perform pg_advisory_xact_lock(hashtext('academy_fundador'));
    select coalesce(max(fundador_num), 0) + 1 into num from academy_profiles;
  end if;
  insert into academy_profiles (id, nome, email, profissao, conselho, registro, cidade, uf, modalidade, origem, status, aprovado_em, fundador_num)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome',''), split_part(new.email,'@',1)),
    new.email,
    new.raw_user_meta_data->>'profissao',
    new.raw_user_meta_data->>'conselho',
    new.raw_user_meta_data->>'registro',
    new.raw_user_meta_data->>'cidade',
    new.raw_user_meta_data->>'uf',
    new.raw_user_meta_data->>'modalidade',
    new.raw_user_meta_data->>'origem',
    'aprovado', now(), num
  ) on conflict (id) do nothing;
  return new;
end $$;

create or replace function public.academy_fundador() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not coalesce(academy_my_role() in ('comercial','admin'), false) and auth.uid() is not null then
    new.origem := old.origem; new.fundador_num := old.fundador_num;
  end if;
  if new.status = 'aprovado' and old.status is distinct from 'aprovado'
     and new.role = 'prescritor' and new.fundador_num is null and academy_fundador_aberto() then
    perform pg_advisory_xact_lock(hashtext('academy_fundador'));
    select coalesce(max(fundador_num), 0) + 1 into new.fundador_num from academy_profiles;
  end if;
  return new;
end $$;

-- e-mail de boas-vindas no lugar de "cadastro recebido"
create or replace function public.academy_email_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare nome1 text := split_part(coalesce(new.nome, ''), ' ', 1);
        btn text := '<a href="https://academy.fourlabnutrition.com.br/login" style="display:inline-block;margin-top:12px;background:#e96709;color:#fff;text-decoration:none;font-weight:700;padding:12px 22px;border-radius:999px">Acessar o Academy</a>';
begin
  if new.role <> 'prescritor' then return new; end if;
  if tg_op = 'INSERT' then
    perform academy_send_email(new.email, 'Bem-vindo(a) ao FourLab Academy',
      'Olá, ' || nome1 || '!<br><br>Seu acesso está liberado.'
      || case when new.fundador_num is not null then ' Você é o membro fundador nº ' || new.fundador_num || '.' else '' end
      || '<br>' || btn);
  elsif new.status is distinct from old.status and new.status = 'aprovado' then
    perform academy_send_email(new.email, 'Seu acesso ao FourLab Academy foi liberado',
      'Olá, ' || nome1 || '!<br><br>Seu acesso está liberado.<br>' || btn);
  elsif new.status is distinct from old.status and new.status = 'recusado' then
    perform academy_send_email(new.email, 'Sobre seu cadastro no FourLab Academy',
      'Olá, ' || nome1 || '.<br><br>Não conseguimos validar seu registro profissional. '
      || coalesce(new.motivo_recusa, '') || '<br><br>Se achar que houve um engano, fale com a equipe FourLab que conferimos de novo.');
  end if;
  return new;
end $$;

-- quem já estava pendente entra agora (a trava de perfil bloquearia a mudança no SQL Editor)
alter table public.academy_profiles disable trigger t_guard;
update public.academy_profiles set status = 'aprovado', aprovado_em = now() where status = 'pendente' and role = 'prescritor';
alter table public.academy_profiles enable trigger t_guard;

-- aula inaugural: uma única linha, editada em admin/live
create table if not exists public.academy_live (
  id boolean primary key default true check (id),
  titulo text not null default 'Aula inaugural',
  professor text not null default 'Marcelo de Carvalho',
  inicio timestamptz,
  yt_id text,
  chat_aberto boolean not null default false,
  aulas_liberam_em timestamptz
);
insert into public.academy_live (id) values (true) on conflict do nothing;
alter table public.academy_live enable row level security;
drop policy if exists lv_read on public.academy_live;
create policy lv_read on public.academy_live for select using (academy_is_approved());
drop policy if exists lv_write on public.academy_live;
create policy lv_write on public.academy_live for update using (academy_is_staff()) with check (academy_is_staff());

-- aulas, trilhas e debates das aulas só aparecem depois da data de liberação (equipe vê tudo)
create or replace function public.academy_aulas_liberadas() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select aulas_liberam_em <= now() from academy_live), false)
$$;
drop policy if exists c_read on public.academy_trilhas;
create policy c_read on public.academy_trilhas for select using ((etapa = 'publicado' and academy_is_approved() and academy_aulas_liberadas()) or academy_is_staff());
drop policy if exists c_read on public.academy_aulas;
create policy c_read on public.academy_aulas for select using ((etapa = 'publicado' and academy_is_approved() and academy_aulas_liberadas()) or academy_is_staff());
drop policy if exists f_read on public.academy_forum_topicos;
create policy f_read on public.academy_forum_topicos for select using (academy_is_approved() and (aula_id is null or academy_aulas_liberadas()));

-- chat da live
create table if not exists public.academy_live_chat (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.academy_profiles(id) on delete set null,
  autor_nome text not null default '',
  oficial boolean not null default false,
  fundador boolean not null default false,
  corpo text not null check (length(corpo) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists academy_live_chat_t on public.academy_live_chat (created_at desc);
create table if not exists public.academy_live_bloqueados (
  user_id uuid primary key references public.academy_profiles(id) on delete cascade
);
alter table public.academy_live_chat enable row level security;
alter table public.academy_live_bloqueados enable row level security;
drop policy if exists lb_staff on public.academy_live_bloqueados;
create policy lb_staff on public.academy_live_bloqueados for all using (academy_is_staff()) with check (academy_is_staff());
drop policy if exists lc_read on public.academy_live_chat;
create policy lc_read on public.academy_live_chat for select using (academy_is_approved());
drop policy if exists lc_ins on public.academy_live_chat;
create policy lc_ins on public.academy_live_chat for insert with check (academy_is_approved() and user_id = auth.uid());
drop policy if exists lc_del on public.academy_live_chat;
create policy lc_del on public.academy_live_chat for delete using (academy_is_staff());

-- autor preenchido no servidor; respeita chat aberto, bloqueio e 1 mensagem a cada 2 segundos
create or replace function public.academy_live_chat_autor() returns trigger
language plpgsql security definer set search_path = public as $$
declare pf academy_profiles;
begin
  select * into pf from academy_profiles where id = auth.uid();
  if pf.role = 'prescritor' then
    if not (select chat_aberto from academy_live) then raise exception 'chat fechado'; end if;
    if exists (select 1 from academy_live_bloqueados where user_id = pf.id) then raise exception 'bloqueado'; end if;
    if exists (select 1 from academy_live_chat where user_id = pf.id and created_at > now() - interval '2 seconds') then raise exception 'aguarde'; end if;
  end if;
  new.oficial := pf.role <> 'prescritor';
  new.fundador := pf.fundador_num is not null;
  new.autor_nome := split_part(pf.nome,' ',1) || coalesce(' ' || nullif(left(split_part(pf.nome,' ',2),1),'') || '.', '');
  new.created_at := now();
  return new;
end $$;
drop trigger if exists t_autor on public.academy_live_chat;
create trigger t_autor before insert on public.academy_live_chat for each row execute function public.academy_live_chat_autor();

do $$ begin
  alter publication supabase_realtime add table public.academy_live_chat;
exception when duplicate_object then null; end $$;
