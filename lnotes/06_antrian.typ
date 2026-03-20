// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(
    top,
    float: true,
    scope: "parent",
    clearance: 4mm,
    block(below: 1em, width: 100%)[

      #if title != none {
        align(center, block(inset: 2em)[
          #set par(leading: heading-line-height) if heading-line-height != none
          #set text(font: heading-family) if heading-family != none
          #set text(weight: heading-weight)
          #set text(style: heading-style) if heading-style != "normal"
          #set text(fill: heading-color) if heading-color != black

          #text(size: title-size)[#title #if thanks != none {
            footnote(thanks, numbering: "*")
            counter(footnote).update(n => n - 1)
          }]
          #(if subtitle != none {
            parbreak()
            text(size: subtitle-size)[#subtitle]
          })
        ])
      }

      #if authors != none and authors != () {
        let count = authors.len()
        let ncols = calc.min(count, 3)
        grid(
          columns: (1fr,) * ncols,
          row-gutter: 1.5em,
          ..authors.map(author =>
              align(center)[
                #author.name \
                #author.affiliation \
                #author.email
              ]
          )
        )
      }

      #if date != none {
        align(center)[#block(inset: 1em)[
          #date
        ]]
      }

      #if abstract != none {
        block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
        ]
      }
    ]
  )

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Pemodelan Antrian: Sebuah Studi Kasus Pengubah Acak Diskrit],
  subtitle: [Catatan Kuliah Probabilitas dan Statistika],
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)
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
      name: "Meliana Christianti Johan",
      department: "Sekolah Teknik Elektro dan Informatika",
      institution: "Institut Teknologi Bandung",
      city: "Bandung",
      country: "Indonesia",
      mail: "meliana.christianti@it.maranatha.edu",
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
    Dokumen ini dibuat untuk mahasiswa II-2111 Probabilitas dan Statistika. Kita lihat rantai distribusi probabilitas yang sangat penting dalam engineering. Hampir semua model sistem teknik (network, server, reliability, queueing) lahir dari rantai ini. Simulasi Poisson process sebenarnya sangat sederhana dan sangat bagus untuk membantu mahasiswa memahami konsep arrival acak dalam sistem.

  ],
)

Simulasi dulu baru teori. Seperti biasa kita mulai dengan impor python library yang diperlukan

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
= Perhitungan Secara Manual
<perhitungan-secara-manual>
Katakanlah dalam suatu interval 60 menit rata rata 5 kendaraan per 10 menit pelanggan tiba di loket pelayanan, meskipun tidak bersamaan.

#block[
#Skylighting(([#CommentTok("## parameter");],
[#NormalTok("lambda_rate ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");#OperatorTok("/");#DecValTok("10");#NormalTok("   ");#CommentTok("## rata-rata 5 request per 10 m4nit");],
[#NormalTok("T ");#OperatorTok("=");#NormalTok(" ");#DecValTok("60");#NormalTok("            ");#CommentTok("## total waktu simulasi (menit)");],));
]
Misalnya waktu pelanngan dengan no urut idx tiba di loket pelayanan adalah waktu\_tiba\[idx\]. Durasi antar kedatangan pelanggan \[idx\] dengan idx-1 adalah selang\_tiba\[idx\] dimana

waktu\_tiba\[idx\] - waktu\_tiba\[idx-1\] = selang\_tiba\[idx\]

#block[
#Skylighting(([#NormalTok("waktu_tiba ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("t ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[],
[#ControlFlowTok("while");#NormalTok(" t ");#OperatorTok("<");#NormalTok(" T:");],
[#NormalTok("    ");#CommentTok("## generate waktu antar kedatangan");],
[#NormalTok("    selang_tiba ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("1");#OperatorTok("/");#NormalTok("lambda_rate)");],
[#NormalTok("    t ");#OperatorTok("+=");#NormalTok(" selang_tiba");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" t ");#OperatorTok("<");#NormalTok(" T:");],
[#NormalTok("        waktu_tiba.append(t)");],));
]
Asumsi daralm sebuah interval waktu (mislany 1 hari, atau 8 Jam, atau 1 jam)kedatangan terjadi secara acak

Contoh output:

#block[
#Skylighting(([#NormalTok("tiba_total");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(waktu_tiba)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Arrival times:\"");#NormalTok(", waktu_tiba)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Total arrivals:\"");#NormalTok(", tiba_total)");],));
#block[
#Skylighting(([#NormalTok("Arrival times: [1.9385108320726023, 3.2000994089880783, 9.419685769673078, 12.49538745671005, 12.676694663362545, 14.982158748199897, 19.06415741966172, 20.063163161756272, 20.065154520374243, 24.749522432721157, 35.363900121657565, 39.771512314379706, 41.93152287771641, 43.05975847653915, 44.588057752177306, 45.39501430622771, 45.747532175489546, 49.934361679710356, 50.25344521940932, 52.74696550410564, 53.030029561009165, 57.89642786114467, 57.95783375321613, 58.067594692478124, 58.60098228839955, 59.197631166161415]");],
[#NormalTok("Total arrivals: 26");],));
]
]
Artinya: selama 60 detik terjadi 26 \*\* request\*\*.

== 2. Visualisasi Arrival
<visualisasi-arrival>
Kemudian kita melihatnya secara visual

#Skylighting(([#NormalTok("plt.eventplot(waktu_tiba)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Time\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Poisson Arrival Process\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#figure([
#box(image("06_antrian_files/figure-typst/fig-plotevent-output-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Grafik ini menunjukkan kedatangan request secara acak sepanjang waktu.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-plotevent>


Kita langsung memahami bahwa:

#block(
fill:luma(230),
inset:8pt,
radius:4pt,
[
arrival tidak teratur, tetapi rata-ratanya stabil

])

= Simulasi Model Antrian
<simulasi-model-antrian>
Simulasi #strong[Poisson process] sebenarnya sangat sederhana dan sangat bagus untuk membantu mahasiswa memahami konsep #strong[arrival acak] dalam sistem.

Kita akan mensimulasikan dua hal:

+ #strong[jumlah kejadian dalam waktu tertentu] (Poisson)
+ #strong[waktu antar kejadian] (Exponential)

Ini langsung menunjukkan hubungan teori yang kita bahas sebelumnya.

Seperti biasa kita mulai dengan impor python library yang diperlukan

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
== 1. Simulasi Poisson Process dengan Python
<simulasi-poisson-process-dengan-python>
Ide dasar:

- waktu antar kedatangan mengikuti #strong[Exponential]
- kita terus menambahkan waktu sampai melewati batas waktu total

Contoh: simulasi #strong[request server selama 10 detik].

Kita mulai dengan parameter dari random generator.

#block[
#Skylighting(([#CommentTok("## parameter");],
[#NormalTok("lambda_rate ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok("   ");#CommentTok("## rata-rata 2 request per detik");],
[#NormalTok("T ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");#NormalTok("            ");#CommentTok("## total waktu simulasi (detik)");],));
]
#block[
#Skylighting(([#NormalTok("arrival_times ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("t ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[],
[#ControlFlowTok("while");#NormalTok(" t ");#OperatorTok("<");#NormalTok(" T:");],
[#NormalTok("    ");#CommentTok("## generate waktu antar kedatangan");],
[#NormalTok("    interarrival ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("1");#OperatorTok("/");#NormalTok("lambda_rate)");],
[#NormalTok("    t ");#OperatorTok("+=");#NormalTok(" interarrival");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" t ");#OperatorTok("<");#NormalTok(" T:");],
[#NormalTok("        arrival_times.append(t)");],));
]
Contoh output:

#block[
#Skylighting(([#NormalTok("request");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(arrival_times)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Arrival times:\"");#NormalTok(", arrival_times)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Total arrivals:\"");#NormalTok(", request)");],));
#block[
#Skylighting(([#NormalTok("Arrival times: [0.24947022065891236, 0.705758691002432, 0.8157438412088059, 1.3920899732554146, 1.931987065974343, 2.7330129627650344, 3.0295950234436724, 3.138441961911517, 3.5984261542878575, 3.8220475049578475, 3.9798398255049254, 4.065220622468721, 4.161779684551403, 4.326349825267032, 4.4491237099303635, 6.196320929076668, 6.37392445573316, 6.600172693339279, 6.92238303687704, 7.3949852671, 8.530629222540139]");],
[#NormalTok("Total arrivals: 21");],));
]
]
Artinya: selama 10 detik terjadi 21 \*\* request\*\*.

== 2. Visualisasi Arrival
<visualisasi-arrival-1>
Kemudian kita melihatnya secara visual

#Skylighting(([#NormalTok("plt.eventplot(arrival_times)");],
[#NormalTok("plt.xlabel(");#StringTok("\"Time\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Poisson Arrival Process\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#figure([
#box(image("06_antrian_files/figure-typst/fig-plot-event-output-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Grafik ini menunjukkan kedatangan request secara acak sepanjang waktu.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-plot-event>


Kita langsung memahami bahwa:

#block(
fill:luma(230),
inset:8pt,
radius:4pt,
[
arrival tidak teratur, tetapi rata-ratanya stabil

])

== 3. Simulasi Distribusi Poisson
<simulasi-distribusi-poisson>
Sekarang kita simulasi #strong[jumlah kejadian dalam interval waktu tetap].

#Skylighting(([#NormalTok("lambda_rate ");#OperatorTok("=");#NormalTok(" ");#DecValTok("4");#NormalTok("   ");#CommentTok("## rata-rata 4 kejadian");],
[#NormalTok("samples ");#OperatorTok("=");#NormalTok(" np.random.poisson(lambda_rate, ");#DecValTok("10000");#NormalTok(")");],
[],
[#NormalTok("plt.hist(samples, bins");#OperatorTok("=");#DecValTok("15");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Number of events\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Poisson Distribution Simulation\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("06_antrian_files/figure-typst/cell-12-output-1.svg"))

Ini akan menghasilkan histogram yang mengikuti distribusi #strong[Poisson].

== 4. Simulasi Waiting Time (Exponential)
<simulasi-waiting-time-exponential>
Kita lihat distribusi waktu antar kedatangan.

#Skylighting(([#NormalTok("interarrival ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("1");#OperatorTok("/");#NormalTok("lambda_rate, ");#DecValTok("10000");#NormalTok(")");],
[],
[#NormalTok("plt.hist(interarrival, bins");#OperatorTok("=");#DecValTok("50");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Waiting time\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Exponential Distribution\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("06_antrian_files/figure-typst/cell-13-output-1.svg"))

Mahasiswa akan melihat bahwa:

- banyak waktu tunggu #strong[pendek]
- beberapa #strong[panjang]

Ini ciri khas #strong[exponential distribution].

== 5. Demonstrasi yang sangat kuat di kelas
<demonstrasi-yang-sangat-kuat-di-kelas>
Anda bisa melakukan eksperimen sederhana:

Misalnya untuk #strong[web server]:

#block[
#Skylighting(([#NormalTok("lambda_rate ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");#NormalTok("   ");#CommentTok("## 5 request per detik");],
[#NormalTok("T ");#OperatorTok("=");#NormalTok(" ");#DecValTok("60");#NormalTok("            ");#CommentTok("## simulasi 1 menit");],));
]
Lalu mahasiswa menghitung:

- total request
- waktu antar request
- distribusi arrival

Ini langsung menghubungkan teori:

#Skylighting(([#NormalTok("Bernoulli → Binomial → Poisson → Exponential");],));
ke #strong[sistem nyata].

== 6. Simulasi M/M/1 Queue (bonus kecil)
<simulasi-mm1-queue-bonus-kecil>
Contoh sangat sederhana:

#block[
#Skylighting(([#NormalTok("arrival_rate ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("service_rate ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1000");],
[],
[#NormalTok("interarrival ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("1");#OperatorTok("/");#NormalTok("arrival_rate, n)");],
[#NormalTok("service_time ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("1");#OperatorTok("/");#NormalTok("service_rate, n)");],
[],
[#NormalTok("arrival_time ");#OperatorTok("=");#NormalTok(" np.cumsum(interarrival)");],
[],
[#NormalTok("start_service ");#OperatorTok("=");#NormalTok(" np.zeros(n)");],
[#NormalTok("finish_service ");#OperatorTok("=");#NormalTok(" np.zeros(n)");],
[],
[#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(n):");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" i ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("        start_service[i] ");#OperatorTok("=");#NormalTok(" arrival_time[i]");],
[#NormalTok("    ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("        start_service[i] ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(arrival_time[i], finish_service[i");#OperatorTok("-");#DecValTok("1");#NormalTok("])");],
[#NormalTok("    ");],
[#NormalTok("    finish_service[i] ");#OperatorTok("=");#NormalTok(" start_service[i] ");#OperatorTok("+");#NormalTok(" service_time[i]");],
[],
[#NormalTok("waiting_time ");#OperatorTok("=");#NormalTok(" start_service ");#OperatorTok("-");#NormalTok(" arrival_time");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Average waiting time:\"");#NormalTok(", np.mean(waiting_time))");],));
#block[
#Skylighting(([#NormalTok("Average waiting time: 0.7018971085492183");],));
]
]
Ini sudah menjadi #strong[simulasi dasar sistem antrian].

== 7. Insight penting untuk mahasiswa
<insight-penting-untuk-mahasiswa>
Dengan simulasi ini mahasiswa melihat bahwa:

#Skylighting(([#NormalTok("random events");],
[#NormalTok("→ Poisson arrival");],
[#NormalTok("→ Exponential waiting time");],
[#NormalTok("→ queueing systems");],));
Ini membuat probabilitas terasa #strong[hidup], bukan sekadar rumus.

= Rantai Distribusi Probabilitas dalam Engineering
<rantai-distribusi-probabilitas-dalam-engineering>
#Skylighting(([#NormalTok("Bernoulli → Binomial → Poisson → Exponential → Queueing Theory ");],));
Menggunakan rujukan antara lain #cite(<mahayana>, form: "prose"), Kita bahas satu per satu secara intuitif.

\$\#\# 1. Bernoulli --- kejadian dasar (sukses / gagal)

$ P \( X = 1 \) = p \, \; P \( X = 0 \) = 1 - p $ Bernoulli adalah #strong[atom dari probabilitas diskrit].

Contoh:

- bit diterima benar / salah

- packet berhasil / hilang

- komponen hidup / gagal

Ini adalah #strong[model kejadian tunggal].

Dalam engineering digital:

#Skylighting(([#NormalTok("error bit = Bernoulli trial ");],));
== 2. Binomial --- jumlah sukses dalam n percobaan
<binomial-jumlah-sukses-dalam-n-percobaan>
$ P \( X = k \) = binom(n, k) p^k \( 1 - p \)^(n - k) $

Jika kita melakukan #strong[banyak Bernoulli trial], kita mendapat distribusi Binomial.

Contoh engineering:

- jumlah error dalam 1000 bit

- jumlah packet loss dalam 100 transmisi

- jumlah mahasiswa lulus ujian

Binomial menjawab:

#Skylighting(([#NormalTok("berapa banyak kejadian sukses dalam n percobaan ");],));
== 3. Poisson --- kejadian langka dalam waktu/ruang
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

#Skylighting(([#NormalTok("berapa kejadian dalam interval waktu ");],));
== 4. Exponential --- waktu antar kejadian
<exponential-waktu-antar-kejadian>
Jika kejadian mengikuti Poisson process, maka #strong[jarak waktu antar kejadian] mengikuti distribusi #strong[Exponential].

$ f \( t \) = lambda e^(- lambda t) $

Contoh:

- waktu antar telepon masuk

- waktu antar packet arrival

- waktu antar kegagalan komponen

Ini sangat penting karena memiliki sifat:

#Skylighting(([#NormalTok("memoryless ");],));
Artinya:

masa depan #strong[tidak bergantung masa lalu].

== 5. Queueing Theory --- sistem pelayanan
<queueing-theory-sistem-pelayanan>
Jika:

- arrival mengikuti #strong[Poisson]

- service time mengikuti #strong[Exponential]

maka kita mendapatkan model antrian klasik:

#Skylighting(([#NormalTok("M/M/1 queue ");],));
dimana

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([simbol], [arti],),
  table.hline(),
  [M], [Markov (Poisson arrival)],
  [M], [exponential service],
  [1], [satu server],
)
Model ini dipakai untuk:

- server komputer

- call center

- jaringan internet

- sistem produksi

== 6. Diagram besar probabilitas sistem teknik
<diagram-besar-probabilitas-sistem-teknik>
Struktur besar:

#Skylighting(([#NormalTok("kejadian dasar      ↓ Bernoulli trial      ↓ Binomial (jumlah sukses)      ↓ Poisson (kejadian per waktu)      ↓ Exponential (waktu antar kejadian)      ↓ Queueing systems ");],));
Ini adalah #strong[salah satu rantai konsep paling penting dalam engineering systems].

== 7. Intuisi besar (sangat penting)
<intuisi-besar-sangat-penting>
Ada dua cara melihat dunia:

====== dunia statistik
<dunia-statistik>
#Skylighting(([#NormalTok("menghitung kejadian ");],));
====== dunia sistem
<dunia-sistem>
#Skylighting(([#NormalTok("kejadian → waktu antar kejadian → sistem antrian ");],));
Karena itu dalam engineering:

#Skylighting(([#NormalTok("probability → stochastic process → queueing ");],));
== 8. Contoh nyata: server web
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

Terdapat juga bisa #strong[hubungan yang lebih dalam lagi yang sangat elegan], yaitu:

#Skylighting(([#NormalTok("Bernoulli → Geometric → Negative Binomial → Poisson → Exponential → Gamma ");],));
Ini sebenarnya adalah #strong[keluarga distribusi yang berasal dari proses yang sama].

Dan ini sangat indah secara matematis.

= References
<references>
#block[
] <refs>



#bibliography(("ref.bib"))

