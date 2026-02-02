-- Remote Config Table for Force Update Feature
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS app_config (
  id SERIAL PRIMARY KEY,
  config_key TEXT UNIQUE NOT NULL,
  config_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Allow public read access (anyone can check version)
CREATE POLICY "Allow public read access"
  ON app_config
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Only authenticated users with special role can update (for admin panel later)
CREATE POLICY "Allow admin update"
  ON app_config
  FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin');

-- Insert default configuration
INSERT INTO app_config (config_key, config_value, description) VALUES
  ('min_android_version', '1.0.0', 'Minimum required Android app version'),
  ('min_ios_version', '1.0.0', 'Minimum required iOS app version'),
  ('force_update_enabled', 'false', 'Enable force update feature'),
  ('update_message_title', 'Update Required', 'Title for force update dialog'),
  ('update_message_body', 'Please update to the latest version to continue using the app.', 'Message for force update dialog'),
  ('playstore_url', 'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME', 'Google Play Store URL'),
  ('appstore_url', 'https://apps.apple.com/app/YOUR_APP_ID', 'Apple App Store URL'),
  ('admin_pin', '1234', 'Admin panel access PIN (4 digits)')
ON CONFLICT (config_key) DO NOTHING;

-- Function to easily update config values
CREATE OR REPLACE FUNCTION update_config(key TEXT, value TEXT)
RETURNS void AS $$
BEGIN
  UPDATE app_config 
  SET config_value = value, updated_at = NOW()
  WHERE config_key = key;
END;
$$ LANGUAGE plpgsql;

-- Example usage:
-- SELECT update_config('min_android_version', '2.0.0');
-- SELECT update_config('force_update_enabled', 'true');
