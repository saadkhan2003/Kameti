-- Add skipped_dates column to committees table
-- Stores ISO date strings for collection days the host has skipped
ALTER TABLE committees ADD COLUMN IF NOT EXISTS skipped_dates text[] DEFAULT '{}';
