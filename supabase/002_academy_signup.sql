-- FourLab Academy · cria o perfil (pendente) automaticamente no cadastro.
-- Só age em cadastros feitos pelo site do Academy (marcados com app = 'academy'),
-- para não criar perfil do Academy para usuários do painel B2B.
create or replace function public.academy_handle_signup() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.raw_user_meta_data->>'app','') <> 'academy' then return new; end if;
  insert into academy_profiles (id, nome, email, profissao, conselho, registro, cidade, uf, modalidade)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome',''), split_part(new.email,'@',1)),
    new.email,
    new.raw_user_meta_data->>'profissao',
    new.raw_user_meta_data->>'conselho',
    new.raw_user_meta_data->>'registro',
    new.raw_user_meta_data->>'cidade',
    new.raw_user_meta_data->>'uf',
    new.raw_user_meta_data->>'modalidade'
  ) on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists academy_on_signup on auth.users;
create trigger academy_on_signup after insert on auth.users
  for each row execute function public.academy_handle_signup();
