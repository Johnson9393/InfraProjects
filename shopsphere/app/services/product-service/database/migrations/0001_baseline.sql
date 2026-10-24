-- Baseline product schema.
-- CREATE TABLE IF NOT EXISTS does not change rows or columns that already exist.

CREATE TABLE IF NOT EXISTS products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DOUBLE PRECISION NOT NULL,
    stock BIGINT NOT NULL DEFAULT 0,
    category VARCHAR(100) NOT NULL,
    image_url VARCHAR(500),
    images TEXT[],
    sku VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_sku ON products (sku);

CREATE INDEX IF NOT EXISTS idx_products_name ON products (name);

CREATE INDEX IF NOT EXISTS idx_products_price ON products (price);

CREATE INDEX IF NOT EXISTS idx_products_category ON products (category);

CREATE INDEX IF NOT EXISTS idx_products_is_active ON products (is_active);

CREATE INDEX IF NOT EXISTS idx_products_deleted_at ON products (deleted_at);
