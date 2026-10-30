-- FourLab Academy · e-mails automáticos pelo Resend (cadastro recebido, aprovado, recusado).
-- Pré-requisito: guardar a chave do Resend no Vault (rodar UMA vez, trocando a chave):
--   select vault.create_secret('re_SUA_CHAVE_AQUI', 'resend_api_key');

create extension if not exists pg_net;

create or replace function public.academy_send_email(para text, assunto text, corpo text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare k text;
begin
  select decrypted_secret into k from vault.decrypted_secrets where name = 'resend_api_key';
  if k is null then return; end if;  -- sem chave, não envia (não trava o cadastro)
  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || k, 'Content-Type', 'application/json'),
    body := jsonb_build_object(
      'from', 'FourLab Academy <academy@fourlabnutrition.com.br>',
      'to', jsonb_build_array(para),
      'subject', assunto,
      'html',
        '<div style="background:#141013;padding:32px 16px;font-family:Arial,Helvetica,sans-serif">'
        || '<div style="max-width:520px;margin:0 auto;background:#1e181b;border-radius:18px;overflow:hidden">'
        || '<div style="height:6px;background:linear-gradient(90deg,#fdcc03,#e96709,#e3055f,#731b58)"></div>'
        || '<div style="padding:28px;color:#f5f0ed;font-size:15px;line-height:1.6">'
        || '<div style="font-weight:800;font-size:20px;letter-spacing:.5px">FOURLAB ACADEMY</div><br>'
        || corpo
        || '</div></div>'
        || '<p style="text-align:center;color:#9d8f88;font-size:12px;margin-top:16px">FourLab Nutrition · academy.fourlabnutrition.com.br</p></div>'
    )
  );
end $$;
revoke all on function public.academy_send_email(text, text, text) from public, anon, authenticated;

create or replace function public.academy_email_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare nome1 text := split_part(coalesce(new.nome, ''), ' ', 1);
        btn text := '<a href="https://academy.fourlabnutrition.com.br/login.html" style="display:inline-block;margin-top:12px;background:#e96709;color:#fff;text-decoration:none;font-weight:700;padding:12px 22px;border-radius:999px">Acessar o Academy</a>';
begin
  if new.role <> 'prescritor' then return new; end if;
  if tg_op = 'INSERT' then
    perform academy_send_email(new.email, 'Recebemos seu cadastro no FourLab Academy',
      'Olá, ' || nome1 || '!<br><br>Recebemos seu cadastro. Para liberar o acesso, entre no site e envie a foto da carteirinha do seu conselho. A conferência leva em geral até 48h.<br>' || btn);
  elsif new.status is distinct from old.status and new.status = 'aprovado' then
    perform academy_send_email(new.email, 'Seu acesso ao FourLab Academy foi liberado',
      'Olá, ' || nome1 || '!<br><br>Seu registro foi conferido e o acesso está liberado. Aulas, artigos com tradução e protocolos já estão disponíveis para você.<br>' || btn);
  elsif new.status is distinct from old.status and new.status = 'recusado' then
    perform academy_send_email(new.email, 'Sobre seu cadastro no FourLab Academy',
      'Olá, ' || nome1 || '.<br><br>Não conseguimos validar seu registro profissional. '
      || coalesce(new.motivo_recusa, '') || '<br><br>Se achar que houve um engano, fale com a equipe FourLab que conferimos de novo.');
  end if;
  return new;
end $$;

drop trigger if exists academy_email_status on public.academy_profiles;
create trigger academy_email_status after insert or update of status on public.academy_profiles
  for each row execute function public.academy_email_status();
