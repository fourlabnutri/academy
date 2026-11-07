-- 1) Prescritor só cria tópico de Dúvida ou Fale com a FourLab (responder continua liberado)
create or replace function public.academy_forum_cat_check() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not academy_is_staff() and new.categoria not in ('duvida', 'fourlab') then
    raise exception 'Somente a equipe publica casos clínicos e debates.';
  end if;
  return new;
end $$;
drop trigger if exists t_cat_check on public.academy_forum_topicos;
create trigger t_cat_check before insert or update of categoria on public.academy_forum_topicos
  for each row execute function public.academy_forum_cat_check();

-- 2) Sai os casos de teste; entram os debates do Endurance Applied
delete from public.academy_forum_topicos
 where autor_nome = 'Equipe FourLab' and categoria = 'caso'
   and (titulo like 'Caso %' or titulo like 'Caso para debate:%');

insert into public.academy_forum_topicos (categoria, titulo, corpo, oficial, fixado, autor_nome) values
('debate', 'Bloco 1 · Mitos e decisões: mostarda, pickle juice e eletrólitos funcionam?',
'No Endurance Applied discutimos hidratação e eletrólitos, manejo energético e respostas adaptativas, e o uso de mostarda e pickle juice contra cãibras.

Para debater:
1. Você já indicou mostarda ou pickle juice para cãibra? Qual foi a resposta do atleta?
2. Como você decide a reposição de sódio: taxa de sudorese, concentração de sódio no suor ou sintomas?
3. Em que situações você reduz carboidrato de propósito para buscar adaptação, e quando isso vira risco?',
true, true, 'Equipe FourLab'),
('debate', 'Bloco 2 · Tendências no endurance: géis de lactato e urolitina',
'Dois temas que chegam cada vez mais ao consultório: géis com lactato e a urolitina A.

Para debater:
1. O que a evidência atual sustenta sobre géis de lactato em relação aos géis de carboidrato tradicionais?
2. Para qual perfil de atleta você consideraria testar? Como mediria se funcionou?
3. Urolitina A: onde você vê aplicação real (recuperação, função mitocondrial, envelhecimento) e onde ainda é aposta?',
true, true, 'Equipe FourLab'),
('debate', 'Bloco 3 · Updates nutricionais: GLP/GIP, taurina e mega doses de carboidrato',
'Atualizações que mudam a prescrição: atletas usando agonistas de GLP-1/GIP, o papel da taurina e as estratégias de ingestão muito alta de carboidrato durante a prova.

Para debater:
1. Como você conduz um atleta de endurance em uso de GLP/GIP (apetite, proteína, energia disponível, performance)?
2. Taurina: em que contexto você prescreve e com qual dose?
3. Mega doses de carboidrato (acima de 90–120 g/h): como você treina o intestino e quem realmente se beneficia?',
true, true, 'Equipe FourLab'),
('caso', 'Bloco 4 · Estudo de caso: do diagnóstico ao ajuste da estratégia',
'Caso discutido no Endurance Applied. Use este tópico para continuar a conversa e trazer como você conduziria cada etapa.

Roteiro:
1. Avaliação inicial e principais problemas
2. Definição de prioridades
3. Estratégia energética e distribuição de carboidratos
4. Hidratação e eletrólitos
5. Suplementação
6. Rotina de treino e competição
7. Sintomas gastrointestinais e tolerância
8. Decisões em diferentes cenários
9. Ajustes ao longo do acompanhamento

Em qual etapa você teria conduzido diferente? Responda indicando o número da etapa.',
true, true, 'Equipe FourLab');
