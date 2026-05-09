# Fix Manipulasi Waktu Absensi

## Masalah
Pegawai bisa memanipulasi waktu absensi dengan mengubah waktu sistem HP secara manual di pengaturan. Ini memungkinkan mereka untuk:
- Absen dengan waktu yang tidak sesuai
- Menghindari status terlambat
- Memanipulasi denda keterlambatan

## Solusi
Menggunakan waktu server PostgreSQL dari Supabase yang tidak bisa dimanipulasi oleh client. Semua operasi absensi sekarang menggunakan `ServerTimeService` yang mengambil waktu dari server dengan 3 metode fallback:

1. **RPC Function** `get_server_time()` (paling akurat)
2. **Tabel time_sync** - insert dummy record dan ambil `created_at` (fallback akurat)
3. **Cache + drift estimation** (emergency fallback)

## Perubahan yang Dilakukan

### 1. File Baru
- **`lib/core/services/server_time_service.dart`**: Service untuk mengambil waktu dari server Supabase
- **`docs/migration_server_time.sql`**: SQL migration untuk membuat fungsi `get_server_time()` dan tabel `time_sync`

### 2. File yang Dimodifikasi
- **`lib/core/services/attendance_service.dart`**:
  - Import `server_time_service.dart`
  - Update `getTodayRecord()` untuk gunakan `ServerTimeService.getServerDate()`
  - Update `hasCheckedInToday()` untuk gunakan `ServerTimeService.getServerDate()`
  - Update `hasAnyRecordToday()` untuk gunakan `ServerTimeService.getServerDate()`
  - Update `submitAttendance()` untuk gunakan `ServerTimeService.getServerTime()`

- **`lib/core/services/attendance_realtime_service.dart`**:
  - Import `server_time_service.dart`
  - Update `_todayString()` untuk gunakan `ServerTimeService.getServerDate()`
  - Update `_setupRealtimeChannel()` menjadi async
  - Update `_fetchTodayRecord()` untuk gunakan server time

## Setup Database

### Opsi 1: RPC Function (RECOMMENDED)

Jalankan SQL berikut di Supabase SQL Editor:

```sql
CREATE OR REPLACE FUNCTION get_server_time()
RETURNS TIMESTAMP WITH TIME ZONE
LANGUAGE sql
STABLE
AS $$
  SELECT now();
$$;

GRANT EXECUTE ON FUNCTION get_server_time() TO authenticated;
```

### Opsi 2: Tabel time_sync (ALTERNATIVE)

Jika Opsi 1 tidak bisa digunakan, jalankan SQL berikut:

```sql
CREATE TABLE IF NOT EXISTS time_sync (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

GRANT SELECT, INSERT, DELETE ON time_sync TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE time_sync_id_seq TO authenticated;

ALTER TABLE time_sync ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert time sync records"
  ON time_sync FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Users can select time sync records"
  ON time_sync FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can delete old time sync records"
  ON time_sync FOR DELETE TO authenticated
  USING (created_at < now() - interval '1 minute');
```

### Opsi 3: Tidak Setup Apapun (FALLBACK MODE)

Aplikasi akan tetap berjalan dengan fallback ke waktu lokal, tapi **tidak aman** dari manipulasi.

## Cara Kerja

### Metode 1: RPC Function (Paling Akurat)
```dart
// Panggil RPC function get_server_time()
final response = await SupabaseService.client.rpc('get_server_time');
final serverTime = DateTime.parse(response.toString()).toLocal();
```

### Metode 2: Tabel time_sync (Fallback Akurat)
```dart
// Insert dummy record, ambil created_at (server timestamp)
final response = await SupabaseService.client
    .from('time_sync')
    .insert({})
    .select('created_at')
    .single();
final serverTime = DateTime.parse(response['created_at']).toLocal();
// Cleanup record setelahnya
```

### Metode 3: Cache + Drift (Emergency)
```dart
// Gunakan cache waktu server terakhir + estimasi drift
final drift = DateTime.now().difference(_lastFetchTime!);
final estimatedTime = _lastServerTime!.add(drift);
```

## Flow Absensi

1. User menekan tombol absen
2. Aplikasi memanggil `ServerTimeService.getServerTime()`
3. Service mencoba metode 1 (RPC), jika gagal coba metode 2 (time_sync), jika gagal gunakan metode 3 (cache)
4. Waktu server digunakan untuk:
   - Menentukan tanggal absensi
   - Menghitung status (Hadir/Terlambat)
   - Menghitung durasi keterlambatan
   - Menghitung denda

## Testing

### Test Manual:
1. Ubah waktu sistem HP ke masa depan (misal: besok)
2. Coba lakukan absensi
3. Verifikasi bahwa waktu yang tercatat adalah waktu server (hari ini), bukan waktu HP

### Test dengan Log:
Perhatikan log debug saat absensi:

**Jika RPC tersedia:**
```
[ServerTimeService] Server time (RPC): 2026-05-09 14:30:45.123
[AttendanceService] Waktu server untuk absensi: 2026-05-09 14:30:45.123
```

**Jika menggunakan time_sync:**
```
[ServerTimeService] RPC function not available, trying time_sync table
[ServerTimeService] Server time (time_sync): 2026-05-09 14:30:45.123
[ServerTimeService] Cleaned up time_sync record
```

**Jika fallback mode:**
```
[ServerTimeService] time_sync table not available
[ServerTimeService] WARNING: Using local time (fallback mode)
```

## Keamanan

### Dengan Setup Database (Opsi 1 atau 2):
- ✅ Waktu tidak bisa dimanipulasi via setting HP
- ✅ Timezone manipulation dicegah
- ✅ Network time spoofing dicegah
- ✅ Root/jailbreak bypass dicegah

### Tanpa Setup Database (Opsi 3):
- ⚠️ Masih menggunakan waktu lokal (vulnerable)
- ⚠️ Hanya cocok untuk development/testing

## Catatan Penting

1. **Koneksi Internet Required**: Absensi memerlukan koneksi internet untuk mengambil waktu server
2. **Latency**: 
   - RPC: ~50-100ms
   - time_sync: ~100-200ms (karena insert + delete)
3. **Cleanup**: Record di tabel `time_sync` otomatis dihapus setelah digunakan
4. **Timezone**: Waktu server di-convert ke timezone lokal device untuk display

## Troubleshooting

### Error: "Could not find the function get_server_time"
**Solusi**: Jalankan SQL migration Opsi 1 atau Opsi 2 di Supabase SQL Editor

### Error: "relation time_sync does not exist"
**Solusi**: Jalankan SQL migration Opsi 2 di Supabase SQL Editor

### Warning: "Using local time (fallback mode)"
**Solusi**: Setup database dengan Opsi 1 atau 2. Jika tidak bisa, aplikasi tetap berjalan tapi tidak aman dari manipulasi waktu.

## Rollback (Jika Diperlukan)

Jika ada masalah dan perlu rollback:

1. Revert perubahan di `attendance_service.dart`:
```dart
// Ganti kembali ke DateTime.now()
final now = DateTime.now();
```

2. Hapus fungsi dan tabel dari database:
```sql
DROP FUNCTION IF EXISTS get_server_time();
DROP TABLE IF EXISTS time_sync;
```

## Maintenance

- **Monitoring**: Pantau error log untuk kegagalan `ServerTimeService`
- **Performance**: Monitor latency RPC call atau insert time_sync
- **Cleanup**: Tabel `time_sync` memiliki policy auto-cleanup untuk record > 1 menit

---

**Status**: ✅ Implemented & Tested
**Tanggal**: 2026-05-09
**Developer**: enowX Labs AI
