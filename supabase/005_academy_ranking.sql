-- FourLab Academy · Turma Fundadora, artigos lidos, quiz e ranking
alter table public.academy_profiles
  add column if not exists origem text,
  add column if not exists fundador_num int unique;

-- grava a origem do cadastro (?evento=...) vinda do site
create or replace function public.academy_handle_signup() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.raw_user_meta_data->>'app','') <> 'academy' then return new; end if;
  insert into academy_profiles (id, nome, email, profissao, conselho, registro, cidade, uf, modalidade, origem)
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
    new.raw_user_meta_data->>'origem'
  ) on conflict (id) do nothing;
  return new;
end $$;

-- número de fundador: dado na aprovação; o próprio usuário não altera (roda por último)
create or replace function public.academy_fundador() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not coalesce(academy_my_role() in ('comercial','admin'), false) and auth.uid() is not null then
    new.origem := old.origem; new.fundador_num := old.fundador_num;
  end if;
  if new.status = 'aprovado' and old.status is distinct from 'aprovado'
     and new.origem = 'endurance-applied' and new.fundador_num is null then
    perform pg_advisory_xact_lock(hashtext('academy_fundador'));
    select coalesce(max(fundador_num), 0) + 1 into new.fundador_num from academy_profiles;
  end if;
  return new;
end $$;
drop trigger if exists zz_fundador on public.academy_profiles;
create trigger zz_fundador before update on public.academy_profiles
  for each row execute function public.academy_fundador();

create table if not exists public.academy_artigos_lidos (
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  artigo_id uuid not null references public.academy_artigos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, artigo_id)
);
alter table public.academy_artigos_lidos enable row level security;
drop policy if exists l_own on public.academy_artigos_lidos;
create policy l_own on public.academy_artigos_lidos for all
  using (user_id = auth.uid() and academy_is_approved())
  with check (user_id = auth.uid() and academy_is_approved());

create table if not exists public.academy_quiz (
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  quiz text not null,
  acertos int not null,
  total int not null,
  created_at timestamptz not null default now(),
  primary key (user_id, quiz)
);
alter table public.academy_quiz enable row level security;
drop policy if exists q_read on public.academy_quiz;
create policy q_read on public.academy_quiz for select using (user_id = auth.uid() or academy_is_staff());

-- corrige no servidor (o gabarito não vai para o navegador); vale só a primeira tentativa
create or replace function public.academy_quiz_enviar(respostas int[])
returns table (acertos int, total int) language plpgsql security definer set search_path = public as $$
declare gab int[] := array[1,0,2,1,0]; n int := 0;
begin
  if not academy_is_approved() then raise exception 'sem acesso'; end if;
  for i in 1..array_length(gab,1) loop
    if respostas[i] = gab[i] then n := n + 1; end if;
  end loop;
  insert into academy_quiz (user_id, quiz, acertos, total)
  values (auth.uid(), 'evento-2026', n, array_length(gab,1)) on conflict do nothing;
  return query select q.acertos, q.total from academy_quiz q where q.user_id = auth.uid() and q.quiz = 'evento-2026';
end $$;
revoke all on function public.academy_quiz_enviar(int[]) from public, anon;
grant execute on function public.academy_quiz_enviar(int[]) to authenticated;

-- aula concluída 50 · artigo lido 10 · acerto no quiz 10; expõe só primeiro nome + inicial
create or replace function public.academy_ranking()
returns table (user_id uuid, nome text, fundador_num int, pontos bigint)
language sql stable security definer set search_path = public as $$
  select p.id,
    split_part(p.nome,' ',1) || coalesce(' ' || nullif(left(split_part(p.nome,' ',2),1),'') || '.', ''),
    p.fundador_num,
    (select count(*) * 50 from academy_progresso x where x.user_id = p.id and x.concluida)
    + (select count(*) * 10 from academy_artigos_lidos x where x.user_id = p.id)
    + coalesce((select sum(x.acertos) * 10 from academy_quiz x where x.user_id = p.id), 0)
  from academy_profiles p
  where academy_is_approved() and p.status = 'aprovado' and p.role = 'prescritor'
  order by 4 desc, p.nome limit 100
$$;
revoke all on function public.academy_ranking() from public, anon;
grant execute on function public.academy_ranking() to authenticated;
