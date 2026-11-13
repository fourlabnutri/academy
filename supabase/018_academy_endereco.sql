-- Endereço completo para envio + celular
alter table public.academy_profiles
  add column if not exists telefone text,
  add column if not exists cep text,
  add column if not exists logradouro text,
  add column if not exists numero text,
  add column if not exists complemento text,
  add column if not exists bairro text;

create or replace function public.academy_handle_signup() returns trigger
language plpgsql security definer set search_path = public as $$
declare num int; cv academy_convites; m jsonb := new.raw_user_meta_data;
begin
  select * into cv from academy_convites where email = lower(new.email);
  if found then
    insert into academy_profiles (id, nome, email, role, status, aprovado_em)
    values (new.id, cv.nome, new.email, cv.role, 'aprovado', now()) on conflict (id) do nothing;
    delete from academy_convites where email = cv.email;
    return new;
  end if;
  if coalesce(m->>'app','') <> 'academy' then return new; end if;
  if academy_fundador_aberto() then
    perform pg_advisory_xact_lock(hashtext('academy_fundador'));
    select coalesce(max(fundador_num), 0) + 1 into num from academy_profiles;
  end if;
  insert into academy_profiles (id, nome, email, profissao, conselho, registro, cidade, uf, modalidade, origem,
    telefone, cep, logradouro, numero, complemento, bairro, status, aprovado_em, fundador_num)
  values (
    new.id, coalesce(nullif(m->>'nome',''), split_part(new.email,'@',1)), new.email,
    m->>'profissao', m->>'conselho', m->>'registro', m->>'cidade', m->>'uf', m->>'modalidade', m->>'origem',
    m->>'telefone', m->>'cep', m->>'logradouro', m->>'numero', m->>'complemento', m->>'bairro',
    'aprovado', now(), num
  ) on conflict (id) do nothing;
  return new;
end $$;
