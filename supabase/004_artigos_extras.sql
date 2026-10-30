-- FourLab Academy · campos extras dos artigos (rodar 1 vez)
alter table public.academy_artigos
  add column if not exists slug text unique,
  add column if not exists tipo_estudo text,
  add column if not exists extras jsonb not null default '{}'::jsonb;
