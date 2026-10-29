-- =====================================================================
-- VERSÃO PARA SQLITE (Letos / SQLiteStudio) - apenas para TESTE
-- A entrega oficial do trabalho continua sendo o script MySQL.
-- =====================================================================
PRAGMA foreign_keys = ON;

CREATE TABLE tbl_categorias (
  id_categoria INTEGER PRIMARY KEY AUTOINCREMENT,
  nome         TEXT NOT NULL UNIQUE,
  descricao    TEXT
);

CREATE TABLE tbl_fornecedores (
  id_fornecedor INTEGER PRIMARY KEY AUTOINCREMENT,
  razao_social  TEXT NOT NULL,
  cnpj          TEXT NOT NULL UNIQUE,
  telefone      TEXT
);

CREATE TABLE tbl_produtos (
  id_produto     INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo_barras  TEXT NOT NULL UNIQUE,
  nome           TEXT NOT NULL,
  marca          TEXT,
  id_categoria   INTEGER NOT NULL REFERENCES tbl_categorias (id_categoria),
  id_fornecedor  INTEGER NOT NULL REFERENCES tbl_fornecedores (id_fornecedor),
  unidade_medida TEXT NOT NULL DEFAULT 'UN' CHECK (unidade_medida IN ('UN','KG','L')),
  preco_custo    NUMERIC NOT NULL CHECK (preco_custo >= 0),
  preco_venda    NUMERIC NOT NULL CHECK (preco_venda > 0),
  qtd_estoque    NUMERIC NOT NULL DEFAULT 0 CHECK (qtd_estoque >= 0),
  estoque_minimo NUMERIC NOT NULL DEFAULT 0 CHECK (estoque_minimo >= 0),
  data_validade  TEXT,
  ativo          INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE tbl_clientes (
  id_cliente        INTEGER PRIMARY KEY AUTOINCREMENT,
  nome              TEXT NOT NULL,
  cpf               TEXT NOT NULL UNIQUE
                    CHECK (length(cpf) = 11 AND cpf NOT GLOB '*[^0-9]*'),
  data_nascimento   TEXT,
  telefone          TEXT,
  email             TEXT,
  logradouro        TEXT,
  numero            TEXT,
  bairro            TEXT,
  cidade            TEXT,
  uf                TEXT,
  cep               TEXT,
  data_cadastro     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  aceita_ofertas    INTEGER NOT NULL DEFAULT 0,
  pontos_fidelidade INTEGER NOT NULL DEFAULT 0 CHECK (pontos_fidelidade >= 0)
);

CREATE TABLE tbl_colaboradores (
  id_colaborador INTEGER PRIMARY KEY AUTOINCREMENT,
  nome           TEXT NOT NULL,
  cpf            TEXT NOT NULL UNIQUE,
  cargo          TEXT NOT NULL
                 CHECK (cargo IN ('OPERADOR_CAIXA','GERENTE','REPOSITOR','ACOUGUEIRO')),
  data_admissao  TEXT NOT NULL,
  salario        NUMERIC NOT NULL CHECK (salario > 0),
  ativo          INTEGER NOT NULL DEFAULT 1,
  usuario        TEXT NOT NULL UNIQUE
);

CREATE TABLE tbl_formas_pagamento (
  id_forma_pagamento INTEGER PRIMARY KEY AUTOINCREMENT,
  descricao          TEXT NOT NULL UNIQUE
);

CREATE TABLE tbl_vendas (
  id_venda          INTEGER PRIMARY KEY AUTOINCREMENT,
  data_hora         TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  num_caixa         INTEGER NOT NULL,
  id_cliente        INTEGER REFERENCES tbl_clientes (id_cliente),
  id_colaborador    INTEGER NOT NULL REFERENCES tbl_colaboradores (id_colaborador),
  valor_total       NUMERIC NOT NULL DEFAULT 0 CHECK (valor_total >= 0),
  pontos_gerados    INTEGER NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'CONCLUIDA'
                    CHECK (status IN ('CONCLUIDA','CANCELADA')),
  data_cancelamento TEXT,
  id_colab_cancel   INTEGER REFERENCES tbl_colaboradores (id_colaborador),
  CHECK ((status = 'CANCELADA' AND data_cancelamento IS NOT NULL) OR
         (status = 'CONCLUIDA' AND data_cancelamento IS NULL))
);
CREATE INDEX idx_vendas_cliente_data ON tbl_vendas (id_cliente, data_hora);
CREATE INDEX idx_vendas_data ON tbl_vendas (data_hora);

CREATE TABLE tbl_itens_venda (
  id_item        INTEGER PRIMARY KEY AUTOINCREMENT,
  id_venda       INTEGER NOT NULL REFERENCES tbl_vendas (id_venda),
  id_produto     INTEGER NOT NULL REFERENCES tbl_produtos (id_produto),
  quantidade     NUMERIC NOT NULL,
  preco_unitario NUMERIC NOT NULL,
  desconto       NUMERIC NOT NULL DEFAULT 0,
  subtotal       NUMERIC GENERATED ALWAYS AS
                 (ROUND(quantidade * preco_unitario - desconto, 2)) STORED,
  UNIQUE (id_venda, id_produto),
  CHECK (quantidade > 0 AND preco_unitario > 0 AND desconto >= 0
         AND desconto <= quantidade * preco_unitario)
);

CREATE TABLE tbl_pagamentos_venda (
  id_pagamento       INTEGER PRIMARY KEY AUTOINCREMENT,
  id_venda           INTEGER NOT NULL REFERENCES tbl_vendas (id_venda),
  id_forma_pagamento INTEGER NOT NULL REFERENCES tbl_formas_pagamento (id_forma_pagamento),
  valor              NUMERIC NOT NULL CHECK (valor > 0)
);

-- Triggers (no SQLite não existe DELIMITER nem FLOOR/IF)
CREATE TRIGGER trg_itens_venda_ai
AFTER INSERT ON tbl_itens_venda
FOR EACH ROW
BEGIN
  UPDATE tbl_produtos
     SET qtd_estoque = qtd_estoque - NEW.quantidade
   WHERE id_produto = NEW.id_produto;

  UPDATE tbl_vendas
     SET valor_total    = ROUND(valor_total + NEW.subtotal, 2),
         pontos_gerados = CAST(ROUND(valor_total + NEW.subtotal, 2) AS INTEGER)
   WHERE id_venda = NEW.id_venda;
END;

CREATE TRIGGER trg_vendas_au
AFTER UPDATE OF pontos_gerados ON tbl_vendas
FOR EACH ROW
WHEN NEW.id_cliente IS NOT NULL AND NEW.pontos_gerados <> OLD.pontos_gerados
BEGIN
  UPDATE tbl_clientes
     SET pontos_fidelidade = pontos_fidelidade + (NEW.pontos_gerados - OLD.pontos_gerados)
   WHERE id_cliente = NEW.id_cliente;
END;

-- Dados de exemplo
INSERT INTO tbl_categorias (id_categoria, nome) VALUES
  (1,'Mercearia'), (2,'Hortifrúti'), (3,'Bebidas'), (4,'Limpeza'), (5,'Laticínios');

INSERT INTO tbl_fornecedores (id_fornecedor, razao_social, cnpj, telefone) VALUES
  (1,'Distribuidora Alimentos Brasil Ltda','11222333000181','1133334444'),
  (2,'Bebidas do Vale S.A.','22333444000172','1144445555'),
  (3,'Limpa Mais Produtos Ltda','33444555000163','1155556666');

INSERT INTO tbl_produtos (id_produto, codigo_barras, nome, marca, id_categoria, id_fornecedor,
  unidade_medida, preco_custo, preco_venda, qtd_estoque, estoque_minimo) VALUES
  (1,'7891000100103','Arroz Tipo 1 5kg','Bom Grão',1,1,'UN',18.50,24.90,120,20),
  (2,'7891000200204','Feijão Carioca 1kg','Bom Grão',1,1,'UN',6.20,8.99,200,30),
  (3,'7891000300305','Leite Integral 1L','Campo Azul',5,1,'UN',3.90,5.49,300,50),
  (4,'2000000000047','Banana Prata','Hortifruti Local',2,1,'KG',3.20,5.99,80,10),
  (5,'7891000500507','Refrigerante Cola 2L','Gás Cola',3,2,'UN',5.50,9.49,150,24),
  (6,'7891000600608','Detergente 500ml','Brilha',4,3,'UN',1.60,2.99,180,30);

INSERT INTO tbl_clientes (id_cliente, nome, cpf, telefone, email, cidade, uf,
  aceita_ofertas) VALUES
  (1,'Ana Paula Ferreira','52998224725','11988887777','ana.ferreira@email.com','São Paulo','SP',1),
  (2,'João Pedro Santos','11144477735','11977776666','joao.santos@email.com','São Paulo','SP',1);

INSERT INTO tbl_colaboradores (id_colaborador, nome, cpf, cargo, data_admissao, salario,
  usuario) VALUES
  (1,'Maria Souza','12345678909','OPERADOR_CAIXA','2024-03-10',2100.00,'maria.souza'),
  (2,'Carlos Lima','98765432100','GERENTE','2022-08-01',4800.00,'carlos.lima');

INSERT INTO tbl_formas_pagamento (id_forma_pagamento, descricao) VALUES
  (1,'Dinheiro'), (2,'Cartão de Débito'), (3,'Cartão de Crédito'), (4,'Pix'),
  (5,'Vale-Alimentação');

INSERT INTO tbl_vendas (id_venda, data_hora, num_caixa, id_cliente, id_colaborador) VALUES
  (1,'2026-09-28 10:15:00',2,1,1),
  (2,'2026-09-28 11:40:00',2,2,1),
  (3,'2026-09-29 18:05:00',1,NULL,1),
  (4,'2026-10-01 09:30:00',3,1,1);

INSERT INTO tbl_itens_venda (id_venda, id_produto, quantidade, preco_unitario, desconto) VALUES
  (1,1,1,24.90,0), (1,2,2,8.99,0), (1,3,3,5.49,0), (1,4,2.000,5.99,0),
  (2,5,2,9.49,0),  (2,6,3,2.99,0),
  (3,3,2,5.49,0),  (3,1,1,24.90,2.00),
  (4,3,4,5.49,0),  (4,4,1.000,5.99,0);

INSERT INTO tbl_pagamentos_venda (id_venda, id_forma_pagamento, valor) VALUES
  (1,1,30.00), (1,4,41.33),
  (2,3,27.95),
  (3,2,33.88),
  (4,4,27.95);

-- Conferência
SELECT id_venda, valor_total, pontos_gerados FROM tbl_vendas ORDER BY id_venda;
