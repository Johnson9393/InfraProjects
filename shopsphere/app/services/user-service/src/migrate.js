const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const dbConfig = require('./config/database');

function splitSQL(script) {
  const out = [];
  let current = '';

  for (const line of script.split('\n')) {
    const trim = line.trim();
    if (trim.startsWith('--')) {
      continue;
    }
    current += `${line}\n`;
    if (trim.endsWith(';')) {
      const stmt = current.trim().replace(/;$/, '').trim();
      if (stmt) {
        out.push(stmt);
      }
      current = '';
    }
  }

  const rest = current.trim().replace(/;$/, '').trim();
  if (rest) {
    out.push(rest);
  }
  return out;
}

function clientConfig() {
  const config = {
    host: dbConfig.host,
    port: dbConfig.port,
    user: dbConfig.username,
    password: dbConfig.password,
    database: dbConfig.database
  };
  if (dbConfig.dialectOptions && dbConfig.dialectOptions.ssl) {
    config.ssl = dbConfig.dialectOptions.ssl;
  }
  return config;
}

async function connect() {
  let lastError;
  for (let attempt = 1; attempt <= 5; attempt += 1) {
    const client = new Client(clientConfig());
    try {
      await client.connect();
      return client;
    } catch (error) {
      lastError = error;
      console.error(`database connection failed (${attempt}/5): ${error.message}`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }
  throw lastError;
}

async function applyMigrations(client) {
  await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    version text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
  )`);

  const dir = path.join(__dirname, 'migrations');
  const files = fs.readdirSync(dir).filter((name) => name.endsWith('.sql')).sort();

  for (const name of files) {
    const version = name.replace(/\.sql$/, '');
    const existing = await client.query(
      'SELECT COUNT(*)::int AS count FROM schema_migrations WHERE version = $1',
      [version]
    );
    if (existing.rows[0].count > 0) {
      console.log(`migration already applied: ${version}`);
      continue;
    }

    const body = fs.readFileSync(path.join(dir, name), 'utf8');
    try {
      await client.query('BEGIN');
      for (const stmt of splitSQL(body)) {
        await client.query(stmt);
      }
      await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [version]);
      await client.query('COMMIT');
      console.log(`migration applied: ${version}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }
  }
}

async function main() {
  if (dbConfig.readHostActive) {
    console.log('USER_DB_READ_HOST is set; user reads and writes stay on the writer');
  }
  const client = await connect();
  try {
    await applyMigrations(client);
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
