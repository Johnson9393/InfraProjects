-- Run this after rds-init-databases.sql
-- as shopsphere_admin, still connected to "postgres".
-- No passwords in this file. Set each user password once from Secrets Manager
-- (prod/product-db-credentials, user-db-credentials, order-db-credentials,
-- payment-db-credentials). After that, weekly rotation updates them.

CREATE USER product_user WITH LOGIN;
CREATE USER user_user WITH LOGIN;
CREATE USER order_user WITH LOGIN;
CREATE USER payment_user WITH LOGIN;

-- Each user owns only their database. That is enough for migrations and the app.
ALTER DATABASE products OWNER TO product_user;
ALTER DATABASE users OWNER TO user_user;
ALTER DATABASE orders OWNER TO order_user;
ALTER DATABASE payments OWNER TO payment_user;
