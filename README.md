# Taskflow

Kanban de tarefas para equipes. O gerente cria tarefas e designa para os funcionários ou para si mesmo, e cada pessoa move os cards entre A fazer, Em andamento, Pausado e Concluído.

## Como funciona

- Login com e-mail e senha (Supabase Auth). O primeiro cadastro vira gerente; os seguintes entram como funcionário.
- Gerente vê o quadro da equipe inteira, filtra por pessoa, cria, edita e exclui tarefas e muda o papel dos membros na aba Equipe.
- Funcionário vê só as próprias tarefas e pode apenas mudar o status.
- As regras ficam no banco (Row Level Security e triggers), não só na interface.
- Atualização em tempo real quando alguém mexe numa tarefa.

## Tecnologias

HTML, CSS e JavaScript puro, com [supabase-js](https://supabase.com/docs/reference/javascript) via CDN. Banco PostgreSQL no Supabase. Hospedado no GitHub Pages.

## Estrutura

- `index.html`: o site inteiro (telas de login, quadro e equipe).
- `schema.sql`: tabelas `perfis` e `tarefas`, funções, triggers e políticas de acesso.
