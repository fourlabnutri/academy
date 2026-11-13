-- Duas aulas por semana (terça e quinta): Paulo → Lázaro → Juliana
with a as (
  select au.id, t.slug, row_number() over (partition by au.trilha_id order by au.ordem) n
  from academy_aulas au join academy_trilhas t on t.id = au.trilha_id
)
update academy_aulas x set libera_em = case
  when a.slug = 'carboidratos-endurance' and a.n = 1 then timestamptz '2026-11-19 08:00-03'
  when a.slug = 'carboidratos-endurance' and a.n = 2 then timestamptz '2026-11-24 08:00-03'
  when a.slug = 'hidratacao-eletrolitos' and a.n = 1 then timestamptz '2026-12-03 08:00-03'
  when a.slug = 'hidratacao-eletrolitos' and a.n = 2 then timestamptz '2026-12-08 08:00-03'
  when a.slug = 'hidratacao-eletrolitos' and a.n = 3 then timestamptz '2026-12-10 08:00-03'
  else x.libera_em end
from a where a.id = x.id;
-- Lázaro (26/11 e 01/12) aparece no início como "em breve" até as aulas dele serem cadastradas.
