# Taskflow

Organizador pessoal num site só: kanban de tarefas, agenda (Google Agenda), finanças (lançamentos, clientes, revenda e investimentos), caderno de estudos, vagas de emprego atualizadas todo dia e anotações. Cada conta é individual e privada.

## Recursos

- Login com e-mail e senha (Supabase Auth). Cada pessoa só enxerga os próprios dados, garantido por Row Level Security no banco.
- Kanban com A fazer, Em andamento, Pausado e Concluído, arrastar e soltar, prioridade e prazo.
- Agenda semanal com eventos do Google Agenda (Google Identity Services) e os prazos das tarefas.
- Finanças: entradas e saídas por mês, gastos por categoria, clientes, revenda com estoque e lucro, investimentos com rentabilidade.
- Estudos: páginas por matéria com Markdown simples.
- Vagas: lista diária de vagas com controle de envio de currículo.
- Configurações: 8 temas, cor de destaque, cantos, tamanho do texto, densidade, menu horizontal ou vertical e backup em arquivo JSON.

## Tecnologias

HTML, CSS e JavaScript puro, supabase-js via CDN, PostgreSQL no Supabase, GitHub Pages.

## Banco

Os arquivos `.sql` guardam o esquema na ordem em que foi criado: `schema.sql`, `equipes.sql`, `notas.sql`, `financas.sql`, `extras.sql`.
