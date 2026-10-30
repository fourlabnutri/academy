-- FourLab Academy · schema inicial
-- Tabelas com prefixo academy_ no schema public (convive com o painel B2B no mesmo projeto).

-- ---------- tipos ----------
create type public.academy_role as enum ('prescritor','editor','revisor','comercial','admin');
create type public.academy_status as enum ('pendente','aprovado','recusado','suspenso');
create type public.academy_etapa as enum ('rascunho','em_revisao','publicado','arquivado');

-- ---------- pessoas ----------
create table public.academy_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  email text not null,
  role public.academy_role not null default 'prescritor',
  status public.academy_status not null default 'pendente',
  profissao text,                 -- Nutricionista, Médico(a), Educador(a) físico(a)...
  conselho text,                  -- CRN-3, CRM-SP, CREF...
  registro text,                  -- número no conselho
  cidade text, uf text,
  modalidade text,                -- MTB, Corrida, Triathlon, Trail
  comprovante_path text,          -- arquivo no bucket academy-comprovantes
  cupom text unique,
  aprovado_por uuid references public.academy_profiles(id),
  aprovado_em timestamptz,
  motivo_recusa text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- conteúdo ----------
create table public.academy_trilhas (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  titulo text not null,
  descricao text,
  capa_path text,
  carga_horas numeric(5,1),
  ordem int not null default 0,
  etapa public.academy_etapa not null default 'rascunho',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.academy_aulas (
  id uuid primary key default gen_random_uuid(),
  trilha_id uuid not null references public.academy_trilhas(id) on delete cascade,
  titulo text not null,
  resumo text,
  professor text,
  panda_video_id text,            -- id do vídeo no Panda Video
  duracao_seg int,
  materiais jsonb not null default '[]',   -- [{nome, path}]
  ordem int not null default 0,
  etapa public.academy_etapa not null default 'rascunho',
  revisado_por uuid references public.academy_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.academy_artigos (
  id uuid primary key default gen_random_uuid(),
  titulo_original text not null,
  titulo_pt text,
  autores text,
  periodico text,
  ano int,
  doi text,
  link_original text,
  nivel_evidencia text,           -- ECR, RS, Meta-análise, Piloto...
  tema text,                      -- Carboidrato, Hidratação, Ergogênicos, Saúde GI...
  resumo_pt text,
  texto_original text,
  texto_pt text,
  nota_fourlab text,
  pdf_path text,
  etapa public.academy_etapa not null default 'rascunho',
  traduzido_por uuid references public.academy_profiles(id),
  revisado_por uuid references public.academy_profiles(id),
  publicado_em timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.academy_eventos (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descricao text,
  inicio timestamptz not null,
  link_live text,
  aula_gravacao_id uuid references public.academy_aulas(id),
  etapa public.academy_etapa not null default 'rascunho',
  created_at timestamptz not null default now()
);

-- ---------- uso do prescritor ----------
create table public.academy_progresso (
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  aula_id uuid not null references public.academy_aulas(id) on delete cascade,
  segundos_assistidos int not null default 0,
  concluida boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, aula_id)
);

create table public.academy_artigos_salvos (
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  artigo_id uuid not null references public.academy_artigos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, artigo_id)
);

create table public.academy_inscricoes_evento (
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  evento_id uuid not null references public.academy_eventos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, evento_id)
);

create table public.academy_certificados (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  trilha_id uuid not null references public.academy_trilhas(id),
  codigo text unique not null default upper(substr(md5(gen_random_uuid()::text),1,10)),
  emitido_em timestamptz not null default now(),
  unique (user_id, trilha_id)
);

create table public.academy_duvidas (
  id uuid primary key default gen_random_uuid(),
  aula_id uuid not null references public.academy_aulas(id) on delete cascade,
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  pergunta text not null,
  resposta text,
  respondido_por uuid references public.academy_profiles(id),
  created_at timestamptz not null default now()
);

create table public.academy_pedidos_amostra (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  endereco text not null,
  observacao text,
  status text not null default 'novo',     -- novo, enviado, entregue
  created_at timestamptz not null default now()
);

create index on public.academy_aulas (trilha_id, ordem);
create index on public.academy_artigos (tema, publicado_em desc);
create index on public.academy_profiles (status);

-- ---------- helpers de permissão ----------
create or replace function public.academy_my_role() returns public.academy_role
language sql stable security definer set search_path = public as $$
  select role from academy_profiles where id = auth.uid() and status = 'aprovado'
$$;
create or replace function public.academy_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(academy_my_role() in ('editor','revisor','comercial','admin'), false)
$$;
create or replace function public.academy_can_edit() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(academy_my_role() in ('editor','revisor','admin'), false)
$$;
create or replace function public.academy_is_approved() returns boolean
language sql stable security definer set search_path = public as $$
  select academy_my_role() is not null
$$;

-- updated_at
create or replace function public.academy_touch() returns trigger
language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end $$;
create trigger t_touch before update on public.academy_profiles for each row execute function public.academy_touch();
create trigger t_touch before update on public.academy_trilhas  for each row execute function public.academy_touch();
create trigger t_touch before update on public.academy_aulas    for each row execute function public.academy_touch();
create trigger t_touch before update on public.academy_artigos  for each row execute function public.academy_touch();

-- O prescritor não pode mudar o próprio cargo, status ou aprovação.
create or replace function public.academy_guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if academy_my_role() = 'admin' then return new; end if;
  if academy_my_role() = 'comercial' and new.id <> auth.uid() then
    new.role := old.role;  -- comercial aprova/recusa, mas não muda cargo
    if new.status is distinct from old.status then new.aprovado_por := auth.uid(); new.aprovado_em := now(); end if;
    return new;
  end if;
  new.role := old.role; new.status := old.status;
  new.aprovado_por := old.aprovado_por; new.aprovado_em := old.aprovado_em; new.cupom := old.cupom;
  return new;
end $$;
create trigger t_guard before update on public.academy_profiles for each row execute function public.academy_guard_profile();

-- ---------- RLS ----------
alter table public.academy_profiles enable row level security;
alter table public.academy_trilhas enable row level security;
alter table public.academy_aulas enable row level security;
alter table public.academy_artigos enable row level security;
alter table public.academy_eventos enable row level security;
alter table public.academy_progresso enable row level security;
alter table public.academy_artigos_salvos enable row level security;
alter table public.academy_inscricoes_evento enable row level security;
alter table public.academy_certificados enable row level security;
alter table public.academy_duvidas enable row level security;
alter table public.academy_pedidos_amostra enable row level security;

-- perfis: cada um vê e cria o seu (sempre como prescritor pendente); equipe vê todos
create policy p_self_read on public.academy_profiles for select using (id = auth.uid() or academy_is_staff());
create policy p_self_insert on public.academy_profiles for insert with check (id = auth.uid() and role = 'prescritor' and status = 'pendente');
create policy p_update on public.academy_profiles for update using (id = auth.uid() or academy_my_role() in ('comercial','admin'));

-- conteúdo: aprovado lê o que está publicado; quem edita vê e altera tudo
create policy c_read on public.academy_trilhas for select using ((etapa = 'publicado' and academy_is_approved()) or academy_is_staff());
create policy c_write on public.academy_trilhas for all using (academy_can_edit()) with check (academy_can_edit());
create policy c_read on public.academy_aulas for select using ((etapa = 'publicado' and academy_is_approved()) or academy_is_staff());
create policy c_write on public.academy_aulas for all using (academy_can_edit()) with check (academy_can_edit());
create policy c_read on public.academy_artigos for select using ((etapa = 'publicado' and academy_is_approved()) or academy_is_staff());
create policy c_write on public.academy_artigos for all using (academy_can_edit()) with check (academy_can_edit());
create policy c_read on public.academy_eventos for select using ((etapa = 'publicado' and academy_is_approved()) or academy_is_staff());
create policy c_write on public.academy_eventos for all using (academy_can_edit()) with check (academy_can_edit());

-- dados do próprio prescritor; equipe só lê
create policy u_own on public.academy_progresso for all using (user_id = auth.uid() and academy_is_approved()) with check (user_id = auth.uid() and academy_is_approved());
create policy u_staff on public.academy_progresso for select using (academy_is_staff());
create policy u_own on public.academy_artigos_salvos for all using (user_id = auth.uid() and academy_is_approved()) with check (user_id = auth.uid() and academy_is_approved());
create policy u_own on public.academy_inscricoes_evento for all using (user_id = auth.uid() and academy_is_approved()) with check (user_id = auth.uid() and academy_is_approved());
create policy u_staff on public.academy_inscricoes_evento for select using (academy_is_staff());
create policy u_own_read on public.academy_certificados for select using (user_id = auth.uid() or academy_is_staff());
create policy d_read on public.academy_duvidas for select using (academy_is_approved());
create policy d_ask on public.academy_duvidas for insert with check (user_id = auth.uid() and academy_is_approved() and resposta is null);
create policy d_answer on public.academy_duvidas for update using (academy_can_edit());
create policy a_own on public.academy_pedidos_amostra for insert with check (user_id = auth.uid() and academy_is_approved());
create policy a_read on public.academy_pedidos_amostra for select using (user_id = auth.uid() or academy_my_role() in ('comercial','admin'));
create policy a_upd on public.academy_pedidos_amostra for update using (academy_my_role() in ('comercial','admin'));

-- Certificado é emitido pelo banco quando todas as aulas publicadas da trilha forem concluídas.
create or replace function public.academy_emitir_certificado() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  if not new.concluida then return new; end if;
  select trilha_id into t from academy_aulas where id = new.aula_id;
  if not exists (
    select 1 from academy_aulas a
    left join academy_progresso p on p.aula_id = a.id and p.user_id = new.user_id
    where a.trilha_id = t and a.etapa = 'publicado' and coalesce(p.concluida,false) = false
  ) then
    insert into academy_certificados (user_id, trilha_id) values (new.user_id, t) on conflict do nothing;
  end if;
  return new;
end $$;
create trigger t_cert after insert or update of concluida on public.academy_progresso for each row execute function public.academy_emitir_certificado();

-- ---------- storage ----------
insert into storage.buckets (id, name, public) values
  ('academy-comprovantes','academy-comprovantes', false),
  ('academy-artigos','academy-artigos', false),
  ('academy-materiais','academy-materiais', false)
on conflict do nothing;
-- comprovante: cada um envia na pasta com o próprio id; equipe lê
create policy s_comp_up on storage.objects for insert with check (bucket_id = 'academy-comprovantes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy s_comp_read on storage.objects for select using (bucket_id = 'academy-comprovantes' and ((storage.foldername(name))[1] = auth.uid()::text or public.academy_is_staff()));
-- PDFs e materiais: aprovados leem, editores sobem
create policy s_mat_read on storage.objects for select using (bucket_id in ('academy-artigos','academy-materiais') and public.academy_is_approved());
create policy s_mat_write on storage.objects for insert with check (bucket_id in ('academy-artigos','academy-materiais') and public.academy_can_edit());
