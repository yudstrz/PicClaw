# Analisis Arsitektur dan Kelayakan Proyek: PicClaw

Dokumen ini menyajikan analisis teknis mendalam mengenai arsitektur sistem, manajemen memori, dan kelayakan implementasi proyek PicClaw sebagai aplikasi pembersih galeri dengan pendekatan Local-First.

---

## 1. Analisis Arsitektur Data dan Privasi

### Model Local-First dan Tanpa Login
Aplikasi PicClaw menerapkan prinsip kedaulatan data secara penuh (data sovereignty) dengan meniadakan gerbang masuk autentikasi (login) dan lalu lintas data ke server luar. Seluruh data transaksi swipe, metadata gambar, dan struktur pengelompokan disimpan secara lokal di dalam basis data SQLite perangkat. 

Secara arsitektural, ini memberikan beberapa keuntungan:
- Ketiadaan API Endpoint Autentikasi: Mengurangi permukaan serangan (attack surface) secara drastis karena tidak ada transmisi kredensial atau token sesi melalui jaringan.
- Zero Personal Identifiable Information (PII): Aplikasi tidak mengumpulkan alamat surel, nomor telepon, alamat IP, atau data pengenal lainnya, sehingga risiko kebocoran data identitas pengguna adalah nol.

### Kepatuhan Regulasi (GDPR & UU PDP)
Dari sudut pandang regulasi perlindungan data, khususnya General Data Protection Regulation (GDPR) di Uni Eropa dan Undang-Undang Pelindungan Data Pribadi (UU PDP) di Indonesia:
- Peran Hukum: PicClaw tidak bertindak sebagai Pengendali Data (Data Controller) maupun Prosesor Data (Data Processor) pada infrastruktur cloud. Pengguna bertindak sebagai pengendali tunggal atas data mereka sendiri.
- Privacy by Design & Privacy by Default: Desain aplikasi secara otomatis mematuhi standar hukum tertinggi karena tidak ada transfer data lintas batas (cross-border data flow) dan tidak ada retensi data pihak ketiga.

### Sandboxing Sistem Operasi
Keamanan data lokal dijamin oleh mekanisme sandboxing yang diterapkan secara ketat oleh sistem operasi Android dan iOS:
- Android Sandboxing: Setiap aplikasi dijalankan dengan User ID (UID) Linux yang unik di dalam proses terisolasi. Basis data SQLite disimpan di direktori internal `/data/data/[package_name]/databases/` yang hanya dapat diakses oleh UID aplikasi bersangkutan. Keberadaan berkas enkripsi default dan kebijakan SELinux membatasi akses aplikasi lain terhadap berkas ini.
- iOS Sandboxing: Aplikasi diletakkan di dalam container direktori tersendiri di bawah `/var/mobile/Containers/Data/Application/[UUID]/`. iOS menggunakan perlindungan Data Protection API untuk mengenkripsi berkas di tingkat sistem berkas (file system) menggunakan kunci perangkat keras saat perangkat terkunci.

---

## 2. Manajemen Memori dan Tantangan Performa

### Risiko Out of Memory (OOM)
Pikselasi kamera ponsel modern menghasilkan berkas gambar beresolusi tinggi (misalnya 12 MP hingga 108 MP). Jika sebuah gambar beresolusi 4000 x 3000 piksel didekompresi secara penuh ke dalam RAM dalam format warna RGBA (4 byte per piksel), maka memori yang dibutuhkan adalah:

4000 * 3000 * 4 byte = 48.000.000 byte (~45.7 MB RAM)

Jika tumpukan kartu (swiper deck) memuat 10 gambar secara bersamaan tanpa optimasi, memori yang terkonsumsi hanya untuk alokasi bitmap gambar mentah mencapai hampir 500 MB. Hal ini akan memicu mekanisme Low Memory Killer (LMK) dari OS untuk menghentikan proses aplikasi (OOM Crash).

### Strategi Mitigasi Performa di Flutter
Untuk menjaga konsumsi RAM tetap di bawah batas aman (kurang dari 150 MB total heap), PicClaw mengimplementasikan tiga pilar manajemen memori:

1. Lazy Loading dan Paginasi
Akses ke sistem penyimpanan lokal melalui paket `photo_manager` dilakukan secara malas (lazy). Pemanggilan metode `getAssetListRange` hanya mengambil penunjuk metadata (Asset ID, koordinat pembuatan, tipe berkas) dari galeri sistem, bukan memuat byte gambar. Data ditarik dalam partisi kecil (batch 10 item).

2. Penggunaan Sub-sampling dan Konstraksi Resolusi
Alih-alih membaca berkas asli, subsistem data source memanggil API native untuk mengekstrak resolusi thumbnail menengah (500 x 500 piksel) dengan format kompresi JPEG kualitas 80%. Ukuran dekompresi bitmap di memori dibatasi menjadi:

500 * 500 * 4 byte = 1.000.000 byte (~0.95 MB RAM)

Dengan pembatasan ini, alokasi memori untuk 10 kartu aktif diturunkan secara signifikan dari ~450 MB menjadi kurang dari 10 MB. Penggunaan parameter `cacheWidth` dan `cacheHeight` pada widget `Image.memory` memastikan mesin render Skia/Impeller tidak mengalokasikan tekstur GPU melebihi resolusi visual widget.

3. Manajemen Siklus Hidup Cache Gambar (Eviction Policy)
Flutter secara default menyimpan gambar yang didekode di dalam `ImageCache` global. Untuk mencegah akumulasi berkas sampah yang sudah di-swipe, aplikasi mengeksekusi secara manual penghapusan referensi mati melalui `imageCache.clear()` dan `imageCache.clearLiveImages()` di dalam siklus pen notifier. Hal ini membebaskan heap Dart sehingga Garbage Collector (GC) dapat langsung mereklamasi ruang memori yang tidak lagi digunakan oleh widget yang telah di-dispose.

---

## 3. Analisis Risiko dan Mitigasi

Berikut adalah matriks identifikasi risiko sistem beserta solusi mitigasi teknisnya:

### Risiko A: Kehilangan Data Sesi Akibat Uninstall Aplikasi
- Deskripsi: Karena penyimpanan database SQLite bersifat sandboxed di dalam direktori internal aplikasi, proses penghapusan instalan (uninstall) aplikasi oleh pengguna akan secara otomatis menghapus seluruh isi direktori tersebut. Akibatnya, riwayat kurasi (kategori foto yang disimpan atau ditangguhkan untuk dihapus) akan hilang sepenuhnya.
- Dampak: Tinggi. Pengguna kehilangan riwayat penyortiran yang belum dieksekusi secara permanen ke galeri sistem.
- Mitigasi Teknis:
  - Menyediakan fitur Ekspor/Impor berkas database secara berkala ke penyimpanan eksternal yang diatur pengguna (menggunakan Storage Access Framework di Android atau FilePicker di iOS). Berkas cadangan (.json atau .db) disimpan di luar direktori sandbox.
  - Mempersingkat siklus hidup data tertangguh dengan memberikan pengingat terjadwal (local notification) agar pengguna segera melakukan eksekusi final penghapusan gambar dari sistem.

### Risiko B: Perubahan Hak Akses Galeri Secara Dinamis
- Deskripsi: Pengguna dapat mencabut izin akses galeri melalui pengaturan sistem operasi kapan saja saat aplikasi sedang berjalan di latar belakang (background).
- Dampak: Sedang. Menyebabkan kegagalan runtime saat aplikasi mencoba memanggil API `photo_manager`.
- Mitigasi Teknis:
  - Melakukan pemeriksaan validitas izin (`PhotoManager.getPermissionState()`) setiap kali siklus *lifecycle* aplikasi berpindah dari latar belakang ke latar depan (resume).
  - Mengimplementasikan penanganan kegagalan terpusat (Failure handling) pada tingkat data source yang secara otomatis mengarahkan antarmuka pengguna kembali ke halaman permintaan izin akses jika terdeteksi status izin ditolak.

### Risiko C: Galeri Sistem Tidak Sinkron dengan Indeks Database Lokal
- Deskripsi: Foto yang terindeks dalam database lokal dapat dihapus atau dipindahkan oleh pengguna melalui aplikasi galeri bawaan OS di luar aplikasi PicClaw.
- Dampak: Sedang. Menyebabkan pustaka mencoba menampilkan gambar kosong (broken image link).
- Mitigasi Teknis:
  - Sebelum menampilkan kartu di atas tumpukan, sistem melakukan verifikasi keberadaan berkas fisik secara asinkron menggunakan metode `asset.exists`. Jika berkas tidak lagi tersedia di sistem penyimpanan fisik, ID tersebut langsung dihapus dari antrean memori dan database lokal tanpa mengganggu aliran swiping pengguna.
