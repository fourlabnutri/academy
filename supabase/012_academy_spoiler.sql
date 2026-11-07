-- Spoiler do Módulo 1: pergunta rápida que destrava o vídeo (+10 pontos)
create table if not exists public.academy_pesquisa (
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  chave text not null,
  resposta text not null check (length(resposta) between 1 and 300),
  created_at timestamptz not null default now(),
  primary key (user_id, chave)
);
alter table public.academy_pesquisa enable row level security;
drop policy if exists ps_ins on public.academy_pesquisa;
create policy ps_ins on public.academy_pesquisa for insert with check (user_id = auth.uid() and academy_is_approved());
drop policy if exists ps_read on public.academy_pesquisa;
create policy ps_read on public.academy_pesquisa for select using (user_id = auth.uid() or academy_is_staff());

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
    + (select count(*) * 10 from academy_pesquisa x where x.user_id = p.id)
  from academy_profiles p
  where academy_is_approved() and p.status = 'aprovado' and p.role = 'prescritor'
  order by 4 desc, p.nome limit 100
$$;
revoke all on function public.academy_ranking() from public, anon;
grant execute on function public.academy_ranking() to authenticated;
