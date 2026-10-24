const fs = require('fs');

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function sslConfig() {
  const mode = process.env.USER_DB_SSLMODE || 'disable';
  if (mode === 'disable') {
    return undefined;
  }

  if (mode === 'verify-full') {
    const ssl = { require: true, rejectUnauthorized: true };
    const caPath = process.env.USER_DB_SSL_ROOT_CERT;
    if (caPath) {
      ssl.ca = fs.readFileSync(caPath, 'utf8');
    }
    return ssl;
  }

  return { require: true, rejectUnauthorized: false };
}

const writeHost = process.env.USER_DB_HOST || 'localhost';
const readHost = process.env.USER_DB_READ_HOST || '';
const ssl = sslConfig();

module.exports = {
  username: process.env.USER_DB_USER || 'ecommerce_user',
  password: process.env.USER_DB_PASSWORD || 'secure_password_123',
  database: process.env.USER_DB_NAME || 'users',
  host: writeHost,
  port: intEnv('USER_DB_PORT', 5432),
  logging: false,
  pool: {
    max: intEnv('USER_DB_MAX_OPEN_CONNS', 10),
    min: 0,
    acquire: 30000,
    idle: 10000
  },
  dialectOptions: ssl ? { ssl } : undefined,
  readHost,
  readHostActive: readHost !== '' && readHost !== writeHost
};
