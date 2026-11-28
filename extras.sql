-- Preferências de aparência
alter table public.perfis add column preferencias jsonb not null default '{}'::jsonb;

-- Finanças: clientes, revenda, investimentos; Estudos; Vagas (tudo privado por pessoa)
create table public.clientes (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 120), contato text, observacao text, criado_em timestamptz not null default now());
create table public.produtos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 120), custo numeric(12,2) not null default 0 check (custo >= 0), preco numeric(12,2) not null default 0 check (preco >= 0), estoque integer not null default 0, criado_em timestamptz not null default now());
create table public.investimentos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 120), tipo text not null default 'outros', aplicado numeric(14,2) not null default 0 check (aplicado >= 0), atual numeric(14,2) not null default 0 check (atual >= 0), data date not null default current_date, criado_em timestamptz not null default now());
alter table public.lancamentos add column cliente_id uuid references public.clientes(id) on delete set null;
alter table public.lancamentos add column produto_id uuid references public.produtos(id) on delete set null;
alter table public.lancamentos add column quantidade integer check (quantidade is null or quantidade > 0);
create table public.estudos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, materia text not null default 'Geral' check (length(materia) between 1 and 80), titulo text not null default '' check (length(titulo) <= 200), conteudo text not null default '', criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create table public.vagas (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, titulo text not null check (length(titulo) between 1 and 250), empresa text, local text, fonte text, link text not null, resumo text, salario text, publicada_em date, encontrada_em timestamptz not null default now(), status text not null default 'nova' check (status in ('nova','salva','enviado','entrevista','recusado','descartada')), enviado_em date, notas text, unique (dono_id, link));

create or replace function public.manter_dono() returns trigger language plpgsql set search_path = public as $$
begin new.dono_id := old.dono_id; if tg_table_name = 'estudos' then new.atualizado_em := now(); end if; return new; end $$;
-- triggers manter_dono e políticas "so o dono" (dono_id = auth.uid()) em clientes, produtos, investimentos, estudos e vagas

-- Vários quadros e mais detalhes nas tarefas
create table public.quadros (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 60), ordem integer not null default 0, criado_em timestamptz not null default now());
alter table public.tarefas add column quadro_id uuid references public.quadros(id) on delete cascade;
alter table public.tarefas add column etiquetas text[] not null default '{}';
alter table public.tarefas add column checklist jsonb not null default '[]'::jsonb;
alter table public.tarefas add column link text;
alter table public.tarefas add column inicio date;
alter table public.tarefas add column notas text;

-- Hábitos (dias feitos em array) e orçamento mensal por categoria
create table public.habitos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 80), meta_semana integer not null default 7 check (meta_semana between 1 and 7), cor text, feitos date[] not null default '{}', ordem integer not null default 0, criado_em timestamptz not null default now());
create table public.orcamentos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, categoria text not null check (length(categoria) between 1 and 60), limite numeric(12,2) not null check (limite > 0), criado_em timestamptz not null default now(), unique (dono_id, categoria));
-- RLS, trigger manter_dono e política "so o dono" nas duas

-- Colunas personalizadas por quadro (null = padrão A fazer, Em andamento, Pausado, Concluído)
alter table public.quadros add column colunas jsonb;

-- Setor da vaga (vagas de todas as áreas, agrupadas por setor)
alter table public.vagas add column setor text;

-- Registro de cada rodada da busca de vagas (o site mostra a última)
create table public.vagas_execucoes (id uuid primary key default gen_random_uuid(), dono_id uuid not null references public.perfis(id) on delete cascade, executada_em timestamptz not null default now(), novas integer not null default 0, resumo text);
-- RLS: dono só lê

-- Contato para envio de currículo
alter table public.vagas add column contato_email text, add column contato_telefone text;
