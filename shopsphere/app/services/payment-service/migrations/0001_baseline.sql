-- Baseline payment schema.
-- CREATE TABLE IF NOT EXISTS does not change rows or columns that already exist.

CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(255) NOT NULL,
    razorpay_order_id VARCHAR(255),
    razorpay_payment_id VARCHAR(255),
    razorpay_signature VARCHAR(500),
    amount DOUBLE PRECISION NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    status VARCHAR(50) DEFAULT 'created',
    user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_payments_order_id ON payments (order_id);

CREATE UNIQUE INDEX IF NOT EXISTS ix_payments_razorpay_order_id ON payments (razorpay_order_id);

CREATE UNIQUE INDEX IF NOT EXISTS ix_payments_razorpay_payment_id ON payments (razorpay_payment_id);

CREATE INDEX IF NOT EXISTS ix_payments_status ON payments (status);
