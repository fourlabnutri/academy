-- Sala de teste da live: chat separado, visível só para a equipe
create table if not exists public.academy_live_chat_teste (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.academy_profiles(id) on delete set null,
  autor_nome text not null default '',
  corpo text not null check (length(corpo) between 1 and 500),
  created_at timestamptz not null default now()
);
alter table public.academy_live_chat_teste enable row level security;
drop policy if exists lt_all on public.academy_live_chat_teste;
create policy lt_all on public.academy_live_chat_teste for all using (academy_is_staff()) with check (academy_is_staff() and user_id = auth.uid());

create or replace function public.academy_live_teste_autor() returns trigger
language plpgsql security definer set search_path = public as $$
declare pf academy_profiles;
begin
  select * into pf from academy_profiles where id = auth.uid();
  new.autor_nome := split_part(pf.nome,' ',1) || coalesce(' ' || nullif(left(split_part(pf.nome,' ',2),1),'') || '.', '');
  new.created_at := now();
  return new;
end $$;
drop trigger if exists t_autor on public.academy_live_chat_teste;
create trigger t_autor before insert on public.academy_live_chat_teste for each row execute function public.academy_live_teste_autor();

do $$ begin
  alter publication supabase_realtime add table public.academy_live_chat_teste;
exception when duplicate_object then null; end $$;
