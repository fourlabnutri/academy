alter table public.academy_live add column if not exists modulos jsonb not null default '{"live":true,"artigos":true,"forum":true,"ranking":true,"quiz":false,"certificados":true}';
alter table public.academy_live add column if not exists visita_url text;

-- Casos antigos (genéricos) saem; entram casos com dados concretos
delete from public.academy_forum_topicos where autor_nome = 'Equipe FourLab' and categoria = 'caso' and titulo like 'Caso para debate:%';
insert into public.academy_forum_topicos (categoria, titulo, corpo, oficial, fixado, autor_nome) values
('caso', 'Caso 1 · Remadora 2.000 m: bicarbonato com desconforto GI',
'Remadora, 22 anos, 64 kg, peso leve. Prova de 2.000 m (~7min20). Testou bicarbonato de sódio 0,3 g/kg (19 g) em dose única, 60 min antes, com água: teve diarreia e cólica no aquecimento e piorou o tempo em 4 s.
Dieta pré-treino: café da manhã pequeno, 1 g/kg de carboidrato.

Para debater:
1. Vale insistir no bicarbonato para esse perfil de esforço?
2. Que ajustes você faria (dose, fracionamento, horário, refeição junto, forma de apresentação)?
3. Como testaria em treino antes da próxima regata?',
true, false, 'Equipe FourLab'),
('caso', 'Caso 2 · Ciclista master: beta-alanina há 3 semanas e "sem efeito"',
'Ciclista, 47 anos, 78 kg, provas de critério (~60 min com sprints repetidos). Toma 3,2 g/dia de beta-alanina há 3 semanas, de uma vez só, e reclama de formigamento e de não sentir diferença. Quer parar.
Treina 9 h/semana, sem acompanhamento de exames.

Para debater:
1. O tempo de uso e a dose são suficientes para esperar efeito?
2. Como você resolveria a parestesia sem perder a dose diária?
3. Que métrica de treino você usaria para avaliar se está funcionando?',
true, false, 'Equipe FourLab'),
('caso', 'Caso 3 · Corredor de 10 km: creatina e medo de ganhar peso',
'Corredor, 31 anos, 68 kg, 10 km em 36 min. Faz musculação 2x/semana e tiros na pista. Ouviu que creatina "incha" e atrapalha corredor. Creatinina sérica 1,2 mg/dL no último exame, sem outras alterações.

Para debater:
1. A creatina tem indicação para esse atleta? Com qual objetivo?
2. Saturação ou dose fixa (3–5 g/dia)? Como lidar com a variação de peso?
3. Como interpretar a creatinina dele antes e durante o uso?',
true, false, 'Equipe FourLab');
