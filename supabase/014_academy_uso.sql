-- Rastreamento de uso: acessos, páginas, cliques e tempo ativo
create table if not exists public.academy_uso (
  id bigserial primary key,
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  sessao text not null,
  tipo text not null check (tipo in ('view','click','tempo')),
  pagina text not null,
  alvo text,
  seg int not null default 0,
  disp text,
  created_at timestamptz not null default now()
);
create index if not exists uso_user_dt on public.academy_uso (user_id, created_at desc);
create index if not exists uso_dt on public.academy_uso (created_at desc);
alter table public.academy_uso enable row level security;
drop policy if exists u_ins on public.academy_uso;
create policy u_ins on public.academy_uso for insert with check (user_id = auth.uid() and seg between 0 and 120);
drop policy if exists u_read on public.academy_uso;
create policy u_read on public.academy_uso for select using (academy_is_staff());

-- Resumo para o painel (só equipe). d = últimos N dias. Conta apenas prescritores.
create or replace function public.academy_uso_resumo(d int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ini timestamptz := now() - make_interval(days => d); r jsonb;
begin
  if not academy_is_staff() then raise exception 'sem permissão'; end if;
  with u as (
    select x.* from academy_uso x join academy_profiles p on p.id = x.user_id
    where p.role = 'prescritor' and x.created_at >= ini
  ), pr as (select id from academy_profiles where role = 'prescritor' and status = 'aprovado')
  select jsonb_build_object(
    'kpi', jsonb_build_object(
      'hoje', (select count(distinct user_id) from u where created_at >= date_trunc('day', now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo'),
      'semana', (select count(distinct user_id) from u where created_at >= now() - interval '7 days'),
      'periodo', (select count(distinct user_id) from u),
      'base', (select count(*) from pr),
      'sessoes', (select count(distinct sessao) from u),
      'min_total', (select coalesce(sum(seg),0)/60 from u where tipo='tempo'),
      'min_sessao', (select coalesce(round(avg(s)/60.0,1),0) from (select sum(seg) s from u where tipo='tempo' group by sessao) z),
      'mobile', (select count(distinct sessao) from u where disp='mobile')),
    'dias', (select coalesce(jsonb_agg(z order by z.dia),'[]') from (
       select (created_at at time zone 'America/Sao_Paulo')::date dia, count(distinct user_id) usuarios, coalesce(sum(seg) filter (where tipo='tempo'),0)/60 min
       from u group by 1) z),
    'horas', (select coalesce(jsonb_agg(z order by z.h),'[]') from (
       select extract(hour from created_at at time zone 'America/Sao_Paulo')::int h, count(distinct sessao) n from u where tipo='view' group by 1) z),
    'paginas', (select coalesce(jsonb_agg(z order by z.views desc),'[]') from (
       select pagina, count(*) filter (where tipo='view') views, count(distinct user_id) usuarios, coalesce(sum(seg) filter (where tipo='tempo'),0)/60 min
       from u group by pagina) z),
    'cliques', (select coalesce(jsonb_agg(z order by z.n desc),'[]') from (
       select pagina, alvo, count(*) n, count(distinct user_id) usuarios from u where tipo='click' and alvo is not null
       group by pagina, alvo order by count(*) desc limit 40) z),
    'funil', jsonb_build_object(
      'cadastrados', (select count(*) from pr),
      'acessaram', (select count(distinct x.user_id) from academy_uso x join pr on pr.id = x.user_id),
      'assistiram', (select count(distinct x.user_id) from academy_progresso x join pr on pr.id = x.user_id where x.segundos_assistidos > 0 or x.concluida),
      'concluiram', (select count(distinct x.user_id) from academy_progresso x join pr on pr.id = x.user_id where x.concluida),
      'leram', (select count(distinct x.user_id) from academy_artigos_lidos x join pr on pr.id = x.user_id),
      'forum', (select count(distinct user_id) from (select user_id from academy_forum_respostas union select user_id from academy_forum_topicos) f join pr on pr.id = f.user_id)),
    'pessoas', (select coalesce(jsonb_agg(z order by z.ultimo desc nulls last),'[]') from (
       select p.id, p.nome, p.email, p.fundador_num, p.cidade, p.uf, p.created_at cadastro,
         (select max(created_at) from academy_uso x where x.user_id = p.id) ultimo,
         (select count(distinct (created_at at time zone 'America/Sao_Paulo')::date) from academy_uso x where x.user_id = p.id) dias,
         (select count(distinct sessao) from academy_uso x where x.user_id = p.id) sessoes,
         (select coalesce(sum(seg),0)/60 from academy_uso x where x.user_id = p.id and tipo='tempo') min,
         (select count(*) from academy_progresso x where x.user_id = p.id and x.concluida) aulas,
         (select count(*) from academy_artigos_lidos x where x.user_id = p.id) artigos,
         (select count(*) from academy_forum_respostas x where x.user_id = p.id) + (select count(*) from academy_forum_topicos x where x.user_id = p.id) posts
       from academy_profiles p where p.role = 'prescritor' and p.status = 'aprovado') z)
  ) into r;
  return r;
end $$;
revoke all on function public.academy_uso_resumo(int) from public, anon;
grant execute on function public.academy_uso_resumo(int) to authenticated;
