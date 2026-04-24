CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (name, email) VALUES
    ('Paul Smith', 'paul@example.com'),
    ('Jane Doe', 'jane@example.com'),
    ('Bob Jones', 'bob@example.com');
