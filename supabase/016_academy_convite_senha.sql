-- Conta de equipe criada pelo admin já nasce com e-mail confirmado (sem e-mail de confirmação)
create or replace function public.academy_confirma_convite() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from academy_convites where email = lower(new.email)) then
    new.email_confirmed_at := coalesce(new.email_confirmed_at, now());
  end if;
  return new;
end $$;
drop trigger if exists academy_confirma_convite on auth.users;
create trigger academy_confirma_convite before insert on auth.users
  for each row execute function public.academy_confirma_convite();
