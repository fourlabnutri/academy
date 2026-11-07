-- Liberação aula a aula (1ª na sexta 13/11, depois toda quinta)
alter table public.academy_aulas add column if not exists libera_em timestamptz;

with t as (select id, slug from academy_trilhas),
a as (
  select au.id, t.slug, row_number() over (partition by au.trilha_id order by au.ordem) n
  from academy_aulas au join t on t.id = au.trilha_id
)
update academy_aulas x set libera_em = case
  when a.slug = 'carboidratos-endurance' and a.n = 1 then timestamptz '2026-11-19 08:00-03'
  when a.slug = 'carboidratos-endurance' and a.n = 2 then timestamptz '2026-11-26 08:00-03'
  when a.slug = 'hidratacao-eletrolitos' and a.n = 1 then timestamptz '2026-12-03 08:00-03'
  when a.slug = 'hidratacao-eletrolitos' and a.n = 2 then timestamptz '2026-12-10 08:00-03'
  when a.slug = 'hidratacao-eletrolitos' and a.n = 3 then timestamptz '2026-12-17 08:00-03'
end
from a where a.id = x.id and x.libera_em is null;

create or replace function public.academy_aula_liberada(l timestamptz) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(l <= now(), academy_aulas_liberadas())
$$;

drop policy if exists c_read on public.academy_aulas;
create policy c_read on public.academy_aulas for select using (
  (etapa = 'publicado' and academy_is_approved() and academy_aula_liberada(libera_em)) or academy_is_staff());

drop policy if exists c_read on public.academy_trilhas;
create policy c_read on public.academy_trilhas for select using (
  (etapa = 'publicado' and academy_is_approved() and exists (
     select 1 from academy_aulas a where a.trilha_id = academy_trilhas.id and a.etapa = 'publicado' and academy_aula_liberada(a.libera_em)))
  or academy_is_staff());

drop policy if exists f_read on public.academy_forum_topicos;
create policy f_read on public.academy_forum_topicos for select using (
  academy_is_approved() and (aula_id is null or exists (select 1 from academy_aulas a where a.id = aula_id)));

-- Cronograma visível para todos os cadastrados (títulos e datas, mesmo antes de liberar)
create or replace function public.academy_cronograma()
returns table (trilha_slug text, trilha_titulo text, trilha_ordem int, professor text, aula_id uuid, aula_titulo text, aula_ordem int, libera_em timestamptz, liberada boolean)
language sql stable security definer set search_path = public as $$
  select t.slug, t.titulo, t.ordem, a.professor, a.id, a.titulo, a.ordem, a.libera_em, academy_aula_liberada(a.libera_em)
  from academy_aulas a join academy_trilhas t on t.id = a.trilha_id
  where academy_is_approved() and a.etapa = 'publicado' and t.etapa = 'publicado'
  order by t.ordem, a.ordem
$$;
grant execute on function public.academy_cronograma() to authenticated;
