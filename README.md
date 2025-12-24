# Aplikasi Mobile Klasifikasi Produk Kran Air Onda Menggunakan MobileNetV3

Repository ini merupakan bagian dari skripsi berjudul:

**“Perancangan Sistem Klasifikasi Citra Produk Onda Menggunakan MobileNetV3”**

yang disusun sebagai syarat penyelesaian program Sarjana  
Program Studi Teknik Informatika  
Fakultas Teknologi Informasi  
Universitas Tarumanagara


## Deskripsi Singkat
Penelitian ini merancang sebuah sistem klasifikasi citra berbasis deep learning
untuk mengidentifikasi varian produk kran air Onda. Sistem menggunakan arsitektur
**Convolutional Neural Network (CNN)** ringan, yaitu **MobileNetV3 Large**, 
yang diintegrasikan ke dalam aplikasi mobile Android.

Aplikasi memungkinkan pengguna melakukan klasifikasi produk melalui kamera
atau galeri, serta menampilkan hasil prediksi **Top-3** untuk meningkatkan
keandalan identifikasi pada produk dengan kemiripan visual tinggi.


## Struktur Folder
Repository ini terdiri dari beberapa komponen utama sebagai berikut:

- **Dataset**  
  Dataset citra produk kran air Onda yang digunakan dalam proses pelatihan
  dan pengujian model.

- **Notebook Pipeline Model**  
  Notebook untuk preprocessing data, augmentasi citra, pelatihan model CNN,
  serta evaluasi performa model.

- **product_classifier**  
  Source code aplikasi mobile Android untuk klasifikasi citra produk.

- **Buku Panduan Aplikasi.pdf**  
  Dokumen panduan penggunaan aplikasi mobile.

- **omi-vision.apk**  
  File instalasi aplikasi Android hasil perancangan sistem.


## Metode yang Digunakan
- Convolutional Neural Network (CNN)
- Transfer Learning
- MobileNetV2
- MobileNetV3 Small dan MobileNetV3 Large
- Data Augmentation (Albumentations)
- Evaluasi menggunakan Accuracy dan Macro F1-Score

## Instalasi Aplikasi (APK)
Aplikasi **Omi Vision** didistribusikan dalam bentuk file APK sehingga dapat
dipasang secara langsung pada perangkat Android tanpa melalui Google Play Store.

**Langkah Instalasi:**
1. Salin file **omi-vision.apk** ke perangkat Android.
2. Buka file APK melalui File Manager.
3. Jika muncul peringatan keamanan, aktifkan opsi  
   **Izinkan instalasi dari sumber ini (Unknown Sources)**.
4. Lanjutkan proses instalasi hingga selesai.
5. Setelah instalasi berhasil, aplikasi dapat dijalankan melalui menu aplikasi.

**Catatan:**
- Aplikasi tidak memerlukan koneksi internet saat proses klasifikasi.
- Aplikasi memerlukan izin akses kamera dan penyimpanan.
- Proses instalasi dapat berbeda tergantung versi Android.


## Penulis
**Jason Permana**  
Program Studi Teknik Informatika  
Universitas Tarumanagara  
Tahun 2025
