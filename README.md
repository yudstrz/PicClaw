# PicClaw

PicClaw adalah aplikasi utilitas pembersih galeri foto berbasis Flutter yang mengimplementasikan interaksi berbasis gesture geser (swipe) untuk membantu pengguna menyortir tumpukan media secara cepat. Beroperasi secara penuh dengan arsitektur Local-First, aplikasi ini menjamin privasi absolut karena seluruh pemrosesan media dan penyimpanan metadata berlangsung secara luring (offline) 100% di dalam lingkungan memori terisolasi (sandbox) perangkat pengguna tanpa melibatkan server eksternal.

---

## 1. Fitur Utama dan Korelasi Prinsip UI/UX

Desain antarmuka dan pengalaman pengguna PicClaw didasarkan pada 12 Prinsip UI/UX (Laws of UX & Usability Heuristics) berikut:

- Kurasi Berbasis Gesture (Jakob's Law): Menggunakan standar gestur usap yang familier di industri; usap ke kiri untuk memindahkan berkas ke daftar hapus, dan usap ke kanan untuk mempertahankan berkas di galeri.
- Umpan Balik Visual Instan (Immediate Visual Feedback): Saat kartu media digeser, sistem akan menampilkan indikator overlay transparan secara real-time bertuliskan "TRASH" berwarna merah di sisi kiri atau "KEEP" berwarna hijau di sisi kanan berdasarkan koordinat pergeseran piksel.
- Tombol Pembatalan Instan (User Control and Freedom): Menyediakan tombol "Undo" yang mudah dijangkau untuk memulihkan foto yang baru saja diusap kembali ke tumpukan atas secara instan.
- Indikator Status Kemajuan (Visibility of System Status): Menampilkan bilah kemajuan linier (progress bar) beserta hitungan indeks kartu yang sedang aktif (misalnya, "Foto 15 dari 100") agar posisi navigasi pengguna selalu terlihat jelas.
- Pencegahan Kesalahan Penghapusan (Error Prevention): Menggunakan sistem tempat sampah (Trash Bin) lokal. Foto yang diusap ke kiri tidak langsung dihapus dari perangkat keras melainkan ditangguhkan di dalam database lokal. Penghapusan permanen hanya terjadi setelah pengguna meninjau ulang dan menyetujui konfirmasi penghapusan massal melalui API bawaan sistem operasi.
- Pengenalan Visual Dominan (Recognition Rather than Recall): Memposisikan kartu media agar menempati 80% area layar guna memprioritaskan pengenalan visual objek foto tanpa menuntut pengguna mengingat konten detailnya.
- Penempatan Aksi Ergonomis (Fitts's Law): Meletakkan seluruh tombol kontrol fisik utama (Undo, Simpan, Hapus) pada area sepertiga bawah layar (thumb zone) agar mudah dijangkau menggunakan ibu jari saat pengoperasian satu tangan.
- Pembatasan Pilihan (Hick's Law): Membatasi jumlah opsi keputusan interaksi pada satu waktu untuk menghindari kelelahan kognitif pengguna dalam memilih tindakan.
- Fleksibilitas Kendali (Flexibility and Efficiency of Use): Menyediakan navigasi ganda; pengguna berpengalaman dapat mengusap kartu dengan cepat secara gestural, sedangkan pengguna baru dapat mengetuk tombol aksi fisik di bagian bawah.
- Desain Estetis dan Minimalis (Aesthetic and Minimalist Design): Menerapkan latar belakang gelap pekat tanpa dekorasi visual yang tidak penting untuk menonjolkan konten utama dan mengurangi ketegangan mata.
- Keselarasan Sistem dengan Dunia Nyata (Match between System & Real World): Menggunakan ikon representatif seperti keranjang sampah untuk penghapusan dan tangan pencapit (claw) untuk penyelamatan media.
- Efek Estetika Usabilitas (Aesthetic-Usability Effect): Menyusun pergerakan tumpukan kartu dengan interpolasi animasi yang halus (target 60 FPS) guna membangun impresi aplikasi yang andal dan tepercaya.

---

## 2. Arsitektur dan Teknologi Pendukung

Aplikasi PicClaw dikembangkan dengan pola arsitektur Clean Architecture yang terbagi menjadi tiga lapisan utama:

- Presentation Layer: Menggunakan kerangka kerja Flutter dengan State Management Riverpod untuk memantau perubahan status antrean kartu secara reaktif dan efisien.
- Domain Layer: Berisi entitas bisnis murni (MediaItem, Album) dan Use Cases terisolasi yang mendefinisikan aturan bisnis penyortiran gambar tanpa bergantung pada pustaka eksternal.
- Data Layer: Mengintegrasikan pustaka native `photo_manager` untuk melakukan pemindaian galeri sistem secara langsung serta SQLite (`sqflite`) untuk menyimpan riwayat status kurasi media secara permanen di tingkat lokal.

### Teknologi Utama
- Core Framework: Flutter (Dart SDK >= 3.0.0 < 4.0.0)
- State Management: Flutter Riverpod (^2.5.0)
- Native Media Access: Photo Manager (^3.0.0)
- Database Mesin: SQLite via Sqflite (^2.3.0)
- Sistem Pathing: Path Provider (^2.1.1) & Path (^1.9.0)

---

## 3. Struktur Direktori Proyek

Struktur folder mengadopsi pola Clean Architecture berbasis fitur (feature-first) untuk kemudahan perluasan kode di masa mendatang:

```
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart         # Inisialisasi SQLite & pembuatan tabel
│   │   └── database_helper.dart      # Utilitas query database
│   ├── error/
│   │   ├── exceptions.dart           # Kelas pengecualian runtime
│   │   └── failures.dart             # Model kegagalan untuk layer domain
│   ├── theme/
│   │   ├── app_colors.dart           # Konstanta palet warna gelap
│   │   └── app_theme.dart            # Konfigurasi ThemeData aplikasi
│   └── usecase/
│       └── usecase.dart              # Base class untuk semua Use Cases
├── features/
│   ├── gallery_cleaner/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── media_local_datasource.dart  # Integrasi photo_manager
│   │   │   │   └── session_db_datasource.dart   # Operasi baca-tulis SQLite
│   │   │   ├── models/
│   │   │   │   ├── album_model.dart             # Model data album foto
│   │   │   │   └── media_item_model.dart        # Model data berkas media
│   │   │   └── repositories/
│   │   │       └── gallery_repository_impl.dart # Implementasi repositori data
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── album.dart                   # Entitas bisnis album
│   │   │   │   └── media_item.dart              # Entitas bisnis media
│   │   │   ├── repositories/
│   │   │       └── gallery_repository.dart      # Kontrak interface repositori
│   │   │   └── usecases/
│   │   │       ├── delete_pending_media.dart
│   │   │       ├── get_media_batch.dart
│   │   │       └── swipe_media_item.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── gallery_swiper_notifier.dart # Pengendali logika Riverpod
│   │       │   └── gallery_swiper_state.dart    # Model state untuk antarmuka
│   │       ├── widgets/
│   │       │   ├── control_buttons.dart
│   │       │   ├── media_thumbnail.dart         # Widget thumbnail dengan cache terbatas
│   │       │   └── swiper_card.dart             # Desain kartu visual media
│   │       └── pages/
│   │           └── gallery_swiper_page.dart     # Layar utama MainSwipeScreen
└── main.dart                                    # Titik masuk eksekusi aplikasi
```

---

## 4. Skema Database Lokal

Aplikasi menggunakan SQLite untuk mencatat keputusan kurasi pengguna secara luring. Terdapat dua tabel utama yang saling berelasi:

### Tabel: `albums`
Menyimpan data referensi folder atau album media yang terdeteksi di perangkat.

| Nama Kolom | Tipe Data | Atribut | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | ID unik album dari sistem operasi |
| `name` | TEXT | NOT NULL | Nama tampilan album |
| `path` | TEXT | | Jalur penyimpanan fisik direktori |

### Tabel: `media_items`
Menyimpan riwayat keputusan usap berkas foto atau video untuk mencegah pemrosesan ulang berkas yang sama.

| Nama Kolom | Tipe Data | Atribut | Keterangan |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | ID unik gambar/video dari photo_manager |
| `album_id` | TEXT | FOREIGN KEY | Merujuk ke `albums(id)` dengan aksi ON DELETE SET NULL |
| `status` | TEXT | DEFAULT 'UNPROCESSED' | Nilai status: 'UNPROCESSED', 'KEPT', 'PENDING_DELETION' |
| `file_size` | INTEGER | NOT NULL | Ukuran berkas dalam satuan byte |
| `media_type` | INTEGER | NOT NULL | Tipe media (1 untuk gambar, 2 untuk video) |
| `created_at` | INTEGER | NOT NULL | Waktu pembuatan berkas (format epoch millisecond) |

*Catatan Kinerja*: Indeks basis data dibuat pada kolom `status` (`idx_media_status`) dan `album_id` (`idx_media_album`) untuk memastikan kecepatan pencarian data tetap konstan saat memproses puluhan ribu baris riwayat foto.

---

## 5. Panduan Instalasi dan Menjalankan Proyek

### Prasyarat Sistem
- Flutter SDK (Versi stabil terbaru, minimal versi 3.0.0)
- Android Studio / Xcode untuk kompilasi platform target
- Akses perangkat Android/iOS fisik atau emulator dengan dukungan galeri foto

### Langkah Awal
Pastikan Anda berada di direktori proyek, lalu lakukan inisialisasi modul platform native dengan mengeksekusi perintah berikut:

```bash
flutter create .
```

### Konfigurasi Izin Platform Native

#### Android Configuration
Buka berkas `android/app/src/main/AndroidManifest.xml` dan tambahkan deklarasi izin berikut di dalam blok `<manifest>` utama:

```xml
<!-- Izin untuk Android 13 (API 33) ke atas -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

<!-- Izin kompatibilitas untuk Android 12 (API 32) ke bawah -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
```

#### iOS Configuration
Buka berkas `ios/Runner/Info.plist` dan masukkan konfigurasi kunci berikut di dalam blok `<dict>` utama:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>PicClaw membutuhkan akses galeri untuk membaca, menampilkan, dan mengurutkan media Anda.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>PicClaw membutuhkan izin modifikasi galeri untuk melakukan penghapusan foto pilihan Anda.</string>
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

### Menjalankan Aplikasi (Development Mode)
Untuk mengunduh dependensi pustaka dan menjalankan aplikasi pada simulator atau perangkat fisik yang terhubung:

```bash
flutter pub get
flutter run
```

### Kompilasi Paket Rilis (Release Build)
Untuk membangun berkas instalasi mandiri (APK) Android dengan optimasi performa rilis:

```bash
flutter build apk --release
```
Berkas keluaran APK akan terletak di direktori:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 6. Dokumentasi Tambahan

Untuk analisis arsitektur dan panduan konfigurasi yang lebih terperinci, silakan merujuk pada berkas dokumentasi berikut:

- Analisis Kelayakan dan Arsitektur Data: [architecture_feasibility_analysis.md](file:///c:/Users/Wahyudi/Documents/GitHub/PicClaw/docs/architecture_feasibility_analysis.md)
- Panduan CI/CD dan Sinkronisasi Versi SemVer: [cicd_versioning_guide.md](file:///c:/Users/Wahyudi/Documents/GitHub/PicClaw/docs/cicd_versioning_guide.md)

