-- Modo demonstração: um perfil pode "viver" numa data futura (para gravar vídeo)
alter table public.academy_profiles add column if not exists demo_agora timestamptz;

create or replace function public.academy_agora() returns timestamptz
language sql stable security definer set search_path = public as $$
  select coalesce((select demo_agora from academy_profiles where id = auth.uid()), now())
$$;

create or replace function public.academy_aulas_liberadas() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select aulas_liberam_em <= academy_agora() from academy_live), false)
$$;

create or replace function public.academy_aula_liberada(l timestamptz) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(l <= academy_agora(), academy_aulas_liberadas())
$$;

-- Wal (membro fundador nº 2) vê o Academy como em 11/12: aula inaugural feita,
-- 2 aulas do Paulo e 2 da Juliana liberadas, faltando 1 da Juliana e as do Lázaro.
alter table public.academy_profiles disable trigger t_guard;
update public.academy_profiles set demo_agora = '2026-12-11 12:00-03' where email = 'wal@fourlabnutri.com.br';
alter table public.academy_profiles enable trigger t_guard;

-- Para desligar depois:
-- update public.academy_profiles set demo_agora = null where email = 'wal@fourlabnutri.com.br';
