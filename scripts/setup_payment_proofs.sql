-- ========================================
-- Kameti Phase 1: Payment Proof Upload System
-- ========================================
-- Run this in Supabase SQL Editor.

-- 1) Add proof/payment method columns to payments
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS payment_method TEXT NULL;

-- 2) Payment proofs table
CREATE TABLE IF NOT EXISTS payment_proofs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id TEXT NOT NULL,
  committee_id TEXT NOT NULL REFERENCES committees(id) ON DELETE CASCADE,
  member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  host_id TEXT NOT NULL,
  cloudinary_url TEXT NOT NULL,
  cloudinary_public_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  rejection_reason TEXT NULL,
  reviewed_by TEXT NULL,
  reviewed_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_proofs_payment_id ON payment_proofs(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_proofs_host_id ON payment_proofs(host_id);
CREATE INDEX IF NOT EXISTS idx_payment_proofs_member_id ON payment_proofs(member_id);
CREATE INDEX IF NOT EXISTS idx_payment_proofs_status ON payment_proofs(status);

-- 3) fcm tokens
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL UNIQUE,
  token TEXT NOT NULL,
  device_type TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 4) updated_at helper trigger
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_proofs_updated_at ON payment_proofs;
CREATE TRIGGER trg_payment_proofs_updated_at
BEFORE UPDATE ON payment_proofs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at_timestamp();

DROP TRIGGER IF EXISTS trg_fcm_tokens_updated_at ON fcm_tokens;
CREATE TRIGGER trg_fcm_tokens_updated_at
BEFORE UPDATE ON fcm_tokens
FOR EACH ROW
EXECUTE FUNCTION set_updated_at_timestamp();

-- 5) Auto-mark payment paid on approval
CREATE OR REPLACE FUNCTION auto_mark_payment_paid()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND COALESCE(OLD.status, '') != 'approved' THEN
    UPDATE payments
    SET is_paid = TRUE,
        proof_status = 'approved',
        marked_at = NOW(),
        marked_by = NEW.host_id
    WHERE id = NEW.payment_id;
  END IF;

  IF NEW.status = 'pending' AND COALESCE(OLD.status, '') != 'pending' THEN
    UPDATE payments
    SET proof_status = 'pending'
    WHERE id = NEW.payment_id;
  END IF;

  IF NEW.status = 'rejected' AND COALESCE(OLD.status, '') != 'rejected' THEN
    UPDATE payments
    SET proof_status = 'rejected'
    WHERE id = NEW.payment_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_proof_status_change ON payment_proofs;
CREATE TRIGGER on_proof_status_change
AFTER UPDATE ON payment_proofs
FOR EACH ROW
EXECUTE FUNCTION auto_mark_payment_paid();

-- 6) RLS
ALTER TABLE payment_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS host_select_committee_proofs ON payment_proofs;
CREATE POLICY host_select_committee_proofs
ON payment_proofs FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS member_insert_proof ON payment_proofs;
CREATE POLICY member_insert_proof
ON payment_proofs FOR INSERT
TO anon, authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS host_update_proof_status ON payment_proofs;
CREATE POLICY host_update_proof_status
ON payment_proofs FOR UPDATE
TO authenticated
USING (host_id = auth.uid()::text)
WITH CHECK (host_id = auth.uid()::text);

DROP POLICY IF EXISTS users_manage_own_token ON fcm_tokens;
CREATE POLICY users_manage_own_token
ON fcm_tokens FOR ALL
TO authenticated
USING (user_id = auth.uid()::text)
WITH CHECK (user_id = auth.uid()::text);

-- Verification helpers
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('payment_proofs', 'fcm_tokens')
ORDER BY tablename, policyname;
