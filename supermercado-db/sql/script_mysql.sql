-- =====================================================================
-- SISTEMA DE VENDAS DE SUPERMERCADO - Modelo Físico (MySQL 8.0.16+)
-- Autor: Denilson Almeida Rocha | UniFECAF - Análise e Desenv. de Sistemas
-- =====================================================================
CREATE DATABASE IF NOT EXISTS db_supermercado
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_supermercado;

-- ---------------------------------------------------------------------
-- 1. Tabelas de apoio ao cadastro de produtos
-- ---------------------------------------------------------------------
CREATE TABLE tbl_categorias (
  id_categoria  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome          VARCHAR(60)  NOT NULL,
  descricao     VARCHAR(150) NULL,
  CONSTRAINT pk_categorias PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categorias_nome UNIQUE (nome)
) ENGINE=InnoDB;

CREATE TABLE tbl_fornecedores (
  id_fornecedor INT UNSIGNED NOT NULL AUTO_INCREMENT,
  razao_social  VARCHAR(120) NOT NULL,
  cnpj          CHAR(14)     NOT NULL,   -- somente números
  telefone      VARCHAR(15)  NULL,
  CONSTRAINT pk_fornecedores PRIMARY KEY (id_fornecedor),
  CONSTRAINT uq_fornecedores_cnpj UNIQUE (cnpj)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. tbl_produtos: itens vendidos e controle de estoque
-- ---------------------------------------------------------------------
CREATE TABLE tbl_produtos (
  id_produto     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  codigo_barras  VARCHAR(14)   NOT NULL,
  nome           VARCHAR(120)  NOT NULL,
  marca          VARCHAR(60)   NULL,
  id_categoria   INT UNSIGNED  NOT NULL,
  id_fornecedor  INT UNSIGNED  NOT NULL,
  unidade_medida ENUM('UN','KG','L') NOT NULL DEFAULT 'UN',
  preco_custo    DECIMAL(10,2) NOT NULL,
  preco_venda    DECIMAL(10,2) NOT NULL,
  qtd_estoque    DECIMAL(10,3) NOT NULL DEFAULT 0,  -- 3 casas: produtos por kg
  estoque_minimo DECIMAL(10,3) NOT NULL DEFAULT 0,
  data_validade  DATE          NULL,                -- só para perecíveis
  ativo          TINYINT(1)    NOT NULL DEFAULT 1,  -- 0 = fora de linha
  CONSTRAINT pk_produtos PRIMARY KEY (id_produto),
  CONSTRAINT uq_produtos_barras UNIQUE (codigo_barras),
  CONSTRAINT fk_produtos_categoria FOREIGN KEY (id_categoria)
    REFERENCES tbl_categorias (id_categoria),
  CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (id_fornecedor)
    REFERENCES tbl_fornecedores (id_fornecedor),
  CONSTRAINT chk_produtos_precos CHECK (preco_custo >= 0 AND preco_venda > 0),
  CONSTRAINT chk_produtos_estoque CHECK (qtd_estoque >= 0 AND estoque_minimo >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. tbl_clientes: cadastro opcional, identificado pelo CPF
-- ---------------------------------------------------------------------
CREATE TABLE tbl_clientes (
  id_cliente       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome             VARCHAR(120) NOT NULL,
  cpf              CHAR(11)     NOT NULL,          -- somente números
  data_nascimento  DATE         NULL,
  telefone         VARCHAR(15)  NULL,
  email            VARCHAR(120) NULL,
  logradouro       VARCHAR(120) NULL,
  numero           VARCHAR(10)  NULL,
  bairro           VARCHAR(60)  NULL,
  cidade           VARCHAR(60)  NULL,
  uf               CHAR(2)      NULL,
  cep              CHAR(8)      NULL,
  data_cadastro    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  aceita_ofertas   TINYINT(1)   NOT NULL DEFAULT 0,  -- consentimento (LGPD)
  pontos_fidelidade INT         NOT NULL DEFAULT 0,  -- saldo do programa
  CONSTRAINT pk_clientes PRIMARY KEY (id_cliente),
  CONSTRAINT uq_clientes_cpf UNIQUE (cpf),
  CONSTRAINT chk_clientes_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT chk_clientes_pontos CHECK (pontos_fidelidade >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. tbl_colaboradores: funcionários (operadores de caixa, gerentes...)
-- ---------------------------------------------------------------------
CREATE TABLE tbl_colaboradores (
  id_colaborador INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome           VARCHAR(120) NOT NULL,
  cpf            CHAR(11)     NOT NULL,
  cargo          ENUM('OPERADOR_CAIXA','GERENTE','REPOSITOR','ACOUGUEIRO') NOT NULL,
  data_admissao  DATE         NOT NULL,
  salario        DECIMAL(10,2) NOT NULL,
  ativo          TINYINT(1)   NOT NULL DEFAULT 1,   -- 0 = desligado
  usuario        VARCHAR(30)  NOT NULL,             -- login (senha fica no app)
  CONSTRAINT pk_colaboradores PRIMARY KEY (id_colaborador),
  CONSTRAINT uq_colaboradores_cpf UNIQUE (cpf),
  CONSTRAINT uq_colaboradores_usuario UNIQUE (usuario),
  CONSTRAINT chk_colaboradores_salario CHECK (salario > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. tbl_formas_pagamento: dinheiro, débito, crédito, Pix, vale...
-- ---------------------------------------------------------------------
CREATE TABLE tbl_formas_pagamento (
  id_forma_pagamento INT UNSIGNED NOT NULL AUTO_INCREMENT,
  descricao          VARCHAR(40)  NOT NULL,
  CONSTRAINT pk_formas_pagamento PRIMARY KEY (id_forma_pagamento),
  CONSTRAINT uq_formas_pagamento UNIQUE (descricao)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. tbl_vendas: cabeçalho da venda (id_cliente é opcional)
-- ---------------------------------------------------------------------
CREATE TABLE tbl_vendas (
  id_venda          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  data_hora         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  num_caixa         TINYINT UNSIGNED NOT NULL,
  id_cliente        INT UNSIGNED  NULL,            -- NULL = cliente não identificado
  id_colaborador    INT UNSIGNED  NOT NULL,        -- operador que fez a venda
  valor_total       DECIMAL(10,2) NOT NULL DEFAULT 0,  -- atualizado pelo trigger
  pontos_gerados    INT           NOT NULL DEFAULT 0,  -- atualizado pelo trigger
  status            ENUM('CONCLUIDA','CANCELADA') NOT NULL DEFAULT 'CONCLUIDA',
  data_cancelamento DATETIME      NULL,
  id_colab_cancel   INT UNSIGNED  NULL,            -- quem autorizou o cancelamento
  CONSTRAINT pk_vendas PRIMARY KEY (id_venda),
  CONSTRAINT fk_vendas_cliente FOREIGN KEY (id_cliente)
    REFERENCES tbl_clientes (id_cliente),
  CONSTRAINT fk_vendas_colaborador FOREIGN KEY (id_colaborador)
    REFERENCES tbl_colaboradores (id_colaborador),
  CONSTRAINT fk_vendas_colab_cancel FOREIGN KEY (id_colab_cancel)
    REFERENCES tbl_colaboradores (id_colaborador),
  CONSTRAINT chk_vendas_valor CHECK (valor_total >= 0),
  CONSTRAINT chk_vendas_cancel CHECK (
    (status = 'CANCELADA' AND data_cancelamento IS NOT NULL) OR
    (status = 'CONCLUIDA' AND data_cancelamento IS NULL)),
  INDEX idx_vendas_cliente_data (id_cliente, data_hora),  -- histórico por cliente
  INDEX idx_vendas_data (data_hora)                       -- relatórios por período
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. tbl_itens_venda: produtos de cada venda (resolve o N:M venda x produto)
--    Guarda o preço praticado, pois o preço do produto muda com o tempo.
-- ---------------------------------------------------------------------
CREATE TABLE tbl_itens_venda (
  id_item        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_venda       INT UNSIGNED  NOT NULL,
  id_produto     INT UNSIGNED  NOT NULL,
  quantidade     DECIMAL(10,3) NOT NULL,
  preco_unitario DECIMAL(10,2) NOT NULL,
  desconto       DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal       DECIMAL(12,2) AS (ROUND(quantidade * preco_unitario - desconto, 2)) STORED,
  CONSTRAINT pk_itens_venda PRIMARY KEY (id_item),
  CONSTRAINT uq_itens_venda_produto UNIQUE (id_venda, id_produto),
  CONSTRAINT fk_itens_venda FOREIGN KEY (id_venda)
    REFERENCES tbl_vendas (id_venda),
  CONSTRAINT fk_itens_produto FOREIGN KEY (id_produto)
    REFERENCES tbl_produtos (id_produto),
  CONSTRAINT chk_itens_valores CHECK (
    quantidade > 0 AND preco_unitario > 0 AND desconto >= 0
    AND desconto <= quantidade * preco_unitario)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. tbl_pagamentos_venda: formas de pagamento de cada venda (N:M)
-- ---------------------------------------------------------------------
CREATE TABLE tbl_pagamentos_venda (
  id_pagamento       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_venda           INT UNSIGNED  NOT NULL,
  id_forma_pagamento INT UNSIGNED  NOT NULL,
  valor              DECIMAL(10,2) NOT NULL,
  CONSTRAINT pk_pagamentos_venda PRIMARY KEY (id_pagamento),
  CONSTRAINT fk_pagamentos_venda FOREIGN KEY (id_venda)
    REFERENCES tbl_vendas (id_venda),
  CONSTRAINT fk_pagamentos_forma FOREIGN KEY (id_forma_pagamento)
    REFERENCES tbl_formas_pagamento (id_forma_pagamento),
  CONSTRAINT chk_pagamentos_valor CHECK (valor > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. Triggers: automatizam estoque, total da venda e pontos de fidelidade
-- ---------------------------------------------------------------------
DELIMITER $$

-- Ao inserir um item: baixa o estoque e soma o item no total da venda.
-- Os pontos são 1 por real gasto (parte inteira do total da venda).
CREATE TRIGGER trg_itens_venda_ai
AFTER INSERT ON tbl_itens_venda
FOR EACH ROW
BEGIN
  UPDATE tbl_produtos
     SET qtd_estoque = qtd_estoque - NEW.quantidade
   WHERE id_produto = NEW.id_produto;

  UPDATE tbl_vendas
     SET valor_total    = valor_total
                          + ROUND(NEW.quantidade * NEW.preco_unitario - NEW.desconto, 2),
         pontos_gerados = FLOOR(valor_total)
   WHERE id_venda = NEW.id_venda;
END$$

-- Quando os pontos da venda aumentam, credita a diferença ao cliente
-- (só se a venda tiver cliente identificado).
CREATE TRIGGER trg_vendas_au
AFTER UPDATE ON tbl_vendas
FOR EACH ROW
BEGIN
  IF NEW.id_cliente IS NOT NULL AND NEW.pontos_gerados <> OLD.pontos_gerados THEN
    UPDATE tbl_clientes
       SET pontos_fidelidade = pontos_fidelidade
                               + (NEW.pontos_gerados - OLD.pontos_gerados)
     WHERE id_cliente = NEW.id_cliente;
  END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 10. Dados de exemplo (para testar o banco)
-- ---------------------------------------------------------------------
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

-- Vendas (valor_total e pontos começam em 0 e são calculados pelos triggers)
INSERT INTO tbl_vendas (id_venda, data_hora, num_caixa, id_cliente, id_colaborador) VALUES
  (1,'2026-09-28 10:15:00',2,1,1),
  (2,'2026-09-28 11:40:00',2,2,1),
  (3,'2026-09-29 18:05:00',1,NULL,1),   -- cliente não identificado
  (4,'2026-10-01 09:30:00',3,1,1);

INSERT INTO tbl_itens_venda (id_venda, id_produto, quantidade, preco_unitario, desconto) VALUES
  (1,1,1,24.90,0), (1,2,2,8.99,0), (1,3,3,5.49,0), (1,4,2.000,5.99,0),
  (2,5,2,9.49,0),  (2,6,3,2.99,0),
  (3,3,2,5.49,0),  (3,1,1,24.90,2.00),
  (4,3,4,5.49,0),  (4,4,1.000,5.99,0);

-- Pagamentos (a venda 1 foi dividida entre dinheiro e Pix)
INSERT INTO tbl_pagamentos_venda (id_venda, id_forma_pagamento, valor) VALUES
  (1,1,30.00), (1,4,41.33),
  (2,3,27.95),
  (3,2,33.88),
  (4,4,27.95);

-- ---------------------------------------------------------------------
-- 11. Consultas de apoio à fidelização de clientes
-- ---------------------------------------------------------------------

-- 11.1 Produtos mais comprados por cada cliente (base para ofertas direcionadas)
SELECT c.nome AS cliente, p.nome AS produto,
       SUM(i.quantidade) AS qtd_total,
       COUNT(DISTINCT v.id_venda) AS compras
  FROM tbl_vendas v
  JOIN tbl_clientes c     ON c.id_cliente = v.id_cliente
  JOIN tbl_itens_venda i  ON i.id_venda   = v.id_venda
  JOIN tbl_produtos p     ON p.id_produto = i.id_produto
 WHERE v.status = 'CONCLUIDA'
 GROUP BY c.id_cliente, c.nome, p.id_produto, p.nome
 ORDER BY c.nome, qtd_total DESC;

-- 11.2 Clientes que aceitam ofertas e não compram há mais de 60 dias
SELECT c.nome, c.email, c.telefone, MAX(v.data_hora) AS ultima_compra
  FROM tbl_clientes c
  JOIN tbl_vendas v ON v.id_cliente = c.id_cliente AND v.status = 'CONCLUIDA'
 WHERE c.aceita_ofertas = 1
 GROUP BY c.id_cliente, c.nome, c.email, c.telefone
HAVING MAX(v.data_hora) < DATE_SUB(NOW(), INTERVAL 60 DAY);

-- 11.3 Número de compras, ticket médio e saldo de pontos por cliente
SELECT c.nome, COUNT(*) AS compras,
       ROUND(AVG(v.valor_total), 2) AS ticket_medio,
       c.pontos_fidelidade
  FROM tbl_clientes c
  JOIN tbl_vendas v ON v.id_cliente = c.id_cliente AND v.status = 'CONCLUIDA'
 GROUP BY c.id_cliente, c.nome, c.pontos_fidelidade;

-- 11.4 Produtos ativos com estoque abaixo ou igual ao mínimo (reposição)
SELECT nome, qtd_estoque, estoque_minimo
  FROM tbl_produtos
 WHERE ativo = 1 AND qtd_estoque <= estoque_minimo;

-- 11.5 Conferência dos dados de exemplo (valores esperados nos comentários)
--      venda 1: 71.33 / 71 pts | venda 2: 27.95 / 27 | venda 3: 33.88 / 33 | venda 4: 27.95 / 27
SELECT id_venda, valor_total, pontos_gerados FROM tbl_vendas ORDER BY id_venda;
