const { Sequelize } = require('sequelize');
const dbConfig = require('../config/database');

const options = {
  host: dbConfig.host,
  port: dbConfig.port,
  dialect: 'postgres',
  logging: dbConfig.logging,
  pool: dbConfig.pool
};

if (dbConfig.dialectOptions) {
  options.dialectOptions = dbConfig.dialectOptions;
}

const sequelize = new Sequelize(
  dbConfig.database,
  dbConfig.username,
  dbConfig.password,
  options
);

const User = require('./user')(sequelize);

module.exports = {
  sequelize,
  User
};
