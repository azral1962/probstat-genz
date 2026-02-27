import os
import re

# Data silabus berdasarkan kurikulum perkuliahan
silabus = [
    {
        "minggu": "01",
        "topik_id": "Pola Pikir Probabilistik vs Deterministik",
        "topik_en": "Understanding Probabilistic Way of Thinking versus Deterministic Way of Thinking",
        "konsep": "Memahami bahwa dalam dunia nyata, fenomena seringkali mengandung ketidakpastian (randomness) dan tidak dapat diprediksi dengan kepastian mutlak (deterministik), sehingga memerlukan kerangka kerja matematika untuk mengukur ketidakpastian tersebut.",
        "problem": "Sebuah toko ingin menentukan stok barang. Pendekatan deterministik mengasumsikan permintaan konstan (misal: pasti 100 unit), sedangkan realitanya permintaan berfluktuasi secara acak.",
        "solusi": "Menggunakan model probabilistik untuk menghitung peluang terjadinya berbagai tingkat permintaan, sehingga manajer dapat menentukan level safety stock yang optimal untuk meminimalkan risiko kekurangan stok tanpa menimbun barang berlebihan."
    },
    {
        "minggu": "02",
        "topik_id": "Kerangka Probabilitas dan Statistik",
        "topik_en": "Probabilistic Experiment, Sample Space, Event, Probability Definition and Axioms",
        "konsep": "Ruang sampel (S) sebagai himpunan semua hasil yang mungkin, kejadian (E) sebagai himpunan bagian dari ruang sampel, dan aksioma probabilitas (nilai peluang antara 0 dan 1, total peluang semesta = 1).",
        "problem": "Dalam pengiriman data digital, kita ingin mengetahui peluang terjadinya kesalahan bit. Jika dikirim 3 bit, apa ruang sampelnya dan berapa peluang setidaknya satu bit salah?",
        "solusi": "Mendaftar ruang sampel S = {000, 001, ..., 111}. Jika kejadian E adalah 'setidaknya satu error', kita hitung jumlah elemen di E dibagi total elemen di S untuk mendapatkan probabilitasnya, yang digunakan untuk menentukan kualitas saluran komunikasi."
    },
    {
        "minggu": "03",
        "topik_id": "Studi Kasus Aplikasi Teknik",
        "topik_en": "Probabilistic Framework in Engineering Application (Data Center, Generator Backup, Reliability)",
        "konsep": "Keandalan sistem (reliability), sistem seri vs paralel. Dalam sistem paralel, sistem bekerja jika setidaknya satu komponen bekerja, sedangkan seri membutuhkan semua komponen bekerja.",
        "problem": "Sebuah pusat data memiliki dua generator listrik. Apakah lebih baik menyusunnya secara seri atau paralel untuk menjamin ketersediaan daya?",
        "solusi": "Menghitung probabilitas kegagalan sistem. Pada desain paralel, peluang kegagalan total adalah hasil kali peluang kegagalan masing-masing unit (yang jauh lebih kecil). Keputusan optimalnya adalah menggunakan konfigurasi paralel untuk meningkatkan reliabilitas sistem secara drastis."
    },
    {
        "minggu": "04",
        "topik_id": "Teorema Probabilitas dan Bayes",
        "topik_en": "Probability Theorems, Conditional Probability, Bayes Theorem",
        "konsep": "Probabilitas bersyarat P(A|B), aturan perkalian, independensi, dan Teorema Bayes untuk memperbarui keyakinan berdasarkan bukti baru.",
        "problem": "Sebuah sistem pemantauan mendeteksi kerusakan mesin (alarm berbunyi). Diketahui akurasi alarm 90%, tetapi peluang mesin rusak sebenarnya sangat kecil (jarang terjadi). Apakah mesin benar-benar rusak jika alarm berbunyi?",
        "solusi": "Menggunakan Teorema Bayes untuk menghitung Posterior Probability P(Rusak|Alarm). Seringkali hasilnya menunjukkan peluang kerusakan masih rendah (false alarm). Solusinya adalah melakukan verifikasi manual sebelum menghentikan produksi yang mahal."
    },
    {
        "minggu": "05",
        "topik_id": "Variabel Acak",
        "topik_en": "Random Variable Definition, Probability Function, Expectation, Variance",
        "konsep": "Pemetaan hasil eksperimen ke nilai numerik (variabel acak), Nilai Harapan (E[X]) sebagai rata-rata jangka panjang, dan Variansi sebagai ukuran sebaran.",
        "problem": "Seorang investor memiliki dua opsi investasi dengan profil risiko berbeda. Opsi A memberikan hasil pasti, Opsi B memberikan hasil tinggi tapi berisiko rugi.",
        "solusi": "Menghitung E[X] (expected return) dan Variansi (risiko) dari kedua opsi. Keputusan diambil dengan memilih E[X] tertinggi yang masih berada dalam toleransi risiko (variansi) investor tersebut."
    },
    {
        "minggu": "06",
        "topik_id": "Variabel Acak Diskrit",
        "topik_en": "Binomial Distribution, Poisson Distribution",
        "konsep": "Distribusi Binomial untuk jumlah sukses dalam n percobaan, Distribusi Poisson untuk jumlah kejadian dalam interval waktu/ruang tertentu.",
        "problem": "Sebuah pabrik ingin menjamin kualitas produk. Diketahui rata-rata cacat adalah 1%. Berapa peluang menemukan tepat 2 barang cacat dalam sampel 100 unit?",
        "solusi": "Menggunakan rumus distribusi Binomial (atau aproksimasi Poisson jika n besar dan p kecil). Jika peluang cacat melebihi ambang batas toleransi, manajer memutuskan untuk menghentikan lini produksi untuk inspeksi."
    },
    {
        "minggu": "07",
        "topik_id": "Variabel Acak Kontinu",
        "topik_en": "Normal Distribution, Exponential Distribution",
        "konsep": "Distribusi Normal (kurva lonceng) untuk data pengukuran alami, Distribusi Eksponensial untuk waktu tunggu antar kejadian.",
        "problem": "Menentukan garansi produk lampu. Diketahui masa hidup lampu berdistribusi Normal dengan rata-rata 900 jam dan standar deviasi 50 jam.",
        "solusi": "Menghitung peluang lampu mati sebelum waktu tertentu (misal P(X < 700)). Perusahaan menetapkan masa garansi di titik di mana hanya sebagian kecil (misal 1%) lampu yang akan rusak, untuk meminimalkan biaya penggantian klaim garansi."
    },
    {
        "minggu": "08",
        "topik_id": "Ujian Tengah Semester",
        "topik_en": "Midterm Exam",
        "konsep": "Evaluasi materi minggu 1-7.",
        "problem": "Ujian tertulis dan komputasi.",
        "solusi": "Mengerjakan soal evaluasi dengan pendekatan probabilitas dan statistik."
    },
    {
        "minggu": "09",
        "topik_id": "Fungsi Variabel Acak",
        "topik_en": "Function of Random Variables, PDF of new random variable",
        "konsep": "Menentukan distribusi probabilitas dari variabel baru Y yang merupakan fungsi dari variabel acak X (misal Y = g(X)).",
        "problem": "Diketahui distribusi kesalahan pengukuran arus listrik (X). Bagaimana distribusi kesalahan daya listrik (P), jika P = I^2 * R?",
        "solusi": "Menggunakan metode transformasi atau fungsi pembangkit momen untuk menurunkan PDF dari P. Ini penting bagi insinyur untuk menentukan batas toleransi keamanan komponen agar tidak terbakar akibat fluktuasi daya."
    },
    {
        "minggu": "10",
        "topik_id": "Distribusi Sampling dan Teorema Limit Pusat",
        "topik_en": "Sampling Distribution, Central Limit Theorem (CLT)",
        "konsep": "Distribusi dari rata-rata sampel akan mendekati Normal jika ukuran sampel besar (n >= 30), terlepas dari distribusi populasinya.",
        "problem": "Sebuah lift memiliki kapasitas beban maksimum. Jika berat badan rata-rata penumpang adalah variabel acak, berapa peluang 20 orang penumpang melebihi kapasitas lift?",
        "solusi": "Menggunakan CLT untuk memodelkan total berat penumpang sebagai distribusi Normal. Insinyur menggunakan ini untuk menetapkan batas aman jumlah penumpang agar peluang kelebihan beban mendekati nol."
    },
    {
        "minggu": "11",
        "topik_id": "Estimasi",
        "topik_en": "Estimation, Confidence Interval",
        "konsep": "Estimasi titik (point estimate) dan Estimasi Interval (Confidence Interval) untuk memperkirakan parameter populasi (rata-rata atau proporsi).",
        "problem": "Berdasarkan survei sampel terhadap 100 chip komputer, ditemukan rata-rata kecepatan pemrosesan tertentu. Berapa rata-rata kecepatan sebenarnya dari seluruh produksi pabrik?",
        "solusi": "Membangun Confidence Interval (misal 95% CI). Pabrik dapat mengklaim spesifikasi produk dengan keyakinan statistik yang dapat dipertanggungjawabkan kepada konsumen."
    },
    {
        "minggu": "12",
        "topik_id": "Pengujian Hipotesis",
        "topik_en": "Hypothesis Testing Procedure, Error Types",
        "konsep": "Menentukan H0 dan H1, menghitung statistik uji, P-value, serta memahami Galat Tipe I (False Positive) dan Tipe II (False Negative).",
        "problem": "Sebuah obat baru diklaim lebih efektif menyembuhkan penyakit dibandingkan obat lama. Apakah klaim ini valid atau hanya kebetulan?",
        "solusi": "Melakukan uji hipotesis (misal t-test). Jika P-value < alpha (0.05), tolak H0. Keputusannya adalah memproduksi obat baru tersebut karena terbukti secara signifikan lebih baik secara statistik."
    },
    {
        "minggu": "13",
        "topik_id": "Regresi",
        "topik_en": "Regression Line, Coefficient of Correlation",
        "konsep": "Memodelkan hubungan linear antara variabel independen (x) dan dependen (y) dengan metode kuadrat terkecil (y = b0 + b1x).",
        "problem": "Memprediksi konsumsi daya listrik berdasarkan suhu lingkungan.",
        "solusi": "Mengumpulkan data historis, membuat model regresi linear. Model ini digunakan operator pembangkit listrik untuk merencanakan berapa banyak bahan bakar yang harus disiapkan besok berdasarkan ramalan cuaca (suhu)."
    },
    {
        "minggu": "14-15",
        "topik_id": "Studi Kasus Lanjutan",
        "topik_en": "Advanced Case Studies (Application in Computing/Electrical Engineering)",
        "konsep": "Penerapan integratif dari estimasi, uji hipotesis, dan regresi pada masalah dunia nyata yang kompleks, seperti Robust Parameter Design atau deteksi sinyal.",
        "problem": "Mengoptimalkan parameter proses manufaktur agar tahan terhadap variasi lingkungan (noise) atau mendeteksi sinyal radar di tengah noise.",
        "solusi": "Menggunakan desain eksperimen (DOE) dan analisis statistik untuk memilih parameter 'kontrol' yang meminimalkan variansi output (membuat produk robust/tangguh), sehingga menekan biaya cacat produksi."
    },
    {
        "minggu": "16",
        "topik_id": "Ujian Akhir Semester",
        "topik_en": "Final Exam",
        "konsep": "Evaluasi menyeluruh materi satu semester.",
        "problem": "Ujian komprehensif studi kasus.",
        "solusi": "Menerapkan seluruh konsep probabilitas dan statistik untuk menyelesaikan masalah rekayasa."
    }
]

# Template untuk file Quarto (.qmd)
qmd_template = """---
title: "Minggu {minggu}: {topik_id}"
subtitle: "{topik_en}"
format:
  html:
    theme: cosmo
    toc: true
jupyter: python3
---

## 1. Konsep Pengetahuan
{konsep}

## 2. Tipikal Problem
{problem}

## 3. Solusi & Pengambilan Keputusan
{solusi}

## 4. Eksplorasi Komputasi (Python)
*Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.*

```{{python}}
# Tulis kode Python Anda di sini
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats

print("Siap untuk komputasi Minggu {minggu}!")
```
"""

# Membuat direktori jika belum ada
output_dir = "materi_kuliah_qmd"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Membuat file untuk setiap minggu
for item in silabus:
    # Membersihkan nama file dari karakter khusus dan mengganti spasi dengan underscore
    safe_title = re.sub(r'[^a-zA-Z0-9]', '_', item["topik_id"])
    safe_title = re.sub(r'_+', '_', safe_title).strip('_')
    
    filename = f"{item['minggu']}-{safe_title}.qmd"
    filepath = os.path.join(output_dir, filename)
    
    # Mengisi template dengan data
    content = qmd_template.format(
        minggu=item["minggu"],
        topik_id=item["topik_id"],
        topik_en=item["topik_en"],
        konsep=item["konsep"],
        problem=item["problem"],
        solusi=item["solusi"]
    )
    
    # Menulis ke file
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f"Berhasil membuat: {filename}")

print(f"\\nSemua file telah berhasil dibuat di dalam folder '{output_dir}'.")
