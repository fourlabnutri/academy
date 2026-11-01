-- FourLab Academy · fórum, avisos por e-mail e pontos de participação
create table if not exists public.academy_config (chave text primary key, valor text);
alter table public.academy_config enable row level security;
insert into public.academy_config values ('email_forum', 'TROCAR@EMAIL') on conflict do nothing;

create table if not exists public.academy_forum_topicos (
  id uuid primary key default gen_random_uuid(),
  categoria text not null check (categoria in ('debate','caso','duvida','fourlab')),
  titulo text not null check (length(titulo) between 3 and 160),
  corpo text not null check (length(corpo) between 1 and 8000),
  aula_id uuid unique references public.academy_aulas(id) on delete set null,
  user_id uuid references public.academy_profiles(id) on delete set null,
  autor_nome text not null default 'Equipe FourLab',
  oficial boolean not null default false,
  fixado boolean not null default false,
  respostas int not null default 0,
  ultima_em timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create table if not exists public.academy_forum_respostas (
  id uuid primary key default gen_random_uuid(),
  topico_id uuid not null references public.academy_forum_topicos(id) on delete cascade,
  user_id uuid references public.academy_profiles(id) on delete set null,
  autor_nome text not null default 'Equipe FourLab',
  oficial boolean not null default false,
  destaque boolean not null default false,
  corpo text not null check (length(corpo) between 1 and 8000),
  created_at timestamptz not null default now()
);
create index if not exists academy_forum_resp_t on public.academy_forum_respostas (topico_id, created_at);

alter table public.academy_forum_topicos enable row level security;
alter table public.academy_forum_respostas enable row level security;
drop policy if exists f_read on public.academy_forum_topicos;
create policy f_read on public.academy_forum_topicos for select using (academy_is_approved());
drop policy if exists f_ins on public.academy_forum_topicos;
create policy f_ins on public.academy_forum_topicos for insert with check (academy_is_approved() and user_id = auth.uid());
drop policy if exists f_staff on public.academy_forum_topicos;
create policy f_staff on public.academy_forum_topicos for all using (academy_is_staff()) with check (academy_is_staff());
drop policy if exists r_read on public.academy_forum_respostas;
create policy r_read on public.academy_forum_respostas for select using (academy_is_approved());
drop policy if exists r_ins on public.academy_forum_respostas;
create policy r_ins on public.academy_forum_respostas for insert with check (academy_is_approved() and user_id = auth.uid());
drop policy if exists r_staff on public.academy_forum_respostas;
create policy r_staff on public.academy_forum_respostas for all using (academy_is_staff()) with check (academy_is_staff());

-- preenche o autor no servidor (o navegador não define nome nem selo oficial)
create or replace function public.academy_forum_autor() returns trigger
language plpgsql security definer set search_path = public as $$
declare pf academy_profiles;
begin
  select * into pf from academy_profiles where id = auth.uid();
  if pf.id is null then return new; end if;
  new.oficial := pf.role <> 'prescritor';
  new.autor_nome := split_part(pf.nome,' ',1) || coalesce(' ' || nullif(left(split_part(pf.nome,' ',2),1),'') || '.', '')
    || case when pf.role <> 'prescritor' then ' · Equipe FourLab' else coalesce(' · ' || pf.profissao, '') end;
  if tg_table_name = 'academy_forum_respostas' then new.destaque := false; end if;
  return new;
end $$;
drop trigger if exists t_autor on public.academy_forum_topicos;
create trigger t_autor before insert on public.academy_forum_topicos for each row execute function public.academy_forum_autor();
drop trigger if exists t_autor on public.academy_forum_respostas;
create trigger t_autor before insert on public.academy_forum_respostas for each row execute function public.academy_forum_autor();

create or replace function public.academy_txt(t text) returns text language sql immutable as $$
  select replace(replace(replace(replace(coalesce(t,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),chr(10),'<br>')
$$;

-- avisos: mensagem para a FourLab vai ao e-mail da equipe; resposta avisa o autor do tópico
create or replace function public.academy_forum_aviso_topico() returns trigger
language plpgsql security definer set search_path = public as $$
declare dest text;
begin
  select valor into dest from academy_config where chave = 'email_forum';
  if new.categoria = 'fourlab' and dest not like 'TROCAR%' then
    perform academy_send_email(dest, 'Nova mensagem no Academy: ' || new.titulo,
      '<b>' || academy_txt(new.autor_nome) || '</b> escreveu para a FourLab:<br><br>' || academy_txt(new.corpo)
      || '<br><br><a style="color:#e96709" href="https://academy.fourlabnutrition.com.br/topico?id=' || new.id || '">Responder no fórum</a>');
  end if;
  return new;
end $$;
drop trigger if exists t_aviso on public.academy_forum_topicos;
create trigger t_aviso after insert on public.academy_forum_topicos for each row execute function public.academy_forum_aviso_topico();

create or replace function public.academy_forum_aviso_resposta() returns trigger
language plpgsql security definer set search_path = public as $$
declare t academy_forum_topicos; dest text; autor text;
begin
  update academy_forum_topicos set respostas = respostas + 1, ultima_em = now() where id = new.topico_id returning * into t;
  select valor into dest from academy_config where chave = 'email_forum';
  if t.categoria = 'fourlab' and not new.oficial and dest not like 'TROCAR%' then
    perform academy_send_email(dest, 'Nova resposta no Academy: ' || t.titulo,
      '<b>' || academy_txt(new.autor_nome) || '</b>:<br><br>' || academy_txt(new.corpo)
      || '<br><br><a style="color:#e96709" href="https://academy.fourlabnutrition.com.br/topico?id=' || t.id || '">Abrir tópico</a>');
  end if;
  if t.user_id is not null and t.user_id is distinct from new.user_id then
    select email into autor from academy_profiles where id = t.user_id;
    if autor is not null then
      perform academy_send_email(autor, 'Responderam seu tópico: ' || t.titulo,
        '<b>' || academy_txt(new.autor_nome) || '</b> respondeu:<br><br>' || academy_txt(new.corpo)
        || '<br><br><a style="color:#e96709" href="https://academy.fourlabnutrition.com.br/topico?id=' || t.id || '">Ver no fórum</a>');
    end if;
  end if;
  return new;
end $$;
drop trigger if exists t_aviso on public.academy_forum_respostas;
create trigger t_aviso after insert on public.academy_forum_respostas for each row execute function public.academy_forum_aviso_resposta();

-- toda aula publicada abre um debate automaticamente
create or replace function public.academy_forum_aula() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.etapa = 'publicado' then
    insert into academy_forum_topicos (categoria, titulo, corpo, aula_id, oficial)
    values ('debate', 'Debate: ' || new.titulo,
      'Assistiu à aula? Conte como você aplicaria isso no consultório e deixe aqui suas dúvidas. A equipe FourLab acompanha este debate.',
      new.id, true)
    on conflict (aula_id) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists t_debate on public.academy_aulas;
create trigger t_debate after insert or update of etapa on public.academy_aulas for each row execute function public.academy_forum_aula();
insert into academy_forum_topicos (categoria, titulo, corpo, aula_id, oficial)
select 'debate', 'Debate: ' || a.titulo, 'Assistiu à aula? Conte como você aplicaria isso no consultório e deixe aqui suas dúvidas. A equipe FourLab acompanha este debate.', a.id, true
from academy_aulas a where a.etapa = 'publicado' on conflict (aula_id) do nothing;

-- pontos: resposta 10 (máx. 3 por dia), resposta destacada +30
create or replace function public.academy_ranking()
returns table (user_id uuid, nome text, fundador_num int, pontos bigint)
language sql stable security definer set search_path = public as $$
  select p.id,
    split_part(p.nome,' ',1) || coalesce(' ' || nullif(left(split_part(p.nome,' ',2),1),'') || '.', ''),
    p.fundador_num,
    (select count(*) * 50 from academy_progresso x where x.user_id = p.id and x.concluida)
    + (select count(*) * 10 from academy_artigos_lidos x where x.user_id = p.id)
    + coalesce((select sum(x.acertos) * 10 from academy_quiz x where x.user_id = p.id), 0)
    + coalesce((select sum(least(d.n, 3)) * 10 from (select count(*) n from academy_forum_respostas x where x.user_id = p.id group by x.created_at::date) d), 0)
    + (select count(*) * 30 from academy_forum_respostas x where x.user_id = p.id and x.destaque)
  from academy_profiles p
  where academy_is_approved() and p.status = 'aprovado' and p.role = 'prescritor'
  order by 4 desc, p.nome limit 100
$$;
