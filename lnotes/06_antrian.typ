= Rantai Distribusi Probabilitas dalam Engineering
<rantai-distribusi-probabilitas-dalam-engineering>
```
Bernoulli → Binomial → Poisson → Exponential → Queueing Theory 
```

Kita bahas satu per satu secara intuitif.

= 1. Bernoulli --- kejadian dasar (sukses / gagal)
<bernoulli-kejadian-dasar-sukses-gagal>
P(X=1)=p,; P(X=0)=1-p

Bernoulli adalah #strong[atom dari probabilitas diskrit].

Contoh:

- bit diterima benar / salah

- packet berhasil / hilang

- komponen hidup / gagal

Ini adalah #strong[model kejadian tunggal].

Dalam engineering digital:

```
error bit = Bernoulli trial 
```

= 2. Binomial --- jumlah sukses dalam n percobaan
<binomial-jumlah-sukses-dalam-n-percobaan>
$ P \( X = k \) = binom(n, k) p^k \( 1 - p \)^(n - k) $

Jika kita melakukan #strong[banyak Bernoulli trial], kita mendapat
distribusi Binomial.

Contoh engineering:

- jumlah error dalam 1000 bit

- jumlah packet loss dalam 100 transmisi

- jumlah mahasiswa lulus ujian

Binomial menjawab:

```
berapa banyak kejadian sukses dalam n percobaan 
```

= 3. Poisson --- kejadian langka dalam waktu/ruang
<poisson-kejadian-langka-dalam-wakturuang>
$ P \( X = k \) = frac(lambda^k e^(- lambda), k !) $

Jika:

- percobaan sangat banyak

- probabilitas sukses sangat kecil

maka Binomial menjadi #strong[Poisson].

Parameter:

$ lambda = n p $

Contoh nyata engineering:

- jumlah request web per detik

- jumlah kendaraan lewat per menit

- jumlah error per MB data

Poisson menjawab:

```
berapa kejadian dalam interval waktu 
```

= 4. Exponential --- waktu antar kejadian
<exponential-waktu-antar-kejadian>
Jika kejadian mengikuti Poisson process, maka #strong[jarak waktu antar
kejadian] mengikuti distribusi #strong[Exponential].

$ f \( t \) = lambda e^(- lambda t) $

Contoh:

- waktu antar telepon masuk

- waktu antar packet arrival

- waktu antar kegagalan komponen

Ini sangat penting karena memiliki sifat:

```
memoryless 
```

Artinya:

masa depan #strong[tidak bergantung masa lalu].

= 5. Queueing Theory --- sistem pelayanan
<queueing-theory-sistem-pelayanan>
Jika:

- arrival mengikuti #strong[Poisson]

- service time mengikuti #strong[Exponential]

maka kita mendapatkan model antrian klasik:

```
M/M/1 queue 
```

dimana

#figure(
  align(center)[#table(
    columns: 2,
    align: (auto,auto,),
    table.header([simbol], [arti],),
    table.hline(),
    [M], [Markov (Poisson arrival)],
    [M], [exponential service],
    [1], [satu server],
  )]
  , kind: table
  )

Model ini dipakai untuk:

- server komputer

- call center

- jaringan internet

- sistem produksi

= 6. Diagram besar probabilitas sistem teknik
<diagram-besar-probabilitas-sistem-teknik>
Struktur besar:

```
kejadian dasar      ↓ Bernoulli trial      ↓ Binomial (jumlah sukses)      ↓ Poisson (kejadian per waktu)      ↓ Exponential (waktu antar kejadian)      ↓ Queueing systems 
```

Ini adalah #strong[salah satu rantai konsep paling penting dalam
engineering systems].

= 7. Intuisi besar (sangat penting)
<intuisi-besar-sangat-penting>
Ada dua cara melihat dunia:

=== dunia statistik
<dunia-statistik>
```
menghitung kejadian 
```

=== dunia sistem
<dunia-sistem>
```
kejadian → waktu antar kejadian → sistem antrian 
```

Karena itu dalam engineering:

```
probability → stochastic process → queueing 
```

= 8. Contoh nyata: server web
<contoh-nyata-server-web>
Misalnya:

- request datang #strong[Poisson]

- server melayani #strong[Exponential]

maka kita bisa menghitung:

- rata-rata antrian

- waktu tunggu user

- probabilitas server overload

Ini adalah dasar:

- cloud computing

- network engineering

- performance modeling

Jika Anda ingin, saya juga bisa jelaskan #strong[hubungan yang lebih
dalam lagi yang sangat elegan], yaitu:

```
Bernoulli → Geometric → Negative Binomial → Poisson → Exponential → Gamma 
```

Ini sebenarnya adalah #strong[keluarga distribusi yang berasal dari
proses yang sama].

Dan ini sangat indah secara matematis.
