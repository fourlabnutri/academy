-- FourLab Academy · contador da TV e tópicos iniciais do fórum
-- só o total de fundadores (sem nomes), liberado para a tela do estande sem login
create or replace function public.academy_fundadores_total() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from academy_profiles where fundador_num is not null
$$;
revoke all on function public.academy_fundadores_total() from public;
grant execute on function public.academy_fundadores_total() to anon, authenticated;

insert into public.academy_forum_topicos (categoria, titulo, corpo, oficial, fixado, autor_nome)
select * from (values
 ('fourlab', 'Boas-vindas aos membros fundadores',
  'Este é o espaço da comunidade FourLab Academy. Apresente-se aqui: seu nome, cidade e com quais modalidades você trabalha. Use "Casos clínicos" para discutir atendimentos (sem identificar o paciente) e "Fale com a FourLab" para falar direto com a nossa equipe.',
  true, true, 'Equipe FourLab'),
 ('caso', 'Caso para debate: triatleta com desconforto gastrointestinal no Ironman 70.3',
  'Atleta de 38 anos, amador, prepara o primeiro 70.3. Nos treinos longos de bike relata náusea e distensão a partir da 2ª hora, quando aumenta a ingestão de carboidrato. Faz o treino de corrida com pouca ingestão por medo dos sintomas e quebra no final.

Para debater:
1. Como você investigaria a causa dos sintomas?
2. Como estruturaria o treino do intestino até a prova?
3. Que meta de carboidrato por hora você buscaria e como chegaria nela?',
  true, false, 'Equipe FourLab'),
 ('caso', 'Caso para debate: corredora de ultra com prova em calor intenso',
  'Corredora de 29 anos vai disputar uma ultra de 50 km com previsão de 32 °C. Perde bastante sal (marcas brancas na roupa) e já teve cãibras em provas longas. Hoje bebe só água durante os treinos.

Para debater:
1. Como você estimaria as necessidades de líquido e sódio dela?
2. Que estratégia de hidratação e eletrólitos montaria para a prova?
3. Quais sinais de alerta você ensinaria a ela observar?',
  true, false, 'Equipe FourLab'),
 ('caso', 'Caso para debate: ciclista de MTB XCO e suplementos tamponantes',
  'Ciclista de MTB, 24 anos, compete em provas de XCO de cerca de 1h30 com muitos esforços de alta intensidade. Pergunta se deve usar bicarbonato, beta-alanina ou os dois.

Para debater:
1. O perfil de esforço justifica estratégias de tamponamento?
2. Como você escolheria entre bicarbonato, beta-alanina ou a combinação?
3. Como testaria a tolerância antes de usar em competição?',
  true, false, 'Equipe FourLab')
) v(categoria, titulo, corpo, oficial, fixado, autor_nome)
where not exists (select 1 from academy_forum_topicos t where t.titulo = v.titulo);
