-- Migration: Add server time sync functionality
-- Digunakan untuk mencegah manipulasi waktu absensi melalui setting HP.

-- Opsi 1: Buat RPC function untuk get server time (RECOMMENDED)
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS TIMESTAMP WITH TIME ZONE
LANGUAGE sql
STABLE
AS $$
  SELECT now();
$$;

-- Grant execute permission ke authenticated users
GRANT EXECUTE ON FUNCTION get_server_time() TO authenticated;

COMMENT ON FUNCTION get_server_time() IS 'Mengembalikan waktu server PostgreSQL untuk mencegah manipulasi waktu client';

-- Opsi 2: Buat tabel untuk time sync (ALTERNATIVE jika RPC tidak bisa digunakan)
-- Tabel ini digunakan untuk insert dummy record dan ambil server timestamp
CREATE TABLE IF NOT EXISTS time_sync (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON time_sync TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE time_sync_id_seq TO authenticated;

-- Enable RLS
ALTER TABLE time_sync ENABLE ROW LEVEL SECURITY;

-- Policy: authenticated users bisa insert dan select own records
CREATE POLICY "Users can insert time sync records"
  ON time_sync
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can select time sync records"
  ON time_sync
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete old time sync records"
  ON time_sync
  FOR DELETE
  TO authenticated
  USING (created_at < now() - interval '1 minute');

COMMENT ON TABLE time_sync IS 'Tabel untuk sinkronisasi waktu server (mencegah manipulasi waktu client)';

-- Buat function untuk cleanup otomatis (opsional)
CREATE OR REPLACE FUNCTION cleanup_time_sync()
RETURNS void
LANGUAGE sql
AS $$
  DELETE FROM time_sync WHERE created_at < now() - interval '1 hour';
$$;

COMMENT ON FUNCTION cleanup_time_sync() IS 'Cleanup time sync records yang sudah lama';

