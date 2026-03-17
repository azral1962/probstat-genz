#import "graceful-genetics-main/src/lib.typ" as graceful-genetics

#show: graceful-genetics.template.with(
  title: [Pemodelan Antrian: Sebuah Studi Kasus Pengubah Acak Diskrit],
  authors: (
    (
      name: "Armein Z. R. Langi",
      department: "Sekolah Teknik Elektro dan Informatika",
      institution: "Institut Teknologi Bandung",
      city: "Bandung",
      country: "Indonesia",
      mail: "armein@itb.ac.id",
    ),
    (
      name: "Melia Johan Christi",
      department: "Sekolah Teknik Elektro dan Informatika",
      institution: "Institut Teknologi Bandung",
      city: "Bandung",
      country: "Indonesia",
      mail: "stegonaris@space.it",
    ),
  ),
  date: (
    year: 2026,
    month: "Mar",
    day: 17,
  ),
  keywords: (
    "Antrian",
    "Binomial",
    "Poisson",
    "Eksponensial",
    "Python",
  ),
  doi: "10.7891/120948510",
  abstract: [
    Dokumen ini dibuat untuk mahasiswa II-2111 Probabilitas dan Statistika. Kita lihat **rantai distribusi probabilitas yang sangat penting dalam engineering**. Hampir semua model sistem teknik (network, server, reliability, queueing) lahir dari rantai ini. Simulasi **Poisson process** sebenarnya sangat sederhana dan sangat bagus untuk membantu mahasiswa memahami konsep **arrival acak** dalam sistem.

  ],
)

#include "06_antrian.typ"
#figure(
  image("a-mail.png"),
  caption: [
    Visualization of the FTL Earth-to-Mars communication capabilities enabled by A-Mail.
  ],
)
