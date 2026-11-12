-- Admin altera cadastro, senha e exclui contas do Academy (sem e-mail)
create extension if not exists pgcrypto with schema extensions;

create or replace function public.academy_admin_senha(uid uuid, senha text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if academy_my_role() <> 'admin' then raise exception 'sem permissão'; end if;
  if length(senha) < 8 then raise exception 'senha curta'; end if;
  if not exists (select 1 from academy_profiles where id = uid) then raise exception 'conta não é do Academy'; end if;
  update auth.users set encrypted_password = crypt(senha, gen_salt('bf')), updated_at = now(),
    email_confirmed_at = coalesce(email_confirmed_at, now()) where id = uid;
end $$;

create or replace function public.academy_admin_email(uid uuid, novo text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if academy_my_role() <> 'admin' then raise exception 'sem permissão'; end if;
  novo := lower(trim(novo));
  if exists (select 1 from auth.users where lower(email) = novo and id <> uid) then raise exception 'e-mail já usado por outra conta'; end if;
  update auth.users set email = novo, email_confirmed_at = now(), updated_at = now() where id = uid;
  update academy_profiles set email = novo where id = uid;
end $$;

create or replace function public.academy_admin_excluir(uid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if academy_my_role() <> 'admin' then raise exception 'sem permissão'; end if;
  if uid = auth.uid() then raise exception 'não dá para excluir a própria conta'; end if;
  if not exists (select 1 from academy_profiles where id = uid) then raise exception 'conta não é do Academy'; end if;
  update academy_profiles set aprovado_por = null where aprovado_por = uid;
  update academy_duvidas set respondido_por = null where respondido_por = uid;
  update academy_aulas set revisado_por = null where revisado_por = uid;
  update academy_artigos set traduzido_por = null where traduzido_por = uid;
  update academy_artigos set revisado_por = null where revisado_por = uid;
  delete from auth.users where id = uid;
end $$;

revoke all on function public.academy_admin_senha(uuid, text), public.academy_admin_email(uuid, text), public.academy_admin_excluir(uuid) from public, anon;
grant execute on function public.academy_admin_senha(uuid, text), public.academy_admin_email(uuid, text), public.academy_admin_excluir(uuid) to authenticated;
