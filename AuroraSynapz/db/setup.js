const pool = require('./index');

async function setup() {
  // Core tables
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id         SERIAL PRIMARY KEY,
      name       TEXT        NOT NULL,
      email      TEXT        NOT NULL UNIQUE,
      password   TEXT        NOT NULL,
      role       TEXT        NOT NULL DEFAULT 'client',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS contacts (
      id         SERIAL PRIMARY KEY,
      first_name TEXT        NOT NULL,
      last_name  TEXT        NOT NULL,
      email      TEXT        NOT NULL,
      phone      TEXT,
      service    TEXT,
      assets     TEXT,
      message    TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS portfolios (
      id             SERIAL PRIMARY KEY,
      user_id        INTEGER     NOT NULL UNIQUE REFERENCES users(id),
      total_value    NUMERIC     NOT NULL DEFAULT 0,
      cash_balance   NUMERIC     NOT NULL DEFAULT 0,
      day_change     NUMERIC     NOT NULL DEFAULT 0,
      day_change_pct NUMERIC     NOT NULL DEFAULT 0,
      ytd_return     NUMERIC     NOT NULL DEFAULT 0,
      ytd_return_pct NUMERIC     NOT NULL DEFAULT 0,
      inception_date DATE        NOT NULL DEFAULT CURRENT_DATE,
      updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS holdings (
      id          SERIAL PRIMARY KEY,
      user_id     INTEGER NOT NULL REFERENCES users(id),
      symbol      TEXT    NOT NULL,
      name        TEXT    NOT NULL,
      asset_class TEXT    NOT NULL,
      shares      NUMERIC NOT NULL,
      price       NUMERIC NOT NULL,
      avg_cost    NUMERIC NOT NULL,
      day_change  NUMERIC NOT NULL DEFAULT 0,
      day_chg_pct NUMERIC NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id         SERIAL PRIMARY KEY,
      user_id    INTEGER     NOT NULL REFERENCES users(id),
      type       TEXT        NOT NULL,
      symbol     TEXT,
      name       TEXT,
      shares     NUMERIC,
      price      NUMERIC,
      amount     NUMERIC     NOT NULL,
      note       TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS performance_history (
      id      SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id),
      date    DATE    NOT NULL,
      value   NUMERIC NOT NULL
    );

    CREATE TABLE IF NOT EXISTS documents (
      id         SERIAL PRIMARY KEY,
      user_id    INTEGER     NOT NULL REFERENCES users(id),
      title      TEXT        NOT NULL,
      type       TEXT        NOT NULL,
      period     TEXT        NOT NULL,
      size_kb    INTEGER     NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS stripe_payments (
      id                       SERIAL PRIMARY KEY,
      user_id                  INTEGER     NOT NULL REFERENCES users(id),
      stripe_payment_intent_id TEXT        NOT NULL UNIQUE,
      amount                   NUMERIC     NOT NULL,
      status                   TEXT        NOT NULL DEFAULT 'pending',
      created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS alpaca_sync_log (
      id              SERIAL PRIMARY KEY,
      user_id         INTEGER     NOT NULL REFERENCES users(id),
      account_value   NUMERIC,
      positions_count INTEGER,
      synced_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE UNIQUE INDEX IF NOT EXISTS perf_history_user_date
      ON performance_history (user_id, date);
  `);

  // Fund table — single row representing the pooled Alpaca account
  await pool.query(`
    CREATE TABLE IF NOT EXISTS fund (
      id           INTEGER     PRIMARY KEY DEFAULT 1,
      total_value  NUMERIC     NOT NULL DEFAULT 0,
      total_units  NUMERIC     NOT NULL DEFAULT 0,
      unit_price   NUMERIC     NOT NULL DEFAULT 1,
      updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    INSERT INTO fund (id, total_value, total_units, unit_price)
    VALUES (1, 0, 0, 1)
    ON CONFLICT (id) DO NOTHING;
  `);

  // Add units_owned to portfolios (migration — safe to run multiple times)
  await pool.query(`
    ALTER TABLE portfolios ADD COLUMN IF NOT EXISTS units_owned NUMERIC NOT NULL DEFAULT 0;
  `);

  // Withdrawal requests table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS withdrawal_requests (
      id             SERIAL PRIMARY KEY,
      user_id        INTEGER     NOT NULL REFERENCES users(id),
      amount         NUMERIC     NOT NULL,
      units_redeemed NUMERIC     NOT NULL,
      unit_price     NUMERIC     NOT NULL,
      status         TEXT        NOT NULL DEFAULT 'pending',
      notes          TEXT,
      created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      processed_at   TIMESTAMPTZ
    );
  `);

  // One-time migration: seed fund and units from existing portfolio data
  // Only runs if fund has no units but portfolios already have value
  await pool.query(`
    DO $$
    BEGIN
      IF (SELECT total_units FROM fund WHERE id = 1) = 0
         AND EXISTS (SELECT 1 FROM portfolios WHERE total_value > 0) THEN

        -- Give each existing client units equal to their current total_value
        -- at an initial unit price of $1.00
        UPDATE portfolios SET units_owned = total_value WHERE total_value > 0;

        -- Initialise the fund from the sum of those portfolios
        UPDATE fund SET
          total_units = (SELECT COALESCE(SUM(units_owned), 0) FROM portfolios),
          total_value = (SELECT COALESCE(SUM(total_value),  0) FROM portfolios),
          unit_price  = 1,
          updated_at  = NOW()
        WHERE id = 1;

      END IF;
    END;
    $$;
  `);
}

module.exports = setup;
