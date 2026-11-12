-- Sem conferência de carteirinha: todo cadastro entra liberado.
alter table public.academy_profiles disable trigger t_guard;
update public.academy_profiles set status = 'aprovado', aprovado_em = now() where status = 'pendente' and role = 'prescritor';
alter table public.academy_profiles enable trigger t_guard;

-- Convites de equipe: o admin cadastra e-mail + papel; ao criar a conta, o perfil nasce com esse papel.
create table if not exists public.academy_convites (
  email text primary key,
  nome text not null,
  role public.academy_role not null check (role <> 'prescritor'),
  criado_por uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.academy_convites enable row level security;
drop policy if exists cv_admin on public.academy_convites;
create policy cv_admin on public.academy_convites for all using (academy_my_role() = 'admin') with check (academy_my_role() = 'admin');

create or replace function public.academy_handle_signup() returns trigger
language plpgsql security definer set search_path = public as $$
declare num int; cv academy_convites;
begin
  select * into cv from academy_convites where email = lower(new.email);
  if found then
    insert into academy_profiles (id, nome, email, role, status, aprovado_em)
    values (new.id, cv.nome, new.email, cv.role, 'aprovado', now()) on conflict (id) do nothing;
    delete from academy_convites where email = cv.email;
    return new;
  end if;
  if coalesce(new.raw_user_meta_data->>'app','') <> 'academy' then return new; end if;
  if academy_fundador_aberto() then
    perform pg_advisory_xact_lock(hashtext('academy_fundador'));
    select coalesce(max(fundador_num), 0) + 1 into num from academy_profiles;
  end if;
  insert into academy_profiles (id, nome, email, profissao, conselho, registro, cidade, uf, modalidade, origem, status, aprovado_em, fundador_num)
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
    new.raw_user_meta_data->>'origem',
    'aprovado', now(), num
  ) on conflict (id) do nothing;
  return new;
end $$;
