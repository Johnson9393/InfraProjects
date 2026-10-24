-- Baseline order schema.
-- CREATE TABLE IF NOT EXISTS does not change rows or columns that already exist.

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    total_amount DOUBLE PRECISION NOT NULL,
    tax DOUBLE PRECISION NOT NULL DEFAULT 0,
    shipping_address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    zip_code VARCHAR(20),
    country VARCHAR(100),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders (user_id);

CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);

CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    quantity BIGINT NOT NULL,
    subtotal DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items (order_id);
