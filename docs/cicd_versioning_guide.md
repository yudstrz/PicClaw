# Panduan Teknis CI/CD dan Manajemen Versi: PicClaw

Dokumen ini menyediakan panduan operasional untuk melakukan otomatisasi perilisan menggunakan alur kerja GitHub Actions yang telah dikonfigurasi, serta langkah sinkronisasi nomor versi berdasarkan kaidah Semantic Versioning (SemVer).

---

## 1. Panduan Sinkronisasi Versi

Di dalam ekosistem Flutter, versi aplikasi diatur melalui berkas `pubspec.yaml` pada baris:

```yaml
version: 1.1.0+2
```

Format penomoran ini terdiri dari dua bagian yang dipisahkan oleh tanda tambah (+):
- Version Name (Sebelum tanda +): Representasi versi komersial berbasis SemVer (MAJOR.MINOR.PATCH), contoh: `1.1.0`. Bagian ini digunakan oleh pengguna untuk mengidentifikasi tingkat pembaruan aplikasi.
- Version Code / Build Number (Setelah tanda +): Nilai integer positif yang harus naik secara monoton pada setiap perilisan build baru (misalnya dari `1` ke `2`, lalu ke `3`), contoh: `2`. Sistem operasi Android menggunakan nomor ini untuk menentukan apakah suatu berkas APK merupakan pembaruan (upgrade) dari berkas APK yang sudah terpasang.

### Aturan Praktis Penyelarasan Versi
Untuk menghindari ketidakcocokan antara metadata internal berkas APK dengan informasi rilis pada repositori GitHub, ikuti protokol kerja berikut:

1. Perbarui pubspec.yaml Terlebih Dahulu: Sebelum membuat tag rilis di Git, ubah nilai `version` di `pubspec.yaml` agar sesuai dengan rencana rilis. Contohnya, ubah menjadi `1.1.0+2`.
2. Lakukan Commit Pembaruan Versi: Simpan perubahan `pubspec.yaml` ke dalam riwayat commit Git lokal sebelum tag dibuat. Hal ini memastikan bahwa kode sumber pada titik rilis benar-benar memiliki deklarasi versi yang sinkron secara internal.
3. Buat Tag Git yang Identik: Buat tag rilis yang merepresentasikan nilai Version Name dengan tambahan karakter 'v' di depannya (contoh: `v1.1.0`). Tag harus merujuk pada commit pembaruan versi yang telah dibuat pada langkah sebelumnya.
4. Risiko Ketidakcocokan: Jika Anda membuat tag `v1.1.0` tetapi lupa memperbarui berkas `pubspec.yaml` (misal masih tertulis `1.0.0+1`), maka alur kerja CI/CD akan menghasilkan berkas APK bernama `PicClaw-v1.1.0.apk` tetapi secara internal di dalam sistem operasi Android, aplikasi tersebut akan terdeteksi sebagai versi `1.0.0 (build 1)`. Hal ini menyebabkan inkonsistensi pelacakan crash dan kegagalan proses update mandiri di perangkat.

---

## 2. Panduan Eksekusi Kontrol Versi (Git CLI)

Berikut adalah urutan instruksi perintah Command Line Interface (CLI) Git yang harus dijalankan untuk merilis versi baru dan memicu alur kerja otomatisasi CI/CD pada server GitHub:

### Langkah 1: Pastikan Status Kerja Bersih dan Sinkron
Pastikan Anda berada di cabang rilis utama (misalnya `main`) dan seluruh perubahan kode telah disimpan dengan benar:

```bash
git checkout main
git pull origin main
```

### Langkah 2: Edit dan Commit Pembaruan Versi
Buka berkas `pubspec.yaml`, ubah nomor versi (misalnya dari `1.0.0+1` menjadi `1.1.0+2`), kemudian simpan berkas tersebut. Eksekusi commit khusus untuk pembaruan versi:

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 1.1.0+2"
```

### Langkah 3: Dorong Commit ke Repositori Remote
Kirim commit pembaruan versi ke server GitHub sebelum menandai rilis:

```bash
git push origin main
```

### Langkah 4: Buat Tag Lokal Berbasis SemVer
Buat objek tag baru yang beranotasi (-a) dengan pesan penjelasan (-m) yang mewakili rilis Anda:

```bash
git tag -a v1.1.0 -m "Release versi 1.1.0 dengan penambahan fitur kurasi album"
```

### Langkah 5: Dorong Tag ke Server GitHub
Kirim tag yang baru dibuat ke repositori remote untuk memulai eksekusi alur kerja GitHub Actions:

```bash
git push origin v1.1.0
```

### Langkah 6: Monitoring Proses Build
Setelah tag didorong, buka tab 'Actions' pada halaman repositori GitHub Anda untuk memantau jalannya proses build otomatis. Setelah proses selesai, berkas APK rilis berlabel `PicClaw-v1.1.0.apk` akan secara otomatis tersedia di halaman GitHub Releases sebagai draf rilis yang siap diterbitkan.
