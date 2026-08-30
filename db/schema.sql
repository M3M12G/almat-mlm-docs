-- ============================================================
-- Almat MLM — черновая схема БД (PostgreSQL)
-- Применять через EF Core Migrations, не выполнять вручную на проде.
-- ============================================================

-- ---------- Пользователи и сеть ----------

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sponsor_id      UUID REFERENCES users(id),
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone           VARCHAR(32),
    referral_code   VARCHAR(32) UNIQUE NOT NULL,
    rank_id         INT REFERENCES ranks(id),
    total_team_volume NUMERIC(18,2) DEFAULT 0,  -- материализованный агрегат
    is_active_period BOOLEAN DEFAULT FALSE,     -- активность в текущем периоде
    created_at      TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT no_self_sponsor CHECK (id != sponsor_id)
);

CREATE INDEX idx_users_sponsor_id ON users(sponsor_id);

-- ---------- Продукты / пакеты ----------

CREATE TABLE packages (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,      -- START / BUSINESS / PREMIUM
    price       NUMERIC(18,2) NOT NULL,
    lp_value    NUMERIC(18,2) NOT NULL,     -- Life Points для расчёта бонусов
    description TEXT
);

-- ---------- Покупки ----------

CREATE TABLE purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id        UUID NOT NULL REFERENCES users(id),
    package_id      INT REFERENCES packages(id),
    amount          NUMERIC(18,2) NOT NULL,
    lp              NUMERIC(18,2) NOT NULL,
    payment_provider_tx_id VARCHAR(255) UNIQUE,  -- для идемпотентности вебхуков
    status          VARCHAR(32) NOT NULL DEFAULT 'pending', -- pending/paid/failed
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_purchases_buyer_id ON purchases(buyer_id);
CREATE INDEX idx_purchases_created_at ON purchases(created_at);

-- ---------- Правила начисления (данные, не код) ----------

CREATE TABLE bonus_rules (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(64) UNIQUE NOT NULL,  -- 'direct_bonus', 'unilevel_bonus', ...
    type        VARCHAR(32) NOT NULL,
    config_json JSONB NOT NULL,               -- проценты, уровни, пороги
    active_from TIMESTAMPTZ DEFAULT now(),
    active_to   TIMESTAMPTZ
);

-- Пример config_json для unilevel_bonus:
-- {"levels": [2,2,2,2,2,2,2,2,2,2], "requires_active": true}

-- ---------- Ledger начислений (append-only, неизменяемый) ----------

CREATE TABLE bonus_transactions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code           VARCHAR(64) NOT NULL REFERENCES bonus_rules(code),
    source_purchase_id  UUID REFERENCES purchases(id),
    from_user_id        UUID REFERENCES users(id),
    to_user_id          UUID NOT NULL REFERENCES users(id),
    level               INT,                 -- для unilevel — номер уровня
    amount              NUMERIC(18,2) NOT NULL,
    period              VARCHAR(7),          -- 'YYYY-MM' для периодных начислений
    status              VARCHAR(32) NOT NULL DEFAULT 'accrued', -- accrued/paid/reversed
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_bonus_tx_to_user ON bonus_transactions(to_user_id);
CREATE INDEX idx_bonus_tx_source_purchase ON bonus_transactions(source_purchase_id);
CREATE INDEX idx_bonus_tx_period ON bonus_transactions(period);

-- ---------- Ранги ----------

CREATE TABLE ranks (
    id                  SERIAL PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    "order"             INT NOT NULL,             -- порядок в карьерной лестнице
    required_condition_json JSONB NOT NULL,        -- условие достижения
    one_time_bonus      NUMERIC(18,2) NOT NULL,
    leadership_pool_points INT DEFAULT 0           -- баллы для Leadership Pool
);

CREATE TABLE rank_achievements (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id),
    rank_id     INT NOT NULL REFERENCES ranks(id),
    achieved_at TIMESTAMPTZ DEFAULT now(),
    bonus_paid  BOOLEAN DEFAULT FALSE
);

-- ---------- Leadership Pool ----------

CREATE TABLE pool_periods (
    id              SERIAL PRIMARY KEY,
    period          VARCHAR(7) UNIQUE NOT NULL,   -- 'YYYY-MM'
    world_turnover  NUMERIC(18,2) NOT NULL,
    pool_amount     NUMERIC(18,2) NOT NULL,       -- 2% от world_turnover
    total_points    INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE pool_distributions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id   INT NOT NULL REFERENCES pool_periods(id),
    user_id     UUID NOT NULL REFERENCES users(id),
    rank_id     INT NOT NULL REFERENCES ranks(id),
    points      INT NOT NULL,
    amount      NUMERIC(18,2) NOT NULL
);

-- ---------- Выплаты (вывод средств) ----------

CREATE TABLE withdrawal_requests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    amount          NUMERIC(18,2) NOT NULL,
    status          VARCHAR(32) NOT NULL DEFAULT 'pending', -- pending/approved/rejected/paid
    requested_at    TIMESTAMPTZ DEFAULT now(),
    processed_at    TIMESTAMPTZ,
    processed_by    UUID REFERENCES users(id)  -- админ, подтвердивший выплату
);

-- ---------- Бухучёт (минимальный) ----------

CREATE TABLE accounting_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_type      VARCHAR(32) NOT NULL,   -- debit/credit
    amount          NUMERIC(18,2) NOT NULL,
    source_type     VARCHAR(32) NOT NULL,   -- 'purchase' / 'bonus' / 'withdrawal'
    source_id       UUID NOT NULL,          -- ссылка на purchases/bonus_transactions/withdrawal_requests
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ---------- Audit log (безопасность) ----------

CREATE TABLE audit_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id    UUID REFERENCES users(id),
    action      VARCHAR(100) NOT NULL,
    entity_type VARCHAR(64),
    entity_id   UUID,
    metadata    JSONB,
    created_at  TIMESTAMPTZ DEFAULT now()
);
