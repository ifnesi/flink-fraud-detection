-- Create the users_config table if it does not exist
CREATE TABLE IF NOT EXISTS users_config (
    user_id TEXT PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    max_speed REAL
);

-- Insert initial data into users_config table
INSERT INTO users_config (user_id, first_name, last_name, max_speed) VALUES
  ('user_1', 'Lena', 'Whitaker', 10),
  ('user_2', 'Elias', 'Monroe', 100),
  ('user_3', 'Nina', 'Langston', 1000),
  ('user_4', 'Jordan', 'Blake', 99999)
ON CONFLICT (user_id) DO NOTHING;