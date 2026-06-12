const pool = require('./index');

async function setup() {
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
  `);
}

module.exports = setup;
