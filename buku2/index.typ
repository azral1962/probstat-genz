// Quarto-managed appendix state
// bookly has its own states.isappendix, but we track separately for Quarto elements
#let appendix-state = state("quarto-appendix", false)

// Helper to check appendix mode
#let in-appendix() = appendix-state.get()

// Chapter-based numbering for books with appendix support
// Note: bookly handles most numbering internally via its states, these are for Quarto elements
#let equation-numbering = it => {
  let pattern = if in-appendix() { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}

#let callout-numbering = it => {
  let pattern = if in-appendix() { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}

#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if in-appendix() { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if appendix-state.at(loc) { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}

// Chapter-based figure numbering for Quarto's custom float kinds
// Bookly's built-in numbering may not cover Quarto's custom kinds
// (quarto-float-fig, quarto-float-tbl, etc.), so we apply this globally
#let figure-numbering(num) = {
  let chapter = counter(heading).get().first()
  let pattern = if in-appendix() { "A.1" } else { "1.1" }
  numbering(pattern, chapter, num)
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

// Empty page.typ - overrides Quarto's core page.typ
// Marginalia setup is handled in typst-show.typ AFTER bookly.with()
// to ensure marginalia's margins override bookly's default margins
// Import bookly and its key functions
#import "@local/bookly:1.1.3": bookly, part, appendix, front-matter, main-matter

// Apply bookly template
// Note: title-page: none disables bookly's title page (Quarto handles its own)
#show: bookly.with(
  title: [Pengambilan Keputusan Berbasis Probabilitas dan Statistika],
  author: "Armein Z. R. Langi",
  title-page: none,
)

// Use main-matter for standard book content
#show: main-matter


// Apply chapter-based numbering to all figures
// Bookly may not number Quarto's custom figure kinds (quarto-float-fig, etc.)
#set figure(numbering: figure-numbering)
#set text(lang:"id")
#outline()
// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Pengantar]
<pengantar>
Ada begitu banyak buku dan situs tentang probabilitas dan statistika, mengapa buku ini? Buku ini ditulis untuk mahasiswa tingkat 2 dengan tujuan spesifik: menguasai simulasi Python, menguasai teori, dan menguasai aplikasi. dengan urutan prioritas seperti itu.

Niat penulisan buku ini membuat mahasiswa menyadari kegunaann, kekayaaan, dan keindahan konsep probabilitas dan statistika. Tema yang dpilih adalah pengambilan keputusan (#emph[decision making]). Jadi setiap bab dimulai dengan problem yang mengandung ketidak-pastian. Problem ini kemudian dimodelkan secara probabiltas da statistika, sehingga logika probabilitas dan statistika dapat digunaan sebagai dasar pengambilan keputusan.

Buku ini sebenarnya mirip buku resep masakan. Enaknya makanan yang ditulis baru benar terasaa saat resep itu di realisasikan menjadi makaanan. Demikian juga manfaat kode-kode yang ditulis baru terasa saat di ekskeusi.

Semoga buku ini mencapai tujuan penulisannya.

Bandung, 25 Maret 2026 Penyusun, Armein Z. R. langi

= Minggu 01: Pola Pikir Probabilistik vs Deterministik
<minggu-01-pola-pikir-probabilistik-vs-deterministik>
== Tujuan Belajar
<tujuan-belajar>
"Understanding Probabilistic Way of Thinking versus Deterministic Way of Thinking"

#figure([
#box(image("ch/../The_Decision_Engineer.png/image1.png"))
], caption: figure.caption(
position: bottom, 
[
“Bayangin kamu pegang stok toko. Kalau kamu bilang ‘permintaan pasti 100', kamu terlihat rapi… sampai kenyataan menampar. Permintaan itu goyang---kadang 70, kadang 160. Nah, pertanyaan pentingnya: kamu mau terlihat yakin, atau mau benar? Probabilitas itu bukan bikin kita ragu---justru bikin kita #emph[berani mengambil keputusan] dengan risiko yang dihitung. Hari ini kita latihan satu skill: membedakan dunia deterministik vs dunia nyata yang random. Dan keputusan kamu akan kita ukur: berapa peluang kehabisan stok kalau kamu nekat ‘pasti 100'?”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


=== Apa yang Kita Pelajari?
<apa-yang-kita-pelajari>
Memahami bahwa dalam dunia nyata, fenomena seringkali mengandung ketidakpastian (randomness) dan tidak dapat diprediksi dengan kepastian mutlak (deterministik), sehingga memerlukan kerangka kerja matematika untuk mengukur ketidakpastian tersebut.

#strong[Tipikal Problem] Sebuah toko ingin menentukan stok barang. Pendekatan deterministik mengasumsikan permintaan konstan (misal: pasti 100 unit), sedangkan realitanya permintaan berfluktuasi secara acak.

#strong[Solusi & Pengambilan Keputusan] Menggunakan model probabilistik untuk menghitung peluang terjadinya berbagai tingkat permintaan, sehingga manajer dapat menentukan level safety stock yang optimal untuk meminimalkan risiko kekurangan stok tanpa menimbun barang berlebihan. Disini sumber random adalah permintaan harian

== Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python>
Berikut buat python code untuk mensimulasikan permintaan barang (rata-rata 100 unit perhari) dan keputusan berapa yang akan di stok tiap hari: serta akibanya pada biaya sewa gudang (bila ada yang tidak laku) dan hilangnya potensi penjualan, dan kecewanya langganan tidak terlayani (bila barang habis)

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#CommentTok("# Konfigurasi Simulasi");],
[#NormalTok("np.random.seed(");#DecValTok("42");#NormalTok(")  ");#CommentTok("# Agar hasil konsisten saat dijalankan ulang");],
[#NormalTok("days ");#OperatorTok("=");#NormalTok(" ");#DecValTok("30");],
[#NormalTok("average_demand ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("std_dev_demand ");#OperatorTok("=");#NormalTok(" ");#DecValTok("20");],
[#NormalTok("initial_stock ");#OperatorTok("=");#NormalTok(" ");#DecValTok("150");],
[#NormalTok("order_quantity ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");#NormalTok(" ");#CommentTok("# Jumlah stok yang dipesan jika stok rendah");],
[#NormalTok("reorder_point ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");#NormalTok("   ");#CommentTok("# Batas stok untuk memesan ulang");],
[],
[#CommentTok("# Biaya-biaya");],
[#NormalTok("holding_cost_per_unit ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok("   ");#CommentTok("# Biaya gudang per unit sisa");],
[#NormalTok("stockout_cost_per_unit ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");#NormalTok(" ");#CommentTok("# Biaya kehilangan pelanggan per unit habis");],));
]
KalAu kita simulasikan jumlah kebutuhan yang bersifat acak itu

#block[
#Skylighting(([#CommentTok("# Inisialisasi variabel simulasi");],
[#NormalTok("inventory ");#OperatorTok("=");#NormalTok(" initial_stock");],
[#NormalTok("results ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" day ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", days ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("    ");#CommentTok("# 1. Simulasi Permintaan Harian");],
[#NormalTok("    demand ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(np.random.normal(average_demand, std_dev_demand))");],
[#NormalTok("    demand ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(");#DecValTok("0");#NormalTok(", demand)  ");#CommentTok("# Permintaan tidak bisa negatif");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 2. Proses Penjualan");],
[#NormalTok("    units_sold ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("min");#NormalTok("(inventory, demand)");],
[#NormalTok("    stockout ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(");#DecValTok("0");#NormalTok(", demand ");#OperatorTok("-");#NormalTok(" units_sold)");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 3. Update Inventaris");],
[#NormalTok("    inventory ");#OperatorTok("-=");#NormalTok(" units_sold");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 4. Keputusan Stok (Reorder Policy)");],
[#NormalTok("    order_arrived ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" inventory ");#OperatorTok("<");#NormalTok(" reorder_point:");],
[#NormalTok("        inventory ");#OperatorTok("+=");#NormalTok(" order_quantity");],
[#NormalTok("        order_arrived ");#OperatorTok("=");#NormalTok(" order_quantity");],
[#NormalTok("        ");],
[#NormalTok("    ");#CommentTok("# 5. Hitung Biaya");],
[#NormalTok("    holding_cost ");#OperatorTok("=");#NormalTok(" inventory ");#OperatorTok("*");#NormalTok(" holding_cost_per_unit");],
[#NormalTok("    stockout_cost ");#OperatorTok("=");#NormalTok(" stockout ");#OperatorTok("*");#NormalTok(" stockout_cost_per_unit");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Simpan Hasil Harian");],
[#NormalTok("    results.append({");],
[#NormalTok("        ");#StringTok("'Hari'");#NormalTok(": day,");],
[#NormalTok("        ");#StringTok("'Permintaan'");#NormalTok(": demand,");],
[#NormalTok("        ");#StringTok("'Stok Awal'");#NormalTok(": inventory ");#OperatorTok("+");#NormalTok(" units_sold ");#OperatorTok("-");#NormalTok(" order_arrived,");],
[#NormalTok("        ");#StringTok("'Terjual'");#NormalTok(": units_sold,");],
[#NormalTok("        ");#StringTok("'Sisa Stok'");#NormalTok(": inventory,");],
[#NormalTok("        ");#StringTok("'Stockout'");#NormalTok(": stockout,");],
[#NormalTok("        ");#StringTok("'Biaya Gudang'");#NormalTok(": holding_cost,");],
[#NormalTok("        ");#StringTok("'Biaya Stockout'");#NormalTok(": stockout_cost");],
[#NormalTok("    })");],));
]
Dan sekarang kita jawab pertanyaan-pertanyaan tadi.

#block[
#Skylighting(([#CommentTok("# Analisis Hasil");],
[#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.DataFrame(results)");],
[#BuiltInTok("print");#NormalTok("(df.to_string(index");#OperatorTok("=");#VariableTok("False");#NormalTok("))");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("\"");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#StringTok("\"=\"");#OperatorTok("*");#DecValTok("30");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"RINGKASAN SIMULASI 30 HARI\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"=\"");#OperatorTok("*");#DecValTok("30");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Permintaan       : ");#SpecialCharTok("{");#NormalTok("df[");#StringTok("'Permintaan'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("()");#SpecialCharTok("}");#SpecialStringTok(" unit\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Terjual          : ");#SpecialCharTok("{");#NormalTok("df[");#StringTok("'Terjual'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("()");#SpecialCharTok("}");#SpecialStringTok(" unit\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Stockout (Habis) : ");#SpecialCharTok("{");#NormalTok("df[");#StringTok("'Stockout'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("()");#SpecialCharTok("}");#SpecialStringTok(" unit\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Biaya Gudang     : Rp ");#SpecialCharTok("{");#NormalTok("df[");#StringTok("'Biaya Gudang'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("()");#SpecialCharTok(":,.0f}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Biaya Stockout   : Rp ");#SpecialCharTok("{");#NormalTok("df[");#StringTok("'Biaya Stockout'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("()");#SpecialCharTok(":,.0f}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Biaya Operasional: Rp ");#SpecialCharTok("{");#NormalTok("df[");#StringTok("'Biaya Gudang'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("() ");#OperatorTok("+");#NormalTok(" df[");#StringTok("'Biaya Stockout'");#NormalTok("]");#SpecialCharTok(".");#BuiltInTok("sum");#NormalTok("()");#SpecialCharTok(":,.0f}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok(" Hari  Permintaan  Stok Awal  Terjual  Sisa Stok  Stockout  Biaya Gudang  Biaya Stockout");],
[#NormalTok("    1         109        150      109        141         0           282               0");],
[#NormalTok("    2          97        141       97        144         0           288               0");],
[#NormalTok("    3         112        144      112        132         0           264               0");],
[#NormalTok("    4         130        132      130        102         0           204               0");],
[#NormalTok("    5          95        102       95        107         0           214               0");],
[#NormalTok("    6          95        107       95        112         0           224               0");],
[#NormalTok("    7         131        112      112        100        19           200             190");],
[#NormalTok("    8         115        100      100        100        15           200             150");],
[#NormalTok("    9          90        100       90        110         0           220               0");],
[#NormalTok("   10         110        110      110        100         0           200               0");],
[#NormalTok("   11          90        100       90        110         0           220               0");],
[#NormalTok("   12          90        110       90        120         0           240               0");],
[#NormalTok("   13         104        120      104        116         0           232               0");],
[#NormalTok("   14          61        116       61         55         0           110               0");],
[#NormalTok("   15          65         55       55        100        10           200             100");],
[#NormalTok("   16          88        100       88        112         0           224               0");],
[#NormalTok("   17          79        112       79        133         0           266               0");],
[#NormalTok("   18         106        133      106        127         0           254               0");],
[#NormalTok("   19          81        127       81        146         0           292               0");],
[#NormalTok("   20          71        146       71         75         0           150               0");],
[#NormalTok("   21         129         75       75        100        54           200             540");],
[#NormalTok("   22          95        100       95        105         0           210               0");],
[#NormalTok("   23         101        105      101        104         0           208               0");],
[#NormalTok("   24          71        104       71        133         0           266               0");],
[#NormalTok("   25          89        133       89        144         0           288               0");],
[#NormalTok("   26         102        144      102        142         0           284               0");],
[#NormalTok("   27          76        142       76         66         0           132               0");],
[#NormalTok("   28         107         66       66        100        41           200             410");],
[#NormalTok("   29          87        100       87        113         0           226               0");],
[#NormalTok("   30          94        113       94        119         0           238               0");],
[],
[#NormalTok("==============================");],
[#NormalTok("RINGKASAN SIMULASI 30 HARI");],
[#NormalTok("==============================");],
[#NormalTok("Total Permintaan       : 2870 unit");],
[#NormalTok("Total Terjual          : 2731 unit");],
[#NormalTok("Total Stockout (Habis) : 139 unit");],
[#NormalTok("Total Biaya Gudang     : Rp 6,736");],
[#NormalTok("Total Biaya Stockout   : Rp 1,390");],
[#NormalTok("Total Biaya Operasional: Rp 8,126");],));
]
]
#strong[Penjelasan Kode:]

- #emph[np.random.normal]: Membuat variasi permintaan harian agar tidak kaku di angka 100.

- #emph[units\_sold]: Jika permintaan (120) \> stok (100), barang yang terjual hanya 100.

- #emph[stockout]: Jika stok habis, pelanggan kecewa. Biaya tinggi (10) diberikan untuk mencerminkan dampak ini.

- #emph[reorder\_point]: Jika stok sisa 50 atau kurang, sistem menambah stok (misal: pesan 100 unit).

- #emph[Biaya Gudang]: Dihitung dari Sisa Stok \* biaya per unit.

- #emph[Biaya Stockout]: Dihitung dari Stockout \* biaya per unit.

Anda bisa mengubah #emph[order\_quantity] dan #emph[reorder\_point] untuk melihat skenario mana yang menghasilkan total biaya terendah.

== #strong[Materi Kuliah: Konsep, Aplikasi, & Komputasi]
<materi-kuliah-konsep-aplikasi-komputasi>
#strong[\1. Konsep Dasar]

- #strong[Deterministik vs Stokastik:] Deterministik adalah sebab-akibat pasti (Input A $arrow.r$ Output B), contoh: #NormalTok("1 + 1 = 2");. Stokastik mengandung elemen acak, contoh: Waktu kedatangan paket data di router.

- #strong[Ruang Sampel (]$Omega$): Himpunan seluruh kemungkinan hasil. Dalam #emph[load testing], $Omega$ bisa berupa {Sukses, Timeout, Error 500}.

- #strong[Hukum Bilangan Besar (LLN):] Jaminan matematis bahwa rata-rata sampel empiris akan mendekati rata-rata teoretis seiring bertambahnya jumlah percobaan.

#strong[\2. Aplikasi Sistem Informasi] \* #strong[Reliabilitas Infrastruktur:] Menghitung risiko kegagalan. Kegagalan dua server cadangan tidak selalu independen (misal: mati listrik satu gedung mematikan keduanya). \* #strong[Kualitas Layanan (QoS):] Probabilitas digunakan untuk menentukan bandwidth minimum agar #emph[video streaming] tidak #emph[buffering] bagi 99% user.

#strong[\3. Komputasi (Python)] \* #strong[Generasi Angka Acak:] Menggunakan #NormalTok("numpy.random"); untuk memodelkan ketidakpastian. \* #strong[Simulasi Monte Carlo:] Metode komputasi untuk menaksir probabilitas dengan melakukan ribuan percobaan acak.

#horizontalrule

== #strong[Tugas Kelompok (GitHub Classroom)]
<tugas-kelompok-github-classroom>
#strong[Judul:] #emph[Week 1 Mission: Simulating Reliability & Risk]

#strong[Deskripsi:] Mahasiswa diberikan #emph[starter notebook] yang berisi skenario sistem #emph[Disaster Recovery]. Mereka harus melengkapi kode untuk mensimulasikan kegagalan server dan menjawab pertanyaan bisnis.

#strong[Soal Python:]

+ Buat fungsi #NormalTok("simulate_server_uptime(days, prob_failure)"); yang mengembalikan status server (Up/Down) selama n-hari.

+ 2Simulasikan dua server (Server A dan B) yang bekerja paralel. Sistem Down hanya jika #strong[keduanya] Down.

+ Bandingkan: Berapa hari sistem Down jika menggunakan 1 server vs 2 server?

+ #strong[Analisis:] Jika biaya server ke-2 adalah \$100/hari dan biaya sistem Down adalah \$5000/hari, apakah #emph[worth it] menyewa server ke-2? (Jawab dengan grafik profit/loss).

#strong[Submission:] Push #NormalTok(".ipynb"); ke repo GitHub Classroom. Penilaian otomatis via GitHub Actions untuk kelengkapan kode, penilaian manual untuk analisis keputusan.

#horizontalrule

== #strong[15 Soal & Solusi]
<soal-solusi>
Berikut adalah 15 soal.

=== #strong[A. Pertanyaan Konseptual]
<a.-pertanyaan-konseptual>
#strong[\1. Soal:] Jelaskan perbedaan mendasar antara fenomena deterministik (seperti operasi penjumlahan di CPU) dan fenomena probabilistik (seperti waktu kedatangan paket di router).

\* #strong[Solusi:] Fenomena deterministik selalu menghasilkan output yang sama untuk input dan kondisi awal yang sama (kepastian mutlak). Fenomena probabilistik memiliki variasi inheren di mana input yang sama bisa menghasilkan output berbeda, sehingga hanya bisa diprediksi pola atau peluangnya, bukan hasil pastinya.

#strong[\2. Soal:] Mengapa pendekatan #emph[Frequentist] memerlukan asumsi pengulangan eksperimen dalam kondisi yang identik?

\* #strong[Solusi:] Karena pendekatan Frequentist mendefinisikan probabilitas sebagai limit dari frekuensi relatif ($n \/ N$) saat jumlah percobaan ($N$) mendekati tak hingga. Tanpa pengulangan kondisi identik, frekuensi relatif tidak akan konvergen ke nilai yang bermakna.

#strong[\3. Soal:] Definisikan ruang sampel dalam konteks pengujian beban (#emph[load testing]) sebuah situs web e-commerce.

\* #strong[Solusi:] Ruang sampel adalah himpunan semua kemungkinan status respons server terhadap satu #emph[request]. Contoh: $Omega = { upright("HTTP 200 OK") \, upright("HTTP 404 Not Found") \, upright("HTTP 500 Server Error") \, upright("Timeout") }$.

#strong[\4. Soal:] Apa yang dimaksud dengan interpretasi probabilitas subjektif (Bayesian) dan bagaimana relevansinya dalam pengambilan keputusan manajerial?

\* #strong[Solusi:] Probabilitas subjektif adalah ukuran "derajat keyakinan" seseorang berdasarkan informasi yang tersedia saat ini (bukan frekuensi fisik). Ini relevan bagi manajer untuk mengambil keputusan pada kejadian yang tidak berulang (misal: "Peluang sukses peluncuran produk baru") di mana data historis mungkin tidak ada.

#strong[\5. Soal:] Jelaskan peran hukum bilangan besar (Law of Large Numbers) dalam validasi simulasi sistem.

\* #strong[Solusi:] LLN menjamin bahwa hasil simulasi rata-rata (empiris) akan mendekati nilai ekspektasi teoretis sistem jika simulasi dijalankan cukup lama/banyak. Ini memvalidasi bahwa hasil simulasi komputer merepresentasikan perilaku sistem yang sebenarnya.

=== #strong[B. Pertanyaan Aplikatif]
<b.-pertanyaan-aplikatif>
#strong[\6. Soal:] Sebuah sistem Disaster Recovery Center (DRC) memiliki dua server cadangan. Jika probabilitas satu server gagal adalah 0,05, jelaskan mengapa kegagalan keduanya tidak selalu 0,0025 dalam kondisi nyata.

\* #strong[Solusi:] Angka 0,0025 ($0 \, 05 times 0 \, 05$) hanya berlaku jika kegagalan kedua server #strong[independen]. Dalam dunia nyata, sering terjadi #emph[Common Cause Failure] (misal: pemadaman listrik satu gedung, banjir, atau #emph[bug] software yang sama) yang membuat keduanya gagal bersamaan, sehingga probabilitasnya \> 0,0025.

#strong[\7. Soal:] Analisis bagaimana fluktuasi jumlah pengguna aktif di platform media sosial dapat dimodelkan sebagai proses stokastik.

\* #strong[Solusi:] Jumlah pengguna tidak konstan tetapi berubah terhadap waktu secara acak. Ini dapat dimodelkan sebagai proses stokastik (misalnya Proses Poisson untuk kedatangan pengguna baru) di mana variabel acak $X \( t \)$ mewakili jumlah pengguna pada waktu $t$.

#strong[\8. Soal:] Gunakan konsep probabilitas untuk mengevaluasi risiko kehilangan data pada media penyimpanan RAID 0 dibandingkan RAID 1.

\* #strong[Solusi:] RAID 0 (Striping) gagal jika #strong[salah satu] disk gagal (Sistem Seri, risiko tinggi). RAID 1 (Mirroring) gagal hanya jika #strong[semua] disk gagal (Sistem Paralel, risiko rendah/redundansi). Probabilitas kehilangan data RAID 0 \> RAID 1.

#strong[\9. Soal:] Jika sebuah algoritma enkripsi memiliki probabilitas tabrakan (#emph[collision]) $10^(- 15)$, sejauh mana tingkat kepercayaan pengembang pada integritas data? \* #strong[Solusi:] Tingkat kepercayaan sangat tinggi (hampir absolut). Dalam skala probabilistik, $10^(- 15)$ dianggap sebagai kejadian yang secara praktis mustahil terjadi dalam operasional normal, memberikan jaminan integritas data yang kuat ("Probabilistic Guarantee").

#strong[\10. Soal:] Bagaimana probabilitas digunakan dalam menentukan kapasitas bandwidth minimum untuk menjamin kualitas layanan (QoS) video streaming?

\* #strong[Solusi:] Provider tidak menyediakan bandwidth untuk #emph[peak] teoritis semua user (mahal), melainkan menggunakan probabilitas untuk menjamin (misalnya) 99.9% waktu, bandwidth cukup. Ini dihitung menggunakan distribusi beban user agar probabilitas #emph[congestion] \< 0.1%.

=== #strong[C. Pertanyaan Komputasional]
<c.-pertanyaan-komputasional>
#strong[\11. Soal:] Tulis skrip Python untuk mensimulasikan 10.000 percobaan pelemparan koin tidak adil ($p = 0 \, 6$) dan plot konvergensi frekuensi relatifnya.

\* #strong[Solusi:] \`\`\`python import numpy as np import matplotlib.pyplot as plt

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np        ");],
[#NormalTok("n_trials ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10000");],
[#NormalTok("p_head ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.6");],
[#CommentTok("# Simulasi: 1 = Head, 0 = Tail");],
[#NormalTok("flips ");#OperatorTok("=");#NormalTok(" np.random.choice([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("], size");#OperatorTok("=");#NormalTok("n_trials, p");#OperatorTok("=");#NormalTok("[");#DecValTok("1");#OperatorTok("-");#NormalTok("p_head, p_head])");],
[#CommentTok("# Hitung rata-rata kumulatif");],
[#NormalTok("cumulative_avg ");#OperatorTok("=");#NormalTok(" np.cumsum(flips) ");#OperatorTok("/");#NormalTok(" np.arange(");#DecValTok("1");#NormalTok(", n_trials ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("plt.plot(cumulative_avg)");],
[#NormalTok("plt.axhline(p_head, color");#OperatorTok("=");#StringTok("'r'");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(") ");#CommentTok("# Garis teoretis");],
[#NormalTok("plt.xlabel(");#StringTok("\"Jumlah Lemparan\"");#NormalTok(")");#OperatorTok(";");#NormalTok(" plt.ylabel(");#StringTok("\"Frekuensi Relatif Head\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("ch/01-Pola_Pikir_Probabilistik_vs_Deterministik_files/figure-typst/cell-5-output-1.svg"))

#strong[\12. Soal:] Gunakan pustaka #NormalTok("random"); untuk menghasilkan 1.000 sampel waktu tunggu login dan hitung nilai rata-ratanya. \* #strong[Solusi:]

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" random     ");],
[#CommentTok("# Asumsi: Waktu tunggu 0-5 detik     ");],
[#NormalTok("wait_times ");#OperatorTok("=");#NormalTok(" [random.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("5");#NormalTok(") ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok(")]     ");],
[#NormalTok("average_time ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(wait_times) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(wait_times)     ");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Rata-rata waktu tunggu: ");#SpecialCharTok("{");#NormalTok("average_time");#SpecialCharTok(":.4f}");#SpecialStringTok(" detik\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Rata-rata waktu tunggu: 2.5527 detik");],));
]
]
#strong[\13. Soal:] Buatlah simulasi Monte Carlo untuk menghitung luas area di bawah kurva fungsi acak sederhana yang merepresentasikan beban kerja server.

\* #strong[Solusi:]

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np     ");],
[#CommentTok("# Contoh fungsi beban: y = x^2 di interval     ");],
[#NormalTok("n_points ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10000");#NormalTok("     ");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", n_points)     ");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", n_points)     ");],
[#CommentTok("# Titik di bawah kurva y = x^2     ");],
[#NormalTok("under_curve ");#OperatorTok("=");#NormalTok(" y ");#OperatorTok("<");#NormalTok(" x");#OperatorTok("**");#DecValTok("2");#NormalTok("     ");],
[#NormalTok("area ");#OperatorTok("=");#NormalTok(" np.mean(under_curve) ");#OperatorTok("*");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#CommentTok("# Luas kotak total 1x1");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Estimasi Luas Area: ");#SpecialCharTok("{");#NormalTok("area");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Estimasi Luas Area: 0.3385");],));
]
]
#strong[\14. Soal:] Implementasikan fungsi Python yang menghasilkan seluruh kemungkinan kombinasi dari 4-bit biner dan hitung probabilitas munculnya tepat dua angka '1'.

\* #strong[Solusi:]

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" itertools     ");#CommentTok("# Ruang Sampel     ");],
[#NormalTok("outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("list");#NormalTok("(itertools.product([");#DecValTok("0");#NormalTok(",");#DecValTok("1");#NormalTok("], repeat");#OperatorTok("=");#DecValTok("4");#NormalTok("))     ");#CommentTok("# Kejadian A: Tepat dua angka '1'     ");],
[#NormalTok("event_A ");#OperatorTok("=");#NormalTok(" [bits ");#ControlFlowTok("for");#NormalTok(" bits ");#KeywordTok("in");#NormalTok(" outcomes ");#ControlFlowTok("if");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(bits) ");#OperatorTok("==");#NormalTok(" ");#DecValTok("2");#NormalTok("]     ");],
[#NormalTok("prob_A ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(event_A) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(outcomes)     ");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Probabilitas: ");#SpecialCharTok("{");#NormalTok("prob_A");#SpecialCharTok("}");#SpecialStringTok(" (Seharusnya 6/16 = 0.375)\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Probabilitas: 0.375 (Seharusnya 6/16 = 0.375)");],));
]
]
#strong[\15. Soal:] Gunakan numpy untuk mensimulasikan distribusi umur pakai 500 hard disk berdasarkan data kegagalan historis.

\* #strong[Solusi:]

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np     ");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt     ");],
[#CommentTok("# Asumsi: Umur pakai berdistribusi Eksponensial (MTTF = 5 tahun)     ");],
[#NormalTok("mttf ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");#NormalTok("     ");],
[#NormalTok("lifetimes ");#OperatorTok("=");#NormalTok(" np.random.exponential(scale");#OperatorTok("=");#NormalTok("mttf, size");#OperatorTok("=");#DecValTok("500");#NormalTok(")");],
[#NormalTok("plt.hist(lifetimes, bins");#OperatorTok("=");#DecValTok("20");#NormalTok(")     ");],
[#NormalTok("plt.title(");#StringTok("\"Simulasi Umur Pakai Hard Disk\"");#NormalTok(")     ");],
[#NormalTok("plt.show()");],));
#box(image("ch/01-Pola_Pikir_Probabilistik_vs_Deterministik_files/figure-typst/cell-9-output-1.svg"))

= Minggu 02: Kerangka Probabilitas dan Statistik
<minggu-02-kerangka-probabilitas-dan-statistik>
Probabilistic Experiment, Sample Space, Event, Probability Definition and Axioms

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image2.png"))
], caption: figure.caption(
position: bottom, 
[
“Kamu kirim 3 bit data. Kedengarannya kecil… tapi ada ‘semesta' di belakangnya: semua kombinasi yang mungkin. Kalau kamu nggak mendefinisikan ruang sampel dan event dengan benar, kamu bakal salah hitung kualitas sistem komunikasi. Hari ini kita bikin cara pikir yang rapi: apa itu eksperimen, apa itu sample space, apa itu event, dan kenapa aksioma probabilitas itu ‘aturan main semesta'. Setelah ini, kamu bukan cuma bisa hitung peluang---kamu bisa #emph[merancang] perhitungan peluang.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== Apa Yang Kita pelajari?
<apa-yang-kita-pelajari-1>
Ruang sampel (S) sebagai himpunan semua hasil yang mungkin, kejadian (E) sebagai himpunan bagian dari ruang sampel, dan aksioma probabilitas (nilai peluang antara 0 dan 1, total peluang semesta = 1).

#strong[Tipikal Problem] Dalam pengiriman data digital, kita ingin mengetahui peluang terjadinya kesalahan bit. Jika dikirim 3 bit, apa ruang sampelnya dan berapa peluang setidaknya satu bit salah?

#strong[Solusi & Pengambilan Keputusan] Mendaftar ruang sampel S = {000, 001, …, 111}. Jika kejadian E adalah 'setidaknya satu error', kita hitung jumlah elemen di E dibagi total elemen di S untuk mendapatkan probabilitasnya, yang digunakan untuk menentukan kualitas saluran komunikasi.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-1>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 02!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 02!");],));
]
]
Minggu 2: Kerangka Probabilitas dan Operasi Kejadian\*\*

== #strong[Agenda Perkuliahan Minggu 2]
<agenda-perkuliahan-minggu-2>
#strong[Tema Misi:] #emph["Mapping the Glitch: From Chaos to Logical Sets"]

=== #strong[Pertemuan 1: Senin (1 Jam) -- #emph[The Framework & Intuition]]
<pertemuan-1-senin-1-jam-the-framework-intuition>
#emph[Fokus: Membangun mental model tentang "Semesta Kemungkinan" (]$Omega$) dan menerjemahkan logika sistem menjadi Himpunan.

- #strong[00:00 -- 00:10 | The Hook: "The Glitch in the Matrix"]
  - #strong[Aktivitas:] Tampilkan visual #emph[glitch] pada video streaming atau pesan teks yang rusak.
  - #strong[Pertanyaan:] "Komputer bicara dengan 0 dan 1. Jika kita kirim 3 bit dan ada gangguan sinyal, apa saja #emph[universe of possibilities] yang mungkin diterima?"
  - #strong[Relevansi:] Mengenalkan #strong[Ruang Sampel (]$Omega$) bukan sebagai definisi buku, tapi sebagai daftar semua skenario sistem.
- #strong[00:10 -- 00:30 | Live Coding: Membangun Semesta]
  - #strong[Dosen (Python Demo):] Gunakan #NormalTok("itertools.product"); untuk men-generate semua kombinasi bit (000, 001, …, 111).
  - #strong[Konsep:] Tunjukkan bahwa ukuran semesta adalah $2^n$. Definisikan "Kejadian" ($E$) sebagai filter/query: misal #emph[Event A = Error lebih dari 1 bit].
- #strong[00:30 -- 00:50 | Konsep: Logika Himpunan = Logika Data]
  - Hubungkan operator Python dengan Diagram Venn:
    - #strong[AND (]$sect$): Irisan (User Aktif #NormalTok("&"); User Premium).
    - #strong[OR (]$union$): Gabungan (Login via Web #NormalTok("|"); Login via App).
    - #strong[NOT (]$""^c$): Komplemen (Bukan Spam).
  - #strong[Aksioma Kolmogorov:] Jelaskan 3 aturan main yang "haram" dilanggar (Non-negatif, Total=1, Aditivitas).
- #strong[00:50 -- 01:00 | Pod Formation & Mission Brief]
  - Jelaskan misi GitHub: #emph["The Security Filter Project"] (Mendeteksi anomali menggunakan logika himpunan).

=== #strong[Pertemuan 2: Rabu (2 Jam) -- #emph[Simulation Lab]]
<pertemuan-2-rabu-2-jam-simulation-lab>
#emph[Fokus: Hands-on Python untuk memanipulasi himpunan dan memverifikasi hukum probabilitas.]

- #strong[00:00 -- 00:20 | Setup & Micro-Lecture: Jebakan "OR"]
  - #strong[Masalah:] Mengapa $P \( A union B \) eq.not P \( A \) + P \( B \)$?
  - #strong[Visual:] Tunjukkan #emph[double counting] pada irisan diagram Venn. Perkenalkan Prinsip Inklusi-Eksklusi.
- #strong[00:20 -- 01:00 | Pod Challenge: "User Segmentation Analytics"]
  - #strong[Skenario:] Mahasiswa diberikan data dummy 1.000 user dengan atribut (iOS/Android, Paid/Free, Active/Churn).
  - #strong[Tugas (Python):]
    + Hitung peluang user adalah (iOS #strong[DAN] Paid).
    + Hitung peluang user adalah (Android #strong[ATAU] Churn).
    + Verifikasi Hukum De Morgan secara empiris: Apakah #NormalTok("not (A or B)"); sama dengan #NormalTok("(not A) and (not B)");?.
- #strong[01:00 -- 01:30 | Deep Dive: Partisi & Probabilitas Total]
  - Diskusi kasus: "Jika user dipartisi menjadi Low/Mid/High spender, apakah seorang user bisa berada di dua grup?" (Konsep #emph[Mutually Exclusive] & #emph[Collectively Exhaustive]).
- #strong[01:30 -- 01:50 | Showcase & Code Review]
  - Perwakilan Pods menunjukkan #emph[snippet code] operasi himpunan mereka.
- #strong[01:50 -- 02:00 | Exit Ticket]
  - Pertanyaan: "Berikan satu contoh nyata di aplikasi favoritmu di mana dua kejadian bersifat #emph[Mutually Exclusive]."

#horizontalrule

== #strong[Materi Kuliah: Konsep, Aplikasi, & Komputasi]
<materi-kuliah-konsep-aplikasi-komputasi-1>
=== #strong[\1. Konsep Dasar]
<konsep-dasar>
- #strong[Ruang Sampel (]$Omega$): Himpunan seluruh hasil yang mungkin dari eksperimen acak. Dalam sistem digital, ini sering kali diskrit (kombinasi bit, status server).
- #strong[Kejadian (]$E$): Himpunan bagian dari $Omega$. Contoh: Kejadian "Server Down" berisi hasil {Error 500, Error 502, Timeout}.
- #strong[Logika Probabilitas:]
  - #strong[Irisan (]$sect$): Terjadi bersamaan (AND).
  - #strong[Gabungan (]$union$): Salah satu terjadi (OR).
  - #strong[Saling Lepas (#emph[Mutually Exclusive]):] $A sect B = nothing$. Tidak bisa terjadi bersamaan (misal: Status Transaksi Sukses vs Gagal).

=== #strong[\2. Aplikasi Sistem Informasi]
<aplikasi-sistem-informasi>
- #strong[Segmentasi User:] Menggunakan operasi himpunan untuk menargetkan fitur. Misal: $A = upright("Mobile Users")$, $B = upright("High Value")$. Target promo = $A sect B$.
- #strong[Sistem Keamanan:] Sensor redundan. Jika Sensor A mendeteksi intrusi OR Sensor B mendeteksi intrusi ($A union B$), maka alarm bunyi. Perhitungan peluangnya harus membuang irisan agar tidak #emph[double count].
- #strong[Query Database:] SQL #NormalTok("WHERE condition1 AND condition2"); adalah implementasi langsung dari irisan himpunan probabilistik.

=== #strong[\3. Komputasi (Python)]
<komputasi-python>
- #strong[Tipe Data #NormalTok("set");:] Python memiliki tipe data native untuk operasi himpunan matematika.
- #strong[Visualisasi Venn:] Library #NormalTok("matplotlib-venn"); sangat berguna untuk memvisualisasikan proporsi irisan data.
- #strong[Simulasi De Morgan:] Membuktikan identitas logika $\( A union B \)^c = A^c sect B^c$ dengan data acak.

#horizontalrule

== #strong[Tugas Kelompok (GitHub Classroom)]
<tugas-kelompok-github-classroom-1>
#strong[Judul:] #emph[Week 2: The Logic of Glitches - Set Theory in Action]

#strong[Deskripsi:] Anda adalah #emph[Data Engineer] di sebuah platform streaming. Sistem logging Anda mencatat status ribuan sesi user. Tugas Anda adalah membersihkan data dan menghitung probabilitas anomali menggunakan Teori Himpunan.

#strong[Soal Python (Notebook):]

+ 1. #strong[Generate Data:] Buat 10.000 data dummy sesi dengan atribut acak: #NormalTok("region"); (ID/SG/US), #NormalTok("device"); (Mobile/Desktop), dan #NormalTok("status"); (Success/Buffering/Error).

+ 2. #strong[Filter Himpunan:] Buat #NormalTok("set"); Python untuk kejadian:

  + \* $A$: Sesi dari Indonesia (ID).

  + \* $B$: Sesi yang mengalami Error.

+ 3. #strong[Analisis Logika:]

  + \* Hitung $P \( A sect B \)$: Peluang error di Indonesia.

  + \* Hitung $P \( A union B \)$: Peluang sesi berasal dari Indonesia ATAU mengalami error. Gunakan rumus inklusi-eksklusi dan bandingkan hasilnya dengan fungsi #NormalTok("len(A.union(B))");.

+ 4. #strong[Verifikasi De Morgan:] Buktikan dengan kode bahwa "Tidak (ID atau Error)" sama dengan "Bukan ID dan Bukan Error".

#horizontalrule

== #strong[15 Soal & Solusi (Sumber: "Desain Kurikulum Statistika Generasi Z")]
<soal-solusi-sumber-desain-kurikulum-statistika-generasi-z>
Berikut adalah solusi untuk 15 soal yang diambil dari #strong[Minggu 02: Kerangka Probabilitas dan Operasi Kejadian].

=== #strong[A. Pertanyaan Konseptual]
<a.-pertanyaan-konseptual-1>
#strong[\1. Soal:] Jelaskan mengapa aksioma probabilitas Kolmogorov mengharuskan nilai probabilitas berada di rentang \$\$.
\*
\*\*Solusi:\*\* Probabilitas adalah ukuran (\"measure\") dari sebuah himpunan. Nilai non-negatif (\$P(A) $\) a d a l a h s y a r a t m u t l a k u k u r a n f i s i k \/ m a t e m a t i s \( t i d a k a d a p a n j a n g a t a u b e r a t n e g a t i f \) . N i l a i m a k s i m a l 1 \($P()=1\$) adalah hasil dari normalisasi, yang menetapkan bahwa "sesuatu dalam semesta pasti terjadi".

#strong[\2. Soal:] Apa perbedaan antara kejadian saling lepas (#emph[mutually exclusive]) dan kejadian kolektif lengkap (#emph[collectively exhaustive])?

\* #strong[Solusi:] \* #emph[Saling Lepas:] Kejadian tidak memiliki irisan ($A sect B = nothing$). Tidak bisa terjadi bersamaan. \* #emph[Kolektif Lengkap:] Gabungan kejadian mencakup seluruh ruang sampel ($A union B = Omega$). Salah satu pasti terjadi. \* #emph[Partisi:] Jika kejadian bersifat keduanya sekaligus.

#strong[\3. Soal:] Buktikan secara grafis menggunakan diagram Venn mengapa $P \( A union B \) = P \( A \) + P \( B \) - P \( A sect B \)$.

\* #strong[Solusi:] Bayangkan dua lingkaran $A$ dan $B$ yang tumpang tindih. Jika kita menjumlahkan luas $A$ dan luas $B$, area irisan di tengah ($A sect B$) terhitung dua kali. Oleh karena itu, kita harus mengurangkan satu kali area irisan tersebut agar total luasnya akurat.

#strong[\4. Soal:] Mengapa probabilitas dari ruang sampel $Omega$ harus bernilai 1?

\* #strong[Solusi:] Ini adalah Aksioma Normalisasi. $Omega$ mendefinisikan "seluruh kemungkinan hasil". Probabilitas 1 merepresentasikan kepastian mutlak bahwa #emph[salah satu] dari hasil tersebut akan terjadi setelah eksperimen dilakukan.

#strong[\5. Soal:] Jelaskan konsep partisi ruang sampel dalam konteks segmentasi pengguna aplikasi.

\* #strong[Solusi:] Partisi membagi seluruh user base ($Omega$) menjadi kelompok-kelompok yang tidak tumpang tindih (misal: Basic, Pro, Enterprise) dan mencakup semua user (tidak ada user tanpa status). Ini memungkinkan analisis total probabilitas dengan menjumlahkan perilaku tiap segmen secara terpisah.

=== #strong[B. Pertanyaan Aplikatif]
<b.-pertanyaan-aplikatif-1>
#strong[\6. Soal:] Sebuah aplikasi mendeteksi user menggunakan sistem operasi Android (A) atau iOS (I). Jika 60% menggunakan A, 30% menggunakan I, dan 10% menggunakan sistem lain, apakah A dan I saling lepas?

\* #strong[Solusi:] Ya, dalam konteks satu #emph[device] tertentu pada satu waktu, sebuah device tidak bisa berstatus Android dan iOS sekaligus. Secara himpunan $A sect I = nothing$, sehingga mereka saling lepas.

#strong[\7. Soal:] Dalam sistem keamanan, sensor A memiliki probabilitas deteksi 0,8 dan sensor B 0,7. Jika probabilitas keduanya mendeteksi adalah 0,6, hitung probabilitas setidaknya satu sensor bekerja.

\* #strong[Solusi:] Gunakan Inklusi-Eksklusi: $P \( A union B \) = P \( A \) + P \( B \) - P \( A sect B \)$ $P \( A union B \) = 0 \, 8 + 0 \, 7 - 0 \, 6 = 0 \, 9$.

#strong[\8. Soal:] Analisis probabilitas kegagalan sistem redundan di mana komponen A dan B harus mati secara bersamaan agar sistem lumpuh.

\* #strong[Solusi:] Ini adalah logika irisan ($A sect B$). Karena sistem redundan (paralel), kejadian sistem mati adalah irisan dari matinya komponen-komponen penyusunnya. Probabilitasnya jauh lebih kecil daripada komponen tunggal.

#strong[\9. Soal:] Jika sebuah perusahaan memiliki dua ISP (Indosat dan Telkom), gambarkan ruang sampel status koneksi internet perusahaan tersebut.

\* #strong[Solusi:] Ruang sampel terdiri dari kombinasi status kedua ISP (Misal 1=Up, 0=Down): $Omega = { \( I n d o s a t = 1 \, T e l k o m = 1 \) \, \( 1 \, 0 \) \, \( 0 \, 1 \) \, \( 0 \, 0 \) }$. Kejadian "Internet Mati Total" hanya terjadi pada outcome $\( 0 \, 0 \)$.

#strong[\10. Soal:] Sebuah database mencatat user yang aktif (A) dan user yang membayar (B). Deskripsikan dalam bahasa himpunan kejadian "user aktif yang tidak membayar".

\* #strong[Solusi:] User aktif ($A$) #strong[DAN] User tidak membayar ($B^c$). Notasi himpunan: $A sect B^c$ (atau $A - B$).

=== #strong[C. Pertanyaan Komputasional]
<c.-pertanyaan-komputasional-1>
#strong[\11. Soal:] Implementasikan fungsi Python untuk menghitung probabilitas gabungan dari dua kejadian menggunakan input $P \( A \)$, $P \( B \)$, dan $P \( A sect B \)$.

\* #strong[Solusi:]

#block[
#Skylighting(([#KeywordTok("def");#NormalTok(" prob_union(p_a, p_b, p_intersection): ");],
[#NormalTok("  ");#ControlFlowTok("return");#NormalTok(" p_a ");#OperatorTok("+");#NormalTok(" p_b ");#OperatorTok("-");#NormalTok(" p_intersection");],
[#NormalTok("   ");],
[#CommentTok("# Contoh");],
[#BuiltInTok("print");#NormalTok("(prob_union(");#FloatTok("0.8");#NormalTok(", ");#FloatTok("0.7");#NormalTok(", ");#FloatTok("0.6");#NormalTok(")) ");#CommentTok("# Output: 0.9");],));
#block[
#Skylighting(([#NormalTok("0.9");],));
]
]
#strong[\12. Soal:] Gunakan tipe data #NormalTok("set"); di Python untuk mensimulasikan operasi irisan dan gabungan pada 1.000 data sampel identitas user.

\* #strong[Solusi:]

#block[
#Skylighting(([#CommentTok("# Misal user_id 1-500 grup A, 300-800 grup B ");],
[#NormalTok("Group_A ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("(");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#DecValTok("501");#NormalTok(")) ");],
[#NormalTok("Group_B ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("(");#BuiltInTok("range");#NormalTok("(");#DecValTok("300");#NormalTok(", ");#DecValTok("801");#NormalTok("))");],
[#NormalTok("         ");],
[#NormalTok("Intersection ");#OperatorTok("=");#NormalTok(" Group_A ");#OperatorTok("&");#NormalTok(" Group_B ");#CommentTok("# Irisan");],
[#NormalTok("Union ");#OperatorTok("=");#NormalTok(" Group_A ");#OperatorTok("|");#NormalTok(" Group_B ");#CommentTok("# Gabungan");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Jumlah Irisan: ");#SpecialCharTok("{");#BuiltInTok("len");#NormalTok("(Intersection)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(") ");#CommentTok("# 201 user (300-500)");],));
#block[
#Skylighting(([#NormalTok("Jumlah Irisan: 201");],));
]
]
#strong[\13. Soal:] Buat program yang memverifikasi hukum De Morgan secara empiris melalui simulasi acak. \* #strong[Solusi:]

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" random ");],
[#NormalTok("Omega ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("(");#BuiltInTok("range");#NormalTok("(");#DecValTok("100");#NormalTok(")) ");#CommentTok("# Semesta 0-99 ");],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("(random.sample(");#BuiltInTok("list");#NormalTok("(Omega), ");#DecValTok("40");#NormalTok(")) ");],
[#NormalTok("B ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("(random.sample(");#BuiltInTok("list");#NormalTok("(Omega), ");#DecValTok("50");#NormalTok("))");],
[#NormalTok("         ");],
[#CommentTok("# Hukum 1: (A U B)^c = A^c n B^c");],
[#NormalTok("LHS ");#OperatorTok("=");#NormalTok(" Omega ");#OperatorTok("-");#NormalTok(" (A ");#OperatorTok("|");#NormalTok(" B)");],
[#NormalTok("RHS ");#OperatorTok("=");#NormalTok(" (Omega ");#OperatorTok("-");#NormalTok(" A) ");#OperatorTok("&");#NormalTok(" (Omega ");#OperatorTok("-");#NormalTok(" B)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"De Morgan Valid? ");#SpecialCharTok("{");#NormalTok("LHS ");#OperatorTok("==");#NormalTok(" RHS");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("De Morgan Valid? True");],));
]
]
#strong[\14. Soal:] Tulis skrip untuk menghitung probabilitas komplemen dari sekumpulan kejadian yang diberikan dalam bentuk list.

\* #strong[Solusi:]

#block[
#Skylighting(([#NormalTok("events_prob ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.05");#NormalTok("] ");#CommentTok("# P(E1), P(E2)... diasumsikan disjoint     ");],
[#NormalTok("prob_union ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(events_prob)     ");],
[#NormalTok("prob_complement ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" prob_union     ");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Probabilitas Komplemen (None of the above): ");#SpecialCharTok("{");#NormalTok("prob_complement");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Probabilitas Komplemen (None of the above): 0.6499999999999999");],));
]
]
#strong[\15. Soal:] Visualisasikan diagram Venn untuk dua kejadian menggunakan pustaka #NormalTok("matplotlib-venn");.

\* #strong[Solusi:]

#Skylighting(([#ImportTok("from");#NormalTok(" matplotlib_venn ");#ImportTok("import");#NormalTok(" venn2 ");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#NormalTok("         ");],
[#CommentTok("# Subset sizes: (Ab, aB, AB) -> (A only, B only, Intersection)");],
[#CommentTok("# Jika P(A)=0.8, P(B)=0.7, Irisan=0.6:");],
[#CommentTok("# A only = 0.2, B only = 0.1, Irisan = 0.6");],
[#NormalTok("venn2(subsets ");#OperatorTok("=");#NormalTok(" (");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.6");#NormalTok("), set_labels ");#OperatorTok("=");#NormalTok(" (");#StringTok("'Sensor A'");#NormalTok(", ");#StringTok("'Sensor B'");#NormalTok("))");],
[#NormalTok("plt.show()");],));
#box(image("ch/02-Kerangka_Probabilitas_dan_Statistik_files/figure-typst/cell-7-output-1.svg"))

= Minggu 03: Studi Kasus Aplikasi Teknik
<minggu-03-studi-kasus-aplikasi-teknik>
Probabilistic Framework in Engineering Application (Data Center, Generator Backup, Reliability)

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image3.png"))
], caption: figure.caption(
position: bottom, 
[
“Data center mati 3 menit bisa rugi besar. Kamu punya 2 generator---pasang seri atau paralel? Ini bukan selera desain; ini soal peluang gagal total. Kalau seri, satu komponen drop---habis. Kalau paralel, sistem masih hidup selama ada satu yang bertahan. Hari ini probabilitas berubah jadi ‘bahasa keputusan engineering': kita hitung peluang kegagalan sistem dan memilih arsitektur yang paling masuk akal. Ending-nya bukan rumus---ending-nya rekomendasi desain.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan>
Keandalan sistem (reliability), sistem seri vs paralel. Dalam sistem paralel, sistem bekerja jika setidaknya satu komponen bekerja, sedangkan seri membutuhkan semua komponen bekerja.

== 2. Tipikal Problem
<tipikal-problem>
Sebuah pusat data memiliki dua generator listrik. Apakah lebih baik menyusunnya secara seri atau paralel untuk menjamin ketersediaan daya?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan>
Menghitung probabilitas kegagalan sistem. Pada desain paralel, peluang kegagalan total adalah hasil kali peluang kegagalan masing-masing unit (yang jauh lebih kecil). Keputusan optimalnya adalah menggunakan konfigurasi paralel untuk meningkatkan reliabilitas sistem secara drastis.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-2>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 03!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 03!");],));
]
]
Week 03: Reliabilitas Infrastruktur IT (Teori & Simulasi SRE)

== Agenda Perkuliahan Minggu 3
<agenda-perkuliahan-minggu-3>
#strong[Topik:] Studi Kasus Infrastruktur - Reliabilitas dan Resiliensi #strong[Tema Misi:] "Architecting for Failure: How to Build Systems That (Almost) Never Die"

=== Pertemuan 1: Senin (1 Jam) -- The Intuition & The Trap
<pertemuan-1-senin-1-jam-the-intuition-the-trap>
#strong[Fokus:] Memahami kerapuhan sistem seri dan kekuatan redundansi (paralel) melalui simulasi visual.

- #strong[00:00 -- 00:10 | The Hook: "The 500-Error Nightmare"]
  - Aktivitas: Tampilkan diagram arsitektur microservices sederhana (Login $arrow.r$ Database $arrow.r$ Payment).
  - Pertanyaan: "Jika setiap layanan punya peluang sukses 99% (sangat tinggi), berapa peluang user berhasil bayar? Apakah 99%?"
  - Intuisi: Tidak. $0.99 times 0.99 times 0.99 approx 97$. Semakin kompleks sistem seri, semakin rapuh ia.
- #strong[00:10 -- 00:30 | Live Coding: "Chain of Doom vs.~The Hydra"]
  - Dosen (Python Demo):
    + Skenario 1 (Seri): Simulasikan 10 komponen berurutan. Jika satu False, semua mati. Tunjukkan betapa seringnya sistem ini down.
    + Skenario 2 (Paralel/Hydra): Simulasikan 3 server redundan. Sistem mati hanya jika ketiganya False.
  - Visualisasi: Plot grafik batang sederhana: Peluang gagal Seri vs Paralel.
- #strong[00:30 -- 00:50 | Konsep: Matematika Reliabilitas]
  - Formalkan intuisi tadi ke rumus:
    - Seri (AND logic): $R_(s y s) = product R_i$ (Reliabilitas turun drastis).
    - Paralel (OR logic): $R_(s y s) = 1 - product \( 1 - R_i \)$ (Reliabilitas naik drastis).
  - Perkenalkan konsep "Five Nines" (99.999%) sebagai "Holy Grail" anak IT.
- #strong[00:50 -- 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "Design the Unbreakable Cloud". Mahasiswa harus merancang arsitektur server dengan budget terbatas untuk mencapai uptime tertinggi.

=== Pertemuan 2: Rabu (2 Jam) -- Engineering Lab
<pertemuan-2-rabu-2-jam-engineering-lab>
#strong[Fokus:] Menggunakan Python untuk optimasi desain sistem dan memahami risiko tersembunyi.

- #strong[00:00 -- 00:15 | Intro: The Hidden Killer (Common Cause Failure)]
  - Diskusi: "Kalian punya 3 server paralel. Aman? Bagaimana jika ketiga server itu ada di satu gedung yang sama dan listrik gedung mati?"
  - Konsep: Independence Assumption itu berbahaya. Perkenalkan variabel pengganggu (Common Cause).
- #strong[00:15 -- 01:00 | Pod Challenge: "Budget vs.~Reliability"]
  - Skenario: Anda punya budget \$1000.
    - Server Murah: \$200, Reliabilitas 90%.
    - Server Mahal: \$500, Reliabilitas 99%.
  - Tugas (Python):
    + Bandingkan opsi: Beli 2 Server Mahal (Paralel) vs 5 Server Murah (Paralel).
    + Mana yang memberikan $R_(t o t a l)$ lebih tinggi?
    + Simulasikan kejadian "Power Outage" yang membunuh semua server sekaligus dengan peluang 1%. Hitung reliabilitas real-world baru.
- #strong[01:00 -- 01:30 | Deep Dive: m-out-of-n Systems]
  - Kasus: RAID 5 atau Voting System (Consensus). Sistem butuh minimal 2 dari 3 server menyala agar valid.
  - Gunakan #NormalTok("scipy.stats.binom"); untuk menghitung peluangnya.
- #strong[01:30 -- 01:50 | Design Review]
  - Pods mempresentasikan pilihan arsitektur mereka. Debat: "Apakah worth it bayar mahal untuk naik dari 99.9% ke 99.99%?"
- #strong[01:50 -- 02:00 | Exit Ticket]
  - Pertanyaan: "Sebutkan satu contoh sistem Single Point of Failure di kehidupan kampusmu."

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-2>
=== 1. Konsep Dasar
<konsep-dasar-1>
- #strong[Reliabilitas (R):] Probabilitas sebuah komponen/sistem berfungsi dalam periode waktu tertentu. $R = 1 - P \( upright("fail") \)$.
- #strong[Sistem Seri (Rantai Rapuh):] Komponen tersusun berurutan. Kegagalan satu komponen = Kegagalan sistem.
  - Rumus: $R_(s e r i) = R_1 times R_2 times dots.h times R_n$.
- #strong[Sistem Paralel (Redundansi):] Komponen tersusun berdampingan. Sistem gagal hanya jika semua komponen gagal.
  - Rumus: $R_(p a r a l e l) = 1 - \[ \( 1 - R_1 \) times \( 1 - R_2 \) dots.h \]$.
- #strong[Sistem k-out-of-n:] Sistem berfungsi jika minimal k dari n komponen berfungsi (Contoh: Mayoritas voting pada blockchain).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-1>
- #strong[High Availability (HA):] Load Balancer membagi trafik ke beberapa server aplikasi (Paralel). Jika satu server crash, yang lain mengambil alih.
- #strong[ML Pipeline (Seri):] Ingestion $arrow.r$ Cleaning $arrow.r$ Training $arrow.r$ Deployment. Jika Ingestion gagal, model tidak bisa dilatih. Ini adalah sistem seri yang kritis.
- #strong[Disaster Recovery (DR):] Memiliki Secondary Data Center. Ini adalah paralel tingkat tinggi. Namun hati-hati dengan Common Cause Failure (misal: AWS Region US-East-1 down total).

=== 3. Komputasi (Python)
<komputasi-python-1>
- #strong[Fungsi Kustom:] Membuat fungsi #NormalTok("reliability_series(probs)"); dan #NormalTok("reliability_parallel(probs)"); menggunakan #NormalTok("numpy.prod");.
- #strong[Simulasi Monte Carlo:] Menggunakan #NormalTok("random.random()"); untuk mensimulasikan status hidup/mati ribuan server dan menghitung persentase uptime sistem gabungan.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-2>
#strong[Judul:] Week 3: The SRE Challenge - Designing High Availability Systems

#strong[Deskripsi:] Mahasiswa berperan sebagai Site Reliability Engineer (SRE). Diberikan topologi sistem yang kompleks (gabungan seri dan paralel), mahasiswa harus menghitung reliabilitas teoretis dan memvalidasinya dengan simulasi Python.

#strong[Soal Python (Notebook):]

+ 1. #strong[Modeling (30 poin):] Representasikan sistem berikut dalam fungsi Python:

  + - Sub-sistem A: 3 Web Server (Paralel, #cite(<R>, form: "prose")=0.9).

  + - Sub-sistem B: 1 Database Utama (R=0.99).

  + - Sistem Total: Sub-sistem A terhubung Seri dengan Sub-sistem B.

+ 2. #strong[Calculation (30 poin):] Hitung reliabilitas teoretis sistem total.

+ 3. #strong[Simulation (20 poin):] Jalankan simulasi 10.000 kali.

  + - Generate status acak untuk tiap komponen.

  + - Cek logika: #NormalTok("(Web1 OR Web2 OR Web3) AND Database");.

  + - Hitung frekuensi sukses empiris.

+ 4. #strong[Analysis (20 poin):] Jika budget memungkinkan penambahan 1 komponen (Web Server lagi ATAU Database Backup), mana yang paling signifikan menaikkan reliabilitas total? Buktikan dengan angka.

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-1>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-2>
+ #strong[Soal:] Mengapa sistem seri dianggap memiliki resiliensi yang lebih rendah dibandingkan sistem tunggal dengan komponen yang sama?
  - #strong[Solusi:] Karena dalam sistem seri, reliabilitas total adalah hasil perkalian reliabilitas komponen ($R_(t o t a l) = product R_i$). Karena $R_i lt.eq 1$, hasil perkalian akan selalu lebih kecil dari nilai komponen terendah. Menambah komponen seri justru menambah titik kegagalan (Point of Failure).
+ #strong[Soal:] Jelaskan bagaimana redundansi paralel meningkatkan reliabilitas total sebuah sistem informasi.
  - #strong[Solusi:] Redundansi paralel menciptakan jalur alternatif. Sistem hanya gagal jika semua jalur gagal bersamaan. Secara matematis, peluang kegagalan total ($F_(t o t a l)$) adalah hasil kali peluang kegagalan komponen ($F_i$). Karena $F_i$ kecil (misal 0.1), mengalikannya akan menghasilkan angka yang sangat kecil (0.01), sehingga Reliabilitas ($1 - F_(t o t a l)$) meningkat drastis.
+ #strong[Soal:] Apa yang dimaksud dengan ketersediaan (availability) "lima sembilan" (99,999%) dan mengapa sulit dicapai?
  - #strong[Solusi:] "Lima sembilan" berarti sistem harus beroperasi 99,999% dari waktu, yang setara dengan downtime hanya sekitar 5,26 menit per tahun. Ini sulit dicapai karena memerlukan redundansi berlapis (hardware, power, network, geographic) dan eliminasi single point of failure sepenuhnya, serta mitigasi terhadap common cause failures.
+ #strong[Soal:] Bagaimana ketergantungan antar komponen (asumsi ketidakindependenan) mempengaruhi perhitungan reliabilitas?
  - #strong[Solusi:] Rumus standar paralel ($1 - product F_i$) mengasumsikan kegagalan komponen bersifat independen. Jika ada ketergantungan (korelasi positif, misal satu rak server panas menyebabkan server lain ikut panas), probabilitas kegagalan bersama akan jauh lebih tinggi daripada hasil perkalian independen. Ini menyebabkan reliabilitas aktual lebih rendah dari perhitungan teoretis.
+ #strong[Soal:] Deskripsikan perbedaan antara kegagalan aktif dan kegagalan laten dalam sistem infrastruktur.
  - #strong[Solusi:]
    - #strong[Kegagalan Aktif:] Kerusakan yang langsung terlihat dan berdampak (misal: server meledak, kabel putus).
    - #strong[Kegagalan Laten:] Kerusakan yang sudah ada tapi belum memicu error sampai kondisi tertentu terpenuhi (misal: bug pada kode backup yang baru ketahuan saat backup benar-benar dibutuhkan/dijalankan).

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-2>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah jalur internet backbone terdiri dari 3 router yang disusun seri. Jika masing-masing memiliki reliabilitas 0,95, hitung reliabilitas total jalur tersebut.
  - #strong[Solusi:] $R_(t o t a l) = 0 \, 95 times 0 \, 95 times 0 \, 95 = 0 \, 857$ (atau 85,7%).
+ #strong[Soal:] Analisis ketersediaan sistem cloud yang memiliki 4 server paralel di mana sistem tetap berjalan jika minimal 1 server aktif. (Asumsi R tiap server tidak disebut, kita asumsikan R=0.9 untuk contoh, atau F=0.1).
  - #strong[Solusi:] Sistem gagal hanya jika ke-4 server mati. $P \( upright("SystemDown") \) = F^4$. $R_(s y s t e m) = 1 - F^4$.
+ #strong[Soal:] Dalam desain Disaster Recovery Center (DRC), jika link utama memiliki uptime 99% dan link cadangan 98%, hitung probabilitas total sistem terhubung.
  - #strong[Solusi:] (Asumsi paralel/redundant). $P \( upright("MainFail") \) = 1 - 0.99 = 0.01$. $P \( upright("BackupFail") \) = 1 - 0.98 = 0.02$. $P \( upright("TotalFail") \) = 0.01 times 0.02 = 0.0002$. $R_(t o t a l) = 1 - 0.0002 = 0.9998$ (99,98%).
+ #strong[Soal:] Sebuah gedung data center menggunakan 3 generator cadangan. Jika probabilitas satu generator gagal menyala adalah 0,02, berapa probabilitas setidaknya satu menyala saat listrik padam?
  - #strong[Solusi:] Peluang semua gagal = $0.02^3 = 0.000008$. Peluang setidaknya satu menyala = $1 - 0.000008 = 0.999992$.
+ #strong[Soal:] Evaluasi reliabilitas sistem transmisi data di mana satu file dibagi menjadi 5 paket dan sistem gagal jika salah satu paket hilang.
  - #strong[Solusi:] Ini adalah analogi sistem Seri. Jika $R_(p a k e t)$ adalah reliabilitas pengiriman satu paket, maka reliabilitas pengiriman file adalah $\( R_(p a k e t) \)^5$. Risiko kegagalan meningkat seiring bertambahnya jumlah pecahan paket.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-2>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Buat fungsi Python untuk menghitung reliabilitas sistem seri dengan input berupa list reliabilitas komponen.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#KeywordTok("def");#NormalTok(" reliability_series(probs):  ");],
  [#ControlFlowTok("return");#NormalTok(" np.prod(probs)  ");],
  [#CommentTok("# Contoh: reliability_series([0.9, 0.9, 0.9]) -> 0.729  ");],));

+ #strong[Soal:] Implementasikan simulasi untuk membandingkan reliabilitas sistem seri vs paralel dengan jumlah komponen n dari 1 sampai 10.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#NormalTok("n_range ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#DecValTok("11");#NormalTok(")  ");],
  [#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.9");#NormalTok("  ");],
  [#NormalTok("r_series ");#OperatorTok("=");#NormalTok(" [p");#OperatorTok("**");#NormalTok("n ");#ControlFlowTok("for");#NormalTok(" n ");#KeywordTok("in");#NormalTok(" n_range]  ");],
  [#NormalTok("r_parallel ");#OperatorTok("=");#NormalTok(" [");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" (");#DecValTok("1");#OperatorTok("-");#NormalTok("p)");#OperatorTok("**");#NormalTok("n ");#ControlFlowTok("for");#NormalTok(" n ");#KeywordTok("in");#NormalTok(" n_range]  ");],
  [#NormalTok("plt.plot(n_range, r_series, label");#OperatorTok("=");#StringTok("'Seri'");#NormalTok(")  ");],
  [#NormalTok("plt.plot(n_range, r_parallel, label");#OperatorTok("=");#StringTok("'Paralel'");#NormalTok(")  ");],
  [#NormalTok("plt.legend()");#OperatorTok(";");#NormalTok(" plt.show()  ");],));

+ #strong[Soal:] Tulis skrip untuk menghitung jumlah minimum komponen paralel yang dibutuhkan agar reliabilitas total mencapai 0,999.

  - #strong[Solusi:]

  #Skylighting(([#NormalTok("p_component ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.9");#NormalTok("  ");],
  [#NormalTok("target ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.999");#NormalTok("  ");],
  [#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#ControlFlowTok("while");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p_component)");#OperatorTok("**");#NormalTok("n) ");#OperatorTok("<");#NormalTok(" target:  ");],
  [#NormalTok("n ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Butuh ");#SpecialCharTok("{");#NormalTok("n");#SpecialCharTok("}");#SpecialStringTok(" komponen.\"");#NormalTok(")  ");],));

+ #strong[Soal:] Gunakan matplotlib untuk memplot grafik hubungan antara jumlah komponen paralel dan reliabilitas sistem.

  - #strong[Solusi:] (Lihat solusi no 12, fokus pada garis Paralel yang melengkung asimtotik mendekati 1).

+ #strong[Soal:] Simulasikan kegagalan komponen secara acak dalam 10.000 iterasi untuk mengestimasi Mean Time To Failure (MTTF) sistem sederhana.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#CommentTok("# Asumsi: Probabilitas gagal per jam = 0.01  ");],
  [#NormalTok("trials ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10000");#NormalTok("  ");],
  [#NormalTok("failure_times ");#OperatorTok("=");#NormalTok(" []  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):  ");],
  [#NormalTok("time ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok("  ");],
  [#ControlFlowTok("while");#NormalTok(" np.random.rand() ");#OperatorTok(">");#NormalTok(" ");#FloatTok("0.01");#NormalTok(": ");#CommentTok("# Selama belum gagal  ");],
  [#NormalTok("    time ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#NormalTok("failure_times.append(time)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Estimasi MTTF: ");#SpecialCharTok("{");#NormalTok("np");#SpecialCharTok(".");#NormalTok("mean(failure_times)");#SpecialCharTok("}");#SpecialStringTok(" jam\"");#NormalTok(")  ");],));
]

= Minggu 04: Teorema Probabilitas dan Bayes
<minggu-04-teorema-probabilitas-dan-bayes>
Probability Theorems, Conditional Probability, Bayes Theorem

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image4.png"))
], caption: figure.caption(
position: bottom, 
[
“Alarm akurat 90%. Alarm bunyi. Semua panik: ‘mesin rusak!' Tapi… kalau kerusakan itu sangat jarang, alarm 90% bisa tetap sering bohong. Ini plot twist klasik: base rate. Bayes itu alat untuk ‘update keyakinan' berdasarkan bukti, bukan berdasarkan panik. Hari ini kamu belajar beda ‘P(alarm | rusak)' dan ‘P(rusak | alarm)'. Satu membuatmu terlihat pintar, satu menyelamatkan biaya shutdown.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-1>
Probabilitas bersyarat P(A|B), aturan perkalian, independensi, dan Teorema Bayes untuk memperbarui keyakinan berdasarkan bukti baru.

== 2. Tipikal Problem
<tipikal-problem-1>
Sebuah sistem pemantauan mendeteksi kerusakan mesin (alarm berbunyi). Diketahui akurasi alarm 90%, tetapi peluang mesin rusak sebenarnya sangat kecil (jarang terjadi). Apakah mesin benar-benar rusak jika alarm berbunyi?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-1>
Menggunakan Teorema Bayes untuk menghitung Posterior Probability P(Rusak|Alarm). Seringkali hasilnya menunjukkan peluang kerusakan masih rendah (false alarm). Solusinya adalah melakukan verifikasi manual sebelum menghentikan produksi yang mahal.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-3>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 04!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 04!");],));
]
]
Week 04: Teorema Bayes dan Probabilitas Kondisional

== Agenda Perkuliahan Minggu 4
<agenda-perkuliahan-minggu-4>
#strong[Tema Misi:] "Sherlock Holmes 2.0: The Art of Updating Beliefs"

=== Pertemuan 1: Senin (1 Jam) - The Intuition & The Paradox
<pertemuan-1-senin-1-jam---the-intuition-the-paradox>
#strong[Fokus:] Membongkar intuisi yang salah tentang "akurasi" dan memperkenalkan cara berpikir Bayesian.

- #strong[00:00 - 00:10 | The Hook: "Jebakan Tes DNA/Wajah"]
  - Aktivitas: Tampilkan skenario FaceID/Biometrik. "Jika sistem keamanan punya akurasi 99%, dan alarm berbunyi mendeteksi teroris, berapa persen kemungkinan orang itu benar-benar teroris?"
  - Tebakan Mahasiswa: Kebanyakan akan menjawab 99%.
  - Realita: Tunjukkan bahwa jika teroris sangat langka (misal 1 dari 10.000), peluangnya mungkin di bawah 1%. Ini adalah #emph[Base-Rate Fallacy].
- #strong[00:10 - 00:30 | Live Coding: "Simulation over Formula"]
  - Dosen (Python Demo):
    + Buat populasi 10.000 orang (9.999 User, 1 Hacker).
    + Simulasikan alat deteksi dengan False Positive Rate 1%.
    + Hitung berapa kali alarm berbunyi vs berapa kali Hacker tertangkap.
    + Visual: Tampilkan diagram titik (#emph[Population Matrix]).
- #strong[00:30 - 00:50 | Konsep: Teorema Bayes]
  - Perkenalkan rumus bukan sebagai hafalan, tapi sebagai mekanisme update:
    - #strong[Prior:] Keyakinan awal (seberapa sering hacker muncul?).
    - #strong[Likelihood:] Seberapa jago alat deteksinya?
    - #strong[Posterior:] Keyakinan baru setelah alarm bunyi.
  - Bahas perbedaan vital: Independen vs Saling Lepas (Mutually Exclusive).
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "Building a Naive Spam Filter". Mahasiswa akan membuat logika dasar filter email berbasis kata kunci.

=== Pertemuan 2: Rabu (2 Jam) - Logic & Code Lab
<pertemuan-2-rabu-2-jam---logic-code-lab>
#strong[Fokus:] Implementasi Python untuk inferensi probabilistik dan penanganan data tidak seimbang.

- #strong[00:00 - 00:20 | Deep Dive: Monty Hall Paradox]
  - Aktivitas: Simulasikan game show 3 pintu (Monty Hall) secara interaktif atau via kode Python.
  - Diskusi: Mengapa informasi tambahan (pintu dibuka) mengubah probabilitas? Ini inti dari probabilitas kondisional $P \( A \| B \)$.
- #strong[00:20 - 01:10 | Pod Challenge: "The Spam Assassin"]
  - Skenario: Diketahui 20% email adalah Spam. Kata "Gratis" muncul di 90% Spam, tapi juga muncul di 5% email Normal.
  - Tugas (Python):
    + Hitung manual: Jika ada kata "Gratis", berapa peluang itu Spam?
    + Coding: Buat fungsi #NormalTok("is_spam(word, prior, sensitivity, specificity)");.
    + Eksperimen: Apa yang terjadi jika prior spam turun jadi 1%? Apakah filter masih efektif atau terlalu banyak memblokir email penting (False Positive)?
- #strong[01:10 - 01:40 | Studi Kasus: Deteksi Intrusi & Anomali]
  - Bahas Aplikasi 3 dari laporan ML: Mengapa deteksi fraud/intrusi sangat sulit?
  - Solusi teknik: Menggabungkan beberapa sinyal independen (misal: IP Address + Jam Login) untuk menaikkan Likelihood.
- #strong[01:40 - 01:50 | Code Review & Debat]
  - "Kapan kita boleh mengabaikan Prior?" (Jawab: Hampir tidak pernah, kecuali datanya sangat kuat).
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Jelaskan dengan bahasamu sendiri, apa itu False Positive dan kenapa itu berbahaya bagi sistem pemadam kebakaran otomatis?"

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-3>
=== 1. Konsep Dasar
<konsep-dasar-2>
- #strong[Probabilitas Kondisional (]$P \( A \| B \)$): Peluang kejadian A terjadi mengingat kejadian B sudah terjadi. Ini menyempitkan ruang sampel dari $Omega$ menjadi B.
- #strong[Teorema Bayes:] Rumus untuk membalik probabilitas kondisional. $ P \( A \| B \) = frac(P \( B \| A \) dot.op P \( A \), P \( B \)) $ Di mana $P \( A \)$ adalah Prior (keyakinan awal) dan $P \( A \| B \)$ adalah Posterior (keyakinan setelah melihat bukti).
- #strong[Hukum Probabilitas Total:] Digunakan untuk menghitung penyebut ($P \( B \)$) dengan memecah masalah menjadi partisi-partisi yang saling lepas.

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-2>
- #strong[Filter Spam (Naive Bayes):] Mengklasifikasikan email berdasarkan kemunculan kata. Disebut "Naive" karena mengasumsikan kemunculan kata bersifat independen satu sama lain untuk menyederhanakan hitungan.
- #strong[Deteksi Fraud/Intrusi:] Tantangan utamanya adalah #emph[Base-Rate Fallacy]. Karena transaksi fraud sangat jarang (misal 0.1%), sistem dengan akurasi 99% pun akan menghasilkan lebih banyak False Alarm daripada deteksi yang benar.
- #strong[Diagnosa Medis/Sistem:] Memprediksi kerusakan server berdasarkan gejala (suhu panas, latency tinggi) menggunakan data historis korelasi.

=== 3. Komputasi (Python)
<komputasi-python-2>
- #strong[Fungsi Bayes:] Membuat fungsi reusable untuk menghitung posterior.
- #strong[Matriks Konfusi:] Menggunakan pandas atau #NormalTok("sklearn.metrics.confusion_matrix"); untuk memvisualisasikan True Positive, False Positive, dll.
- #strong[Simulasi Monte Carlo:] Membuktikan paradoks probabilitas (seperti Monty Hall) dengan menjalankan ribuan iterasi #NormalTok("random.choice");.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-3>
#strong[Judul:] Week 4: The Bayesian Security Analyst

#strong[Deskripsi:] Mahasiswa diberikan dataset simulasi trafik jaringan (Normal vs Serangan DDoS). Mereka harus membuat detektor sederhana dan mengevaluasi kinerjanya.

#strong[Soal Python (Notebook):]

+ 1. #strong[Analisis Manual:] Diketahui $P \( upright("DDoS") \) = 0.01$. Sebuah sistem deteksi trafik aneh memiliki True Positive Rate 95% dan False Positive Rate 5%. Hitung peluang adanya serangan DDoS sungguhan jika alarm berbunyi.

+ 2. #strong[Bayes Function:] Implementasikan fungsi #NormalTok("bayes_update(prior, sensitivity, specificity)"); di Python. Gunakan untuk memverifikasi jawaban nomor 1.

+ 3. #strong[Simulation:] Generate 10.000 request (gunakan #NormalTok("numpy.random");). Simulasikan alarm berdasarkan probabilitas di atas. Hitung Precision (Berapa % alarm yang benar).

+ 4. #strong[Decision Making:] Jika biaya memblokir user asli (False Positive) adalah \$10 dan biaya membiarkan DDoS lolos (False Negative) adalah \$1000, apakah sistem deteksi ini layak dipakai? Jelaskan dengan perhitungan Expected Loss.

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-2>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-3>
+ #strong[Soal:] Apa intuisi di balik probabilitas kondisional $P \( A \| B \)$? Bagaimana informasi B mempersempit ruang sampel awal?
  - #strong[Solusi:] Probabilitas kondisional merefleksikan pembaruan informasi. Intuisinya adalah kita "membuang" semua hasil di ruang sampel $Omega$ yang tidak memuat B. Ruang sampel yang relevan kini hanya B, sehingga peluang A dihitung sebagai proporsi irisan $A sect B$ terhadap luas total B ($P \( A sect B \) \/ P \( B \)$).
+ #strong[Soal:] Jelaskan perbedaan antara prior probability, likelihood, dan posterior probability dalam kerangka Bayes.
  - #strong[Solusi:]
    - #strong[Prior (]$P \( A \)$): Keyakinan awal sebelum melihat data/bukti.
    - #strong[Likelihood (]$P \( B \| A \)$): Peluang bukti muncul jika hipotesis kita benar.
    - #strong[Posterior (]$P \( A \| B \)$): Keyakinan yang diperbarui setelah melihat bukti.
+ #strong[Soal:] Apa yang dimaksud dengan independensi statistik dan mengapa itu berbeda dengan kejadian saling lepas?
  - #strong[Solusi:] Dua kejadian independen berarti terjadinya satu tidak mengubah peluang terjadinya yang lain ($P \( A \| B \) = P \( A \)$). Kejadian saling lepas berarti keduanya tidak bisa terjadi bersamaan ($A sect B = nothing$). Justru, jika saling lepas, mereka sangat bergantung (jika A terjadi, B pasti tidak terjadi).
+ #strong[Soal:] Bagaimana Hukum Probabilitas Total digunakan sebagai penyebut dalam rumus Bayes?
  - #strong[Solusi:] Penyebut rumus Bayes ($P \( B \)$) seringkali sulit dihitung langsung. Hukum Probabilitas Total memecahnya menjadi jumlahan dari semua skenario yang mungkin: $P \( B \) = sum P \( B \| A_i \) P \( A_i \)$. Ini menormalisasi probabilitas posterior agar totalnya menjadi 1.
+ #strong[Soal:] Mengapa "False Positive" menjadi masalah krusial dalam sistem peringatan dini seperti prediksi gempa atau deteksi virus?
  - #strong[Solusi:] Karena Base Rate (frekuensi kejadian asli) gempa/virus biasanya sangat rendah. Meskipun alat deteksi akurat, secara statistik jumlah alarm palsu (dari populasi sehat/normal yang besar) akan jauh melebihi jumlah alarm benar, menyebabkan kepanikan atau biaya evakuasi yang sia-sia ("Boy Who Cried Wolf").

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-3>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah filter spam mengetahui bahwa 20% email adalah spam. 90% spam mengandung kata "Promo", sementara hanya 5% email normal mengandung kata tersebut. Jika sebuah email mengandung kata "Promo", hitung probabilitas itu adalah spam.
  - #strong[Solusi:]
    - $P \( S \) = 0.2$, $P \( N \) = 0.8$.
    - $P \( upright("Promo") \| S \) = 0.9$, $P \( upright("Promo") \| N \) = 0.05$.
    - $P \( S \| upright("Promo") \) = frac(0.9 times 0.2, \( 0.9 times 0.2 \) + \( 0.05 times 0.8 \)) = frac(0.18, 0.18 + 0.04) = 0.18 / 0.22 approx 0.818$.
+ #strong[Soal:] Analisis probabilitas kegagalan server jika diketahui ada peringatan suhu tinggi, menggunakan data historis korelasi antara suhu dan kegagalan.
  - #strong[Solusi:] Gunakan Bayes. Kita butuh data: $P \( upright("Gagal") \)$, $P \( upright("Panas") \| upright("Gagal") \)$, dan $P \( upright("Panas") \| upright("Normal") \)$. Peringatan suhu tinggi akan meningkatkan probabilitas kegagalan dari baseline (prior), namun seberapa besar peningkatannya bergantung pada seberapa sering server panas tapi tidak gagal (False Positive).
+ #strong[Soal:] Dalam pengujian software, jika modul A memiliki bug, probabilitas modul B memiliki bug meningkat menjadi 0,6. Jika probabilitas awal modul B memiliki bug adalah 0,2, apakah A dan B independen?
  - #strong[Solusi:] Tidak Independen. Definisi independen adalah $P \( B \| A \) = P \( B \)$. Di sini, $P \( B \| A \) = 0.6$ sedangkan $P \( B \) = 0.2$. Karena peluang berubah dengan adanya informasi A, maka mereka dependen (berkorelasi).
+ #strong[Soal:] Gunakan Teorema Bayes untuk mengevaluasi akurasi sistem pengenalan wajah yang memiliki tingkat false match 0,01%.
  - #strong[Solusi:] Jika database berisi 1 juta orang dan 1 penjahat.
    - Jika orang random lewat, peluang match salah = 0,01% = 0,0001.
    - Dari 1.000.000 orang, akan ada $approx 100$ False Match.
    - Jika alarm bunyi, peluang benar penjahat hanya $1 \/ \( 1 + 100 \) approx 1 %$. Akurasi "teknis" tinggi (99.99%) tidak menjamin presisi praktis tinggi pada populasi besar.
+ #strong[Soal:] Analisis probabilitas seorang user adalah bot jika diketahui dia melakukan 100 request dalam 1 detik.
  - #strong[Solusi:] Ini adalah pembaruan Likelihood. $P \( 100 upright("req") \| upright("Manusia") \) approx 0$, sedangkan $P \( 100 upright("req") \| upright("Bot") \)$ tinggi. Dengan Bayes, meskipun Prior bot kecil, Likelihood yang sangat kontras ini akan membuat Posterior $P \( upright("Bot") \| upright("Data") \)$ mendekati 1 (Pasti Bot).
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-3>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Implementasikan fungsi Python #NormalTok("bayes_theorem(prior, likelihood, total_prob)"); yang mengembalikan nilai posterior.

  - #strong[Solusi:]

  #Skylighting(([#KeywordTok("def");#NormalTok(" bayes_theorem(prior, likelihood, neg_likelihood):  ");],
  [#CommentTok("# neg_likelihood adalah P(B|Not A)  ");],
  [#NormalTok("p_b ");#OperatorTok("=");#NormalTok(" (likelihood ");#OperatorTok("*");#NormalTok(" prior) ");#OperatorTok("+");#NormalTok(" (neg_likelihood ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" prior))  ");],
  [#ControlFlowTok("return");#NormalTok(" (likelihood ");#OperatorTok("*");#NormalTok(" prior) ");#OperatorTok("/");#NormalTok(" p_b  ");],));

+ #strong[Soal:] Buatlah skrip untuk mensimulasikan masalah Monty Hall dan buktikan secara empiris mengapa berpindah pintu memberikan probabilitas menang lebih tinggi.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" random  ");],
  [#NormalTok("wins_stay, wins_switch ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("10000");#NormalTok("):  ");],
  [#NormalTok("doors ");#OperatorTok("=");#NormalTok(" [");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok("] ");#CommentTok("# 1 is car  ");],
  [#NormalTok("random.shuffle(doors)  ");],
  [#NormalTok("choice ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#CommentTok("# Misal selalu pilih pintu 0  ");],
  [#CommentTok("# Host buka pintu zonk  ");],
  [#NormalTok("open_door ");#OperatorTok("=");#NormalTok(" [i ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" [");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("] ");#ControlFlowTok("if");#NormalTok(" doors[i] ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#KeywordTok("and");#NormalTok(" i ");#OperatorTok("!=");#NormalTok(" choice][");#DecValTok("0");#NormalTok("]  ");],
  [#CommentTok("# Switch ke pintu sisa  ");],
  [#NormalTok("switch ");#OperatorTok("=");#NormalTok(" [i ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" [");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("] ");#ControlFlowTok("if");#NormalTok(" i ");#OperatorTok("!=");#NormalTok(" choice ");#KeywordTok("and");#NormalTok(" i ");#OperatorTok("!=");#NormalTok(" open_door][");#DecValTok("0");#NormalTok("]  ");],
  [#ControlFlowTok("if");#NormalTok(" doors[choice] ");#OperatorTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok(": wins_stay ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#ControlFlowTok("if");#NormalTok(" doors[switch] ");#OperatorTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok(": wins_switch ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Stay: ");#SpecialCharTok("{");#NormalTok("wins_stay");#OperatorTok("/");#DecValTok("10000");#SpecialCharTok("}");#SpecialStringTok(", Switch: ");#SpecialCharTok("{");#NormalTok("wins_switch");#OperatorTok("/");#DecValTok("10000");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],
  [#CommentTok("# Hasil akan mendekati Stay: 0.33, Switch: 0.66  ");],));

+ #strong[Soal:] Gunakan pustaka numpy untuk menghitung matriks probabilitas transisi sederhana dalam sebuah rantai Markov.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#CommentTok("# Matriks transisi: Hujan(0), Cerah(1)  ");],
  [#CommentTok("# P(0|0)=0.7, P(1|0)=0.3  ");],
  [#CommentTok("# P(0|1)=0.4, P(1|1)=0.6  ");],
  [#NormalTok("T ");#OperatorTok("=");#NormalTok(" np.array([[");#FloatTok("0.7");#NormalTok(", ");#FloatTok("0.3");#NormalTok("], [");#FloatTok("0.4");#NormalTok(", ");#FloatTok("0.6");#NormalTok("]])  ");],
  [#NormalTok("current_state ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok("]) ");#CommentTok("# Hari ini Hujan  ");],
  [#NormalTok("next_day ");#OperatorTok("=");#NormalTok(" current_state.dot(T)  ");],
  [#BuiltInTok("print");#NormalTok("(next_day)  ");],));

+ #strong[Soal:] Tulis program yang mengklasifikasikan pesan singkat sebagai "Spam" atau "Ham" menggunakan algoritma Naive Bayes sederhana.

  - #strong[Solusi:]

  #Skylighting(([#CommentTok("# Sederhana: P(Spam|Word)  ");],
  [#NormalTok("p_spam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.5");#NormalTok("  ");],
  [#NormalTok("p_word_given_spam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.8");#NormalTok(" ");#CommentTok("# Likelihood  ");],
  [#NormalTok("p_word_given_ham ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.1");#NormalTok("  ");],
  [#KeywordTok("def");#NormalTok(" predict(word_present):  ");],
  [#ControlFlowTok("if");#NormalTok(" ");#KeywordTok("not");#NormalTok(" word_present: ");#ControlFlowTok("return");#NormalTok(" p_spam ");#CommentTok("# Simplifikasi  ");],
  [#NormalTok("evidence ");#OperatorTok("=");#NormalTok(" (p_word_given_spam ");#OperatorTok("*");#NormalTok(" p_spam) ");#OperatorTok("+");#NormalTok(" ");#OperatorTok("\\");],
  [#NormalTok("           (p_word_given_ham ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p_spam))  ");],
  [#ControlFlowTok("return");#NormalTok(" (p_word_given_spam ");#OperatorTok("*");#NormalTok(" p_spam) ");#OperatorTok("/");#NormalTok(" evidence  ");],));

+ #strong[Soal:] Visualisasikan bagaimana probabilitas posterior berubah seiring dengan bertambahnya jumlah bukti (evidence) dalam simulasi Python.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#NormalTok("priors ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.1");#NormalTok("] ");#CommentTok("# Keyakinan awal rendah  ");],
  [#NormalTok("likelihood_true ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.8");#NormalTok(" ");#CommentTok("# Bukti mendukung  ");],
  [#NormalTok("likelihood_false ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.4");#NormalTok("  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("10");#NormalTok("):  ");],
  [#NormalTok("curr ");#OperatorTok("=");#NormalTok(" priors[");#OperatorTok("-");#DecValTok("1");#NormalTok("]  ");],
  [#CommentTok("# Update rule: P(A|B)  ");],
  [#NormalTok("post ");#OperatorTok("=");#NormalTok(" (likelihood_true ");#OperatorTok("*");#NormalTok(" curr) ");#OperatorTok("/");#NormalTok(" ");#OperatorTok("\\");],
  [#NormalTok("       ((likelihood_true ");#OperatorTok("*");#NormalTok(" curr) ");#OperatorTok("+");#NormalTok(" (likelihood_false ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#OperatorTok("-");#NormalTok("curr)))  ");],
  [#NormalTok("priors.append(post)  ");],
  [#NormalTok("plt.plot(priors)");#OperatorTok(";");#NormalTok(" plt.title(");#StringTok("\"Bayesian Updating\"");#NormalTok(")");#OperatorTok(";");#NormalTok(" plt.show()  ");],));
]

= Minggu 05: Variabel Acak
<minggu-05-variabel-acak>
Random Variable Definition, Probability Function, Expectation, Variance

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image5.png"))
], caption: figure.caption(
position: bottom, 
[
“Kamu dikasih dua opsi investasi: A stabil, B bisa tinggi tapi bisa jeblok. Pertanyaannya: keputusan yang ‘dewasa' itu bukan cuma lihat rata-rata---tapi lihat risiko. Variabel acak itu cara kita memetakan dunia random jadi angka. Ekspektasi itu ‘rata-rata jangka panjang', variansi itu ‘seberapa liar'. Hari ini kamu mulai bicara seperti engineer: bukan ‘feeling', tapi ‘E dan Var'. Dan kamu akan bikin keputusan yang bisa dipertanggungjawabkan.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-2>
Pemetaan hasil eksperimen ke nilai numerik (variabel acak), Nilai Harapan (E\[X\]) sebagai rata-rata jangka panjang, dan Variansi sebagai ukuran sebaran.

== 2. Tipikal Problem
<tipikal-problem-2>
Seorang investor memiliki dua opsi investasi dengan profil risiko berbeda. Opsi A memberikan hasil pasti, Opsi B memberikan hasil tinggi tapi berisiko rugi.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-2>
Menghitung E\[X\] (expected return) dan Variansi (risiko) dari kedua opsi. Keputusan diambil dengan memilih E\[X\] tertinggi yang masih berada dalam toleransi risiko (variansi) investor tersebut.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-4>
== Konstruksi Random Variable Kontinu dari Hasil Pengamatan
<konstruksi-random-variable-kontinu-dari-hasil-pengamatan>
#block[
#Skylighting(([#CommentTok("\"\"\"");],
[#CommentTok("Created on Tue Mar 24 14:28:57 2026");],
[],
[#CommentTok("@author: Armein Z. R. Langi");],
[#CommentTok("\"\"\"");],
[],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#KeywordTok("class");#NormalTok(" ContinuousRV:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", cum_freq):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".x ");#OperatorTok("=");#NormalTok(" np.array(");#BuiltInTok("sorted");#NormalTok("(cum_freq.keys()), dtype");#OperatorTok("=");#BuiltInTok("float");#NormalTok(")");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".F ");#OperatorTok("=");#NormalTok(" np.array([cum_freq[k] ");#ControlFlowTok("for");#NormalTok(" k ");#KeywordTok("in");#NormalTok(" ");#VariableTok("self");#NormalTok(".x], dtype");#OperatorTok("=");#BuiltInTok("float");#NormalTok(")");],
[],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".F[");#OperatorTok("-");#DecValTok("1");#NormalTok("] ");#OperatorTok("!=");#NormalTok(" ");#FloatTok("1.0");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("raise");#NormalTok(" ");#PreprocessorTok("ValueError");#NormalTok("(");#StringTok("\"CDF terakhir harus 1\"");#NormalTok(")");],
[],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".pdf_grid ");#OperatorTok("=");#NormalTok(" np.gradient(");#VariableTok("self");#NormalTok(".F, ");#VariableTok("self");#NormalTok(".x)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" cdf(");#VariableTok("self");#NormalTok(", t):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" np.interp(t, ");#VariableTok("self");#NormalTok(".x, ");#VariableTok("self");#NormalTok(".F, left");#OperatorTok("=");#FloatTok("0.0");#NormalTok(", right");#OperatorTok("=");#FloatTok("1.0");#NormalTok(")");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" pdf(");#VariableTok("self");#NormalTok(", t):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" np.interp(t, ");#VariableTok("self");#NormalTok(".x, ");#VariableTok("self");#NormalTok(".pdf_grid, left");#OperatorTok("=");#FloatTok("0.0");#NormalTok(", right");#OperatorTok("=");#FloatTok("0.0");#NormalTok(")");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ppf(");#VariableTok("self");#NormalTok(", u):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" np.interp(u, ");#VariableTok("self");#NormalTok(".F, ");#VariableTok("self");#NormalTok(".x)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" rvs(");#VariableTok("self");#NormalTok(", size");#OperatorTok("=");#DecValTok("1");#NormalTok(", random_state");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(random_state)");],
[#NormalTok("        u ");#OperatorTok("=");#NormalTok(" rng.random(size)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".ppf(u)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" mean(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" np.trapezoid(");#VariableTok("self");#NormalTok(".x ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".pdf_grid, ");#VariableTok("self");#NormalTok(".x)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" var(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        m ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".mean()");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" np.trapezoid((");#VariableTok("self");#NormalTok(".x ");#OperatorTok("-");#NormalTok(" m)");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".pdf_grid, ");#VariableTok("self");#NormalTok(".x)");],
[#NormalTok("    ");],
[#NormalTok("cum_freq ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#DecValTok("500");#NormalTok(": ");#FloatTok("0.05");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("600");#NormalTok(": ");#FloatTok("0.10");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("700");#NormalTok(": ");#FloatTok("0.20");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("800");#NormalTok(": ");#FloatTok("0.30");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("900");#NormalTok(": ");#FloatTok("0.34");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("1000");#NormalTok(": ");#FloatTok("0.55");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("1100");#NormalTok(": ");#FloatTok("0.7");#NormalTok(",");],
[#NormalTok("    ");#DecValTok("1200");#NormalTok(": ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("}");],
[],
[#NormalTok("dist ");#OperatorTok("=");#NormalTok(" ContinuousRV(cum_freq)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"CDF(2500) =\"");#NormalTok(", dist.cdf(");#DecValTok("2500");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"PDF(2500) =\"");#NormalTok(", dist.pdf(");#DecValTok("2500");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"PPF(0.5) =\"");#NormalTok(", dist.ppf(");#FloatTok("0.5");#NormalTok("))");],
[],
[#NormalTok("samples ");#OperatorTok("=");#NormalTok(" dist.rvs(size");#OperatorTok("=");#DecValTok("10000");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("42");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(samples[:");#DecValTok("10");#NormalTok("])");],
[],
[],
[#CommentTok("# Mean dan Var dari Teori");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean (integral):\"");#NormalTok(", dist.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var (integral):\"");#NormalTok(", dist.var())");],
[],
[#CommentTok("# bandingkan dengan sampling");],
[#NormalTok("samples ");#OperatorTok("=");#NormalTok(" dist.rvs(");#DecValTok("100000");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("42");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Mean (sampling):\"");#NormalTok(", samples.mean())");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Var (sampling):\"");#NormalTok(", samples.var())");],));
#block[
#Skylighting(([#NormalTok("CDF(2500) = 1.0");],
[#NormalTok("PDF(2500) = 0.0");],
[#NormalTok("PPF(0.5) = 976.1904761904761");],
[#NormalTok("[1124.65201619  947.08497131 1152.8659733  1098.24535271  588.35469578");],
[#NormalTok(" 1191.87411721 1120.37990066 1128.68810176  628.11363268  952.56473233]");],
[#NormalTok("Mean (integral): 903.5");],
[#NormalTok("Var (integral): 39422.137500000004");],
[#NormalTok("Mean (sampling): 928.9725930286986");],
[#NormalTok("Var (sampling): 45303.26251723101");],));
]
]
Week 05: Variabel Acak, Ekspektasi, dan Variansi

== Agenda Perkuliahan Minggu 5
<agenda-perkuliahan-minggu-5>
#strong[Tema Misi:] "The Gambler's Fallacy: Mastering Risk and Reward"

=== Pertemuan 1: Senin (1 Jam) - The Concept & The Trap
<pertemuan-1-senin-1-jam---the-concept-the-trap>
#strong[Fokus:] Mengubah "Kejadian" menjadi "Angka" (Variabel Acak) dan memahami arti "Nilai Harapan" sebagai pusat massa data.

- #strong[00:00 - 00:10 | The Hook: "Gacha & Loot Boxes"]
  - Aktivitas: Tampilkan peluang drop rate item langka di game populer (misal: Genshin Impact atau Mobile Legends).
  - Pertanyaan: "Item A harganya 1000 Diamond, tapi bisa didapat lewat Gacha seharga 100 Diamond dengan peluang 5%. Mana yang lebih 'cuan' secara matematis?"
  - Konsep: Perkenalkan Variabel Acak ($X$) sebagai pemetaan dari Item (Event) ke Nilai Uang (Number).
- #strong[00:10 - 00:30 | Live Coding: "The Law of Averages"]
  - Dosen (Python Demo): Simulasikan taruhan Gacha tersebut 10.000 kali.
  - Visualisasi: Plot rata-rata kumulatif kemenangan. Tunjukkan garis konvergensi menuju Ekspektasi ($E \[ X \]$).
  - Poin Kunci: $E \[ X \]$ bukan nilai yang akan Anda dapatkan sekali main, tapi rata-rata jika Anda main selamanya.
- #strong[00:30 - 00:50 | Deep Dive: Variansi = Risiko]
  - Skenario: Dua server. Server A ping-nya stabil 50ms. Server B ping-nya rata-rata 50ms tapi sering spike ke 200ms. Rata-rata sama, tapi pengalaman beda.
  - Definisikan Variansi ($V a r \( X \)$): Ukuran "keganasan" fluktuasi data. Bagi insinyur IT, variansi adalah musuh (risiko/ketidakstabilan).
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Casino House Edge". Mahasiswa harus merancang permainan judi digital yang menjamin bandar (mereka) untung dalam jangka panjang, tapi tetap menarik bagi pemain.

=== Pertemuan 2: Rabu (2 Jam) - Simulation Lab
<pertemuan-2-rabu-2-jam---simulation-lab>
#strong[Fokus:] Menggunakan Python untuk menghitung risiko investasi/bisnis dan membuktikan sifat momen.

- #strong[00:00 - 00:20 | Setup & Micro-Lecture: PDF vs CDF]
  - Visual: Gunakan matplotlib step-plot untuk menggambar PMF (Probabilitas per titik) dan CDF (Probabilitas kumulatif).
  - Konsep: CDF tidak pernah turun. Ini seperti "loading bar" probabilitas.
- #strong[00:20 - 01:00 | Pod Challenge: "Risk-Return Tradeoff"]
  - Skenario: Anda manajer investasi IT. Ada 2 proyek:
    - Proyek A (Stabil): Untung \$10k (90%), Rugi \$1k (10%).
    - Proyek B (Volatil): Untung \$50k (30%), Rugi \$10k (70%).
  - Tugas (Python):
    + Hitung $E \[ X \]$ dan $V a r \( X \)$ kedua proyek.
    + Simulasikan 100 kali jalan. Berapa kali Proyek B bangkrut?
    + Visualisasikan histogram hasil akhir.
- #strong[01:00 - 01:40 | Studi Kasus: "Expected Latency"]
  - Menghitung expected cost dari retry logic. Jika login gagal ($p = 0.2$), user mencoba lagi. Berapa rata-rata jumlah percobaan? (Pengantar distribusi Geometrik).
- #strong[01:40 - 01:50 | Code Review & Debat]
  - "Apakah $E \[ X \]$ tinggi selalu lebih baik?" (Jawab: Tidak jika Variansinya membahayakan kelangsungan hidup perusahaan).
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Jelaskan dengan bahasa manusia, apa bedanya $E \[ X \]$ dan rata-rata sampel ($macron(x)$)?"

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-4>
=== 1. Konsep Dasar
<konsep-dasar-3>
- #strong[Variabel Acak (]$X$): Fungsi yang memetakan hasil ruang sampel ($Omega$) ke bilangan riil ($bb(R)$). Contoh: $X$ = jumlah paket error.
- #strong[Ekspektasi (]$E \[ X \]$): Pusat massa distribusi.
  - Rumus Diskrit: $E \[ X \] = sum x dot.op P \( X = x \)$.
  - Sifat Linear: $E \[ a X + b \] = a E \[ X \] + b$. (Berguna untuk konversi unit, misal dari Detik ke Milidetik).
- #strong[Variansi (]$V a r \( X \)$): Ukuran penyebaran data dari rata-ratanya (Momen ke-2).
  - Rumus: $V a r \( X \) = E \[ \( X - mu \)^2 \] = E \[ X^2 \] - \( E \[ X \] \)^2$.
  - Sifat: $V a r \( a X + b \) = a^2 V a r \( X \)$. Konstanta $b$ tidak mempengaruhi sebaran.

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-3>
- #strong[Capacity Planning:] Menggunakan $E \[ X \]$ traffic untuk beli server dasar, dan $V a r \( X \)$ untuk menentukan buffer kapasitas (Auto-scaling margin).
- #strong[Analisis Risiko:] Dalam keamanan siber, Risiko = Dampak $times$ Probabilitas ($E \[ upright("Loss") \]$).
- #strong[Algoritma Game:] Menyeimbangkan loot box agar tidak terlalu pelit (pemain kabur) atau terlalu murah (dev bangkrut).

=== 3. Komputasi (Python)
<komputasi-python-3>
- #strong[Numpy:] Menggunakan #NormalTok("np.mean()"); dan #NormalTok("np.var()"); untuk data sampel.
- #strong[Custom Functions:] Implementasi rumus ekspektasi dengan #NormalTok("sum(x * p for x, p in zip(values, probs))");.

#strong[Scipy Stats:] Menggunakan #NormalTok("rv_discrete"); untuk membuat objek variabel acak kustom dan menghitung momennya secara otomatis.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-4>
#strong[Judul:] Week 5: The Digital Casino - Designing Probability for Profit

#strong[Deskripsi:] Mahasiswa bertindak sebagai Game Designer. Mereka harus merancang sistem reward (Variabel Acak) untuk event game baru.

#strong[Set Soal (Notebook):]

+ 1. #strong[Design Distribution:]

  - - Tentukan 3 jenis hadiah (Common, Rare, Epic) dengan nilai poin tertentu.

  - - Tentukan probabilitas masing-masing ($P_(c o m m o n) \, P_(r a r e) \, P_(e p i c)$) sehingga totalnya 1.

+ 2. #strong[Theoretical Calculation:]

  - -Hitung Ekspektasi poin per tarikan ($E \[ X \]$).

  - Hitung Variansi poin ($V a r \( X \)$).

  - Jika biaya main = 100 poin, apakah pemain untung atau rugi secara rata-rata?

+ 3. #strong[Simulation Verification:] \`

  - - Simulasikan 10.000 kali tarikan menggunakan #NormalTok("numpy.random.choice");.

  - - Bandingkan rata-rata simulasi dengan $E \[ X \]$ teoretis. Plot grafik konvergensinya (Hukum Bilangan Besar).

+ 4. #strong[Business Logic:]

  - - Manajemen minta agar kasino untung minimal 10% dari setiap tiket. Ubah probabilitas atau nilai hadiah untuk mencapai target ini tanpa membuat game jadi membosankan (Variansi jangan 0).

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-3>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-4>
+ #strong[Soal:] Apa perbedaan mendasar antara variabel acak diskrit dan kontinu dalam hal cara menghitung probabilitas di satu titik?
  - #strong[Solusi:] Untuk variabel acak diskrit, probabilitas di satu titik $P \( X = x \)$ adalah nilai dari Probability Mass Function (PMF) dan bisa bernilai positif. Untuk variabel acak kontinu, probabilitas di satu titik tunggal $P \( X = x \)$ selalu sama dengan 0; probabilitas hanya didefinisikan dalam interval (luas area di bawah kurva PDF).
+ #strong[Soal:] Mengapa nilai harapan ($E \[ X \]$) sering disebut sebagai pusat massa dari distribusi probabilitas?
  - #strong[Solusi:] Secara matematis, rumus ekspektasi $E \[ X \] = sum x p \( x \)$ identik dengan rumus titik berat dalam fisika, di mana $x$ adalah posisi dan $p \( x \)$ adalah massa di titik tersebut. Jika kita menyeimbangkan histogram distribusi pada sebuah titik tumpu, titik tersebut adalah $E \[ X \]$.
+ #strong[Soal:] Jelaskan hubungan antara variansi dan risiko dalam konteks investasi infrastruktur IT.
  - #strong[Solusi:] Variansi mengukur seberapa jauh hasil aktual bisa menyimpang dari rata-rata (ekspektasi). Dalam IT, variansi tinggi berarti ketidakpastian tinggi (misal: latensi yang kadang cepat sekali, kadang lambat sekali). Investasi dengan variansi tinggi dianggap "berisiko" karena sulit diprediksi dan membutuhkan mitigasi (buffer) yang lebih besar.
+ #strong[Soal:] Apa yang dimaksud dengan fungsi distribusi kumulatif (CDF) dan mengapa nilainya tidak pernah turun?
  - #strong[Solusi:] CDF, $F \( x \) = P \( X lt.eq x \)$, menyatakan peluang variabel acak bernilai kurang dari atau sama dengan $x$. Nilainya tidak pernah turun (monoton naik) karena probabilitas adalah non-negatif; saat kita menggeser $x$ ke kanan, kita hanya bisa menambah (atau tetap), tidak mungkin mengurangi akumulasi peluang yang sudah didapat.
+ #strong[Soal:] Deskripsikan makna fisik dari momen kedua (variansi) terhadap penyebaran data dari nilai rata-ratanya.
  - #strong[Solusi:] Momen kedua di sekitar mean, $E \[ \( X - mu \)^2 \]$, mengukur rata-rata kuadrat jarak data ke pusatnya. Fisiknya mirip dengan "momen inersia": semakin besar variansi, semakin "berat" ekor distribusi atau semakin tersebar datanya dari pusat, menunjukkan fluktuasi yang besar.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-4>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah game online memberikan hadiah Rp 10.000 dengan probabilitas 0,1 dan Rp 0 dengan probabilitas 0,9. Berapakah biaya pendaftaran maksimum yang adil secara statistik?
  - #strong[Solusi:] Biaya adil (fair price) sama dengan nilai harapan kemenangan. $E \[ X \] = \( 10.000 times 0 \, 1 \) + \( 0 times 0 \, 9 \) = 1.000$. Jadi, biaya pendaftaran maksimum agar permainan adil adalah Rp 1.000.
+ #strong[Soal:] Analisis variansi waktu respons database untuk menentukan kestabilan layanan bagi pengguna.
  - #strong[Solusi:] Rata-rata waktu respons (mean) yang rendah itu baik, tapi tidak cukup. Jika variansi tinggi, pengguna akan merasakan pengalaman yang tidak konsisten ("kadang cepat, kadang lag"). Layanan yang stabil harus memiliki variansi (atau standar deviasi) yang kecil agar performa dapat diprediksi (sesuai SLA).
+ #strong[Soal:] Jika sebuah server memiliki kapasitas 100 unit, dan beban kerja harian adalah variabel acak X dengan $mu = 80$ dan $sigma = 10$, seberapa sering server akan mengalami overload?
  - #strong[Solusi:] Overload terjadi jika $X > 100$. Menggunakan pendekatan Skor-Z: $Z = \( 100 - 80 \) \/ 10 = 2$. Dari tabel normal standar, $P \( Z > 2 \) approx 0.0228$ atau sekitar 2.28%. Server akan overload sekitar 2-3 kali per 100 hari.
+ #strong[Soal:] Gunakan konsep ekspektasi untuk menghitung rata-rata jumlah percobaan login yang dilakukan user sebelum berhasil, jika probabilitas berhasil tiap kali adalah $p$.
  - #strong[Solusi:] Ini adalah Variabel Acak Geometrik. Nilai harapannya adalah $E \[ X \] = 1 \/ p$. Jika peluang berhasil login $p = 0.5$, maka rata-rata butuh $1 \/ 0.5 = 2$ kali percobaan.
+ #strong[Soal:] Analisis profitabilitas proyek software menggunakan variabel acak untuk estimasi pendapatan dan biaya.
  - #strong[Solusi:] Profit $P = upright("Pendapatan") \( R \) - upright("Biaya") \( C \)$. Karena $R$ dan $C$ acak, $P$ juga variabel acak. $E \[ P \] = E \[ R \] - E \[ C \]$. Proyek layak jika $E \[ P \] > 0$ dan $V a r \( P \) = V a r \( R \) + V a r \( C \)$ (asumsi independen) berada dalam batas toleransi risiko perusahaan.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-4>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Tulis skrip Python untuk menghitung mean dan variansi dari distribusi probabilitas diskrit yang diberikan dalam bentuk dictionary.

  - #strong[Solusi:]

  #block[
  #Skylighting(([#NormalTok("dist ");#OperatorTok("=");#NormalTok(" {");#DecValTok("1");#NormalTok(": ");#FloatTok("0.2");#NormalTok(", ");#DecValTok("2");#NormalTok(": ");#FloatTok("0.5");#NormalTok(", ");#DecValTok("3");#NormalTok(": ");#FloatTok("0.3");#NormalTok("} ");#CommentTok("# Value: Prob  ");],
  [#NormalTok("mean ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(x ");#OperatorTok("*");#NormalTok(" p ");#ControlFlowTok("for");#NormalTok(" x, p ");#KeywordTok("in");#NormalTok(" dist.items())  ");],
  [#NormalTok("variance ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("((x ");#OperatorTok("-");#NormalTok(" mean)");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" p ");#ControlFlowTok("for");#NormalTok(" x, p ");#KeywordTok("in");#NormalTok(" dist.items())  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Mean: ");#SpecialCharTok("{");#NormalTok("mean");#SpecialCharTok("}");#SpecialStringTok(", Variance: ");#SpecialCharTok("{");#NormalTok("variance");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
  #block[
  #Skylighting(([#NormalTok("Mean: 2.1, Variance: 0.49");],));
  ]
  ]

+ #strong[Soal:] Gunakan #NormalTok("scipy.stats"); untuk menghasilkan 1.000 sampel dari variabel acak kustom dan bandingkan rata-rata sampelnya dengan nilai harapan teoretis.

  - #strong[Solusi:]

  #block[
  #Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" rv_discrete  ");],
  [#NormalTok("xk ");#OperatorTok("=");#NormalTok(" [");#DecValTok("10");#NormalTok(", ");#DecValTok("11");#NormalTok(", ");#DecValTok("12");#NormalTok("]");#OperatorTok(";");#NormalTok(" pk ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.3");#NormalTok("]  ");],
  [#NormalTok("cust_dist ");#OperatorTok("=");#NormalTok(" rv_discrete(name");#OperatorTok("=");#StringTok("'cust'");#NormalTok(", values");#OperatorTok("=");#NormalTok("(xk, pk))  ");],
  [#NormalTok("samples ");#OperatorTok("=");#NormalTok(" cust_dist.rvs(size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Sample Mean: ");#SpecialCharTok("{");#NormalTok("samples");#SpecialCharTok(".");#NormalTok("mean()");#SpecialCharTok("}");#SpecialStringTok(", Theory Mean: ");#SpecialCharTok("{");#NormalTok("cust_dist");#SpecialCharTok(".");#NormalTok("mean()");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
  #block[
  #Skylighting(([#NormalTok("Sample Mean: 11.081, Theory Mean: 11.1");],));
  ]
  ]

+ #strong[Soal:] Plot fungsi massa probabilitas (PMF) dan CDF dari sebuah variabel acak diskrit menggunakan step plot di matplotlib.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("x ");#OperatorTok("=");#NormalTok(" [");#DecValTok("10");#NormalTok(", ");#DecValTok("11");#NormalTok(", ");#DecValTok("12");#NormalTok("]");#OperatorTok(";");#NormalTok(" p ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.3");#NormalTok("]  ");],
  [#NormalTok("cdf ");#OperatorTok("=");#NormalTok(" np.cumsum(p)  ");],
  [#NormalTok("plt.step(x, cdf, where");#OperatorTok("=");#StringTok("'post'");#NormalTok(", label");#OperatorTok("=");#StringTok("'CDF'");#NormalTok(")  ");],
  [#NormalTok("plt.bar(x, p, label");#OperatorTok("=");#StringTok("'PMF'");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")  ");],
  [#NormalTok("plt.legend()");#OperatorTok(";");#NormalTok(" plt.show()  ");],));
  #box(image("ch/05-Variabel_Acak_files/figure-typst/cell-5-output-1.svg"))

+ #strong[Soal:] Implementasikan fungsi untuk menghitung variansi menggunakan rumus $E \[ X^2 \] - \( E \[ X \] \)^2$.

  - #strong[Solusi:]

  #block[
  #Skylighting(([#KeywordTok("def");#NormalTok(" calc_variance(values, probs):  ");],
  [#NormalTok("    ex ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(v ");#OperatorTok("*");#NormalTok(" p ");#ControlFlowTok("for");#NormalTok(" v, p ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(values, probs))  ");],
  [#NormalTok("    ex2 ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("((v");#OperatorTok("**");#DecValTok("2");#NormalTok(") ");#OperatorTok("*");#NormalTok(" p ");#ControlFlowTok("for");#NormalTok(" v, p ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(values, probs))  ");],
  [#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" ex2 ");#OperatorTok("-");#NormalTok(" ex");#OperatorTok("**");#DecValTok("2");#NormalTok("  ");],));
  ]

+ #strong[Soal:] Buat simulasi pelemparan dadu 10.000 kali dan tunjukkan secara visual bagaimana rata-rata kumulatifnya konvergen ke 3,5.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");#OperatorTok(";");#NormalTok(" ");#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
  [#NormalTok("rolls ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("7");#NormalTok(", n)  ");],
  [#BuiltInTok("print");#NormalTok("(rolls,");#StringTok("\"");#CharTok("\\n");#StringTok("\"");#NormalTok(")");],
  [#NormalTok("avgs ");#OperatorTok("=");#NormalTok(" np.cumsum(rolls) ");#OperatorTok("/");#NormalTok(" np.arange(");#DecValTok("1");#NormalTok(", n");#OperatorTok("+");#DecValTok("1");#NormalTok(")  ");],
  [#NormalTok("plt.plot(avgs)");#OperatorTok(";");#NormalTok(" plt.axhline(");#FloatTok("3.5");#NormalTok(", color");#OperatorTok("=");#StringTok("'r'");#NormalTok(")");#OperatorTok(";");#NormalTok("  plt.show()  ");],));
  #block[
  #Skylighting(([#NormalTok("[4 3 1 6 4 3 2 6 4 2 5 2 1 4 1 3 4 6 1 1 1 4 6 2 6 4 2 6 3 3 1 3 2 6 1 4 1");],
  [#NormalTok(" 6 3 1 2 4 3 3 5 2 6 3 3 1 4 6 5 2 5 4 1 4 1 4 2 1 6 5 3 5 2 4 5 5 6 2 5 3");],
  [#NormalTok(" 2 5 4 6 1 3 5 5 5 1 3 4 2 2 2 4 5 2 1 3 5 6 1 2 5 1] ");],));
  ]
  #box(image("ch/05-Variabel_Acak_files/figure-typst/cell-7-output-2.svg"))
]

= Minggu 06: Variabel Acak Diskrit
<minggu-06-variabel-acak-diskrit>
Binomial Distribution, Poisson Distribution

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image6.png"))
], caption: figure.caption(
position: bottom, 
[
“Pabrik bilang cacat 1%. Kamu ambil 100 unit. Pertanyaan kecil tapi tajam: peluang tepat 2 cacat berapa? Ini momen kamu belajar memilih model yang tepat: Binomial untuk ‘n percobaan', Poisson untuk ‘kejadian jarang'. Engineer yang bagus bukan yang hafal rumus banyak---tapi yang #emph[tahu kapan pakai yang mana]. Hari ini kamu latihan dua model, lalu bikin keputusan QC: lanjut produksi atau stop inspeksi?”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-3>
Distribusi Binomial untuk jumlah sukses dalam n percobaan, Distribusi Poisson untuk jumlah kejadian dalam interval waktu/ruang tertentu.

== 2. Tipikal Problem
<tipikal-problem-3>
Sebuah pabrik ingin menjamin kualitas produk. Diketahui rata-rata cacat adalah 1%. Berapa peluang menemukan tepat 2 barang cacat dalam sampel 100 unit?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-3>
Menggunakan rumus distribusi Binomial (atau aproksimasi Poisson jika n besar dan p kecil). Jika peluang cacat melebihi ambang batas toleransi, manajer memutuskan untuk menghentikan lini produksi untuk inspeksi.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-5>
== Model dari Antrian
<model-dari-antrian>
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#CommentTok("# -*- coding: utf-8 -*-");],
[#NormalTok("n_plgn ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("selang ");#OperatorTok("=");#NormalTok(" ");#DecValTok("60");],
[#NormalTok("tiba_selang_rata ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[#NormalTok("lyn_selang_rata ");#OperatorTok("=");#NormalTok(" ");#DecValTok("7");],
[],
[#NormalTok("tiba_selang  ");#OperatorTok("=");#NormalTok(" np.random.exponential(tiba_selang_rata, n_plgn)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"rata-rata selang tiba: \"");#NormalTok(",");#BuiltInTok("sum");#NormalTok("(tiba_selang)");#OperatorTok("/");#BuiltInTok("len");#NormalTok("(tiba_selang))");],
[#NormalTok("tiba_waktu ");#OperatorTok("=");#NormalTok(" np.cumsum(tiba_selang)");],
[],
[#NormalTok("lyn_selang ");#OperatorTok("=");#NormalTok("  np.random.exponential(lyn_selang_rata, ");#BuiltInTok("len");#NormalTok("(tiba_selang))");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"rata-rata selang layanan: \"");#NormalTok(",");#BuiltInTok("sum");#NormalTok("(lyn_selang)");#OperatorTok("/");#BuiltInTok("len");#NormalTok("(lyn_selang))");],
[],
[#NormalTok("lyn_start ");#OperatorTok("=");#NormalTok(" np.zeros(");#BuiltInTok("len");#NormalTok("(tiba_selang))");],
[#NormalTok("lyn_finish ");#OperatorTok("=");#NormalTok(" np.zeros(");#BuiltInTok("len");#NormalTok("(tiba_selang))");],
[],
[#NormalTok("idx_pelanggan");#OperatorTok("=");#BuiltInTok("list");#NormalTok("(");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(tiba_selang)))");],
[#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" idx_pelanggan :");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" i ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("        lyn_start[i] ");#OperatorTok("=");#NormalTok(" tiba_waktu[i]");],
[#NormalTok("    ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("        lyn_start[i] ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(tiba_waktu[i], lyn_finish[i ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok("])");],
[#NormalTok("    lyn_finish[i] ");#OperatorTok("=");#NormalTok(" lyn_start[i] ");#OperatorTok("+");#NormalTok(" lyn_selang[i]");],
[],
[#NormalTok("waiting_duration ");#OperatorTok("=");#NormalTok(" lyn_start ");#OperatorTok("-");#NormalTok(" tiba_waktu");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"rata-rata antrian: \"");#NormalTok(",");#BuiltInTok("sum");#NormalTok("(waiting_duration)");#OperatorTok("/");#BuiltInTok("len");#NormalTok("(waiting_duration))");],
[#NormalTok("system ");#OperatorTok("=");#NormalTok(" lyn_finish ");#OperatorTok("-");#NormalTok(" tiba_waktu");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"rata-rata total layanan: \"");#NormalTok(",");#BuiltInTok("sum");#NormalTok("(waiting_duration");#OperatorTok("+");#NormalTok("lyn_selang)");#OperatorTok("/");#BuiltInTok("len");#NormalTok("(waiting_duration");#OperatorTok("+");#NormalTok("lyn_selang))");],
[],
[#NormalTok("fig, ([ax11, ax12], [ax21, ax22],[ax31, ax32]) ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("3");#NormalTok(",");#DecValTok("2");#NormalTok(")");],
[#NormalTok("ax11.eventplot(tiba_waktu)");],
[#NormalTok("ax21.eventplot(lyn_start)");],
[#NormalTok("ax31.eventplot(lyn_finish)");],
[#NormalTok("ax22.bar(idx_pelanggan, lyn_selang)");],
[#NormalTok("ax12.bar(idx_pelanggan, waiting_duration)");],
[#NormalTok("ax32.bar(idx_pelanggan, waiting_duration ");#OperatorTok("+");#NormalTok(" lyn_selang)");],
[#NormalTok("plt.tight_layout()");],
[#NormalTok("plt.show()");],));
#block[
#Skylighting(([#NormalTok("rata-rata selang tiba:  9.32235484916447");],
[#NormalTok("rata-rata selang layanan:  5.787969242886861");],
[#NormalTok("rata-rata antrian:  4.626373567009774");],
[#NormalTok("rata-rata total layanan:  10.414342809896631");],));
]
#box(image("ch/06-Variabel_Acak_Diskrit_files/figure-typst/cell-2-output-2.svg"))

Week 06: Distribusi Probabilitas Diskrit (Binomial & Poisson)

#strong["Simulation First, Math Later"] menghubungkan teori "kering" dengan aplikasi nyata seperti #emph[Gacha Games], #emph[Server Traffic], dan #emph[Cybersecurity].

#horizontalrule

== #strong[Agenda Perkuliahan Minggu 6]
<agenda-perkuliahan-minggu-6>
#strong[Topik:] Distribusi Binomial & Poisson #strong[Tema Misi:] #emph["The Digital Pulse: Counting Clicks, Bugs, and Attacks"]

=== #strong[Pertemuan 1: Senin (1 Jam) -- #emph[The Intuition & The Rare Event]]
<pertemuan-1-senin-1-jam-the-intuition-the-rare-event>
#emph[Fokus: Memahami pola "sukses/gagal" berulang dan fenomena "kejadian langka" melalui simulasi visual.]

- #strong[00:00 -- 00:10 | The Hook: "Gacha Rates & Server Bursts"]
  - #strong[Aktivitas:] Tampilkan simulator "Gacha" (atau Loot Box).
  - #strong[Pertanyaan:] "Jika #emph[drop rate] item langka adalah 1% ($p = 0.01$) dan kamu melakukan 100 kali #emph[pull] ($n = 100$), apakah kamu #strong[dijamin] dapat 1 item? Atau bisa 0? Atau 5?"
  - #strong[Poin:] Probabilitas bukan jaminan pasti, tapi distribusi kemungkinan. Ini adalah #strong[Binomial].
- #strong[00:10 -- 00:30 | Live Coding: "Visualizing Luck"]
  - #strong[Dosen (Python Demo):]
    - Gunakan #NormalTok("numpy.random.binomial(n=100, p=0.01, size=1000)");.
    - Plot histogram hasilnya.
    - #strong[Visualisasi:] Tunjukkan bahwa meskipun rata-rata dapat 1, banyak yang dapat 0 (sial) atau dapat 3 (hoki).
  - #strong[Transisi:] Apa yang terjadi jika $n$ (jumlah percobaan) menjadi tak hingga (waktu terus berjalan) dan $p$ sangat kecil? Kita masuk ke #strong[Poisson] (distribusi kejadian langka/trafik).
- #strong[00:30 -- 00:50 | Konsep: Binomial vs Poisson]
  - #strong[Binomial:] Diskrit, jumlah percobaan ($n$) tetap (misal: 10 paket data dikirim, berapa yang rusak?).
  - #strong[Poisson:] Diskrit, interval waktu/ruang, $n$ tidak diketahui tapi rata-rata ($lambda$) diketahui (misal: berapa serangan DDoS per jam?).
- #strong[00:50 -- 01:00 | Pod Formation & Mission Brief]
  - #strong[Misi GitHub:] #emph["The Traffic Controller"]. Mahasiswa akan mensimulasikan trafik jaringan untuk mendeteksi anomali.

=== #strong[Pertemuan 2: Rabu (2 Jam) -- #emph[Simulation Lab]]
<pertemuan-2-rabu-2-jam-simulation-lab-1>
#emph[Fokus: Menggunakan Python untuk menghitung risiko kegagalan sistem dan kapasitas server.]

- #strong[00:00 -- 00:20 | Micro-Lecture: Kapan Binomial] $approx$ Poisson?
  - #strong[Hukum Kejadian Jarang:] Tunjukkan lewat kode bahwa jika $n$ besar (1000) dan $p$ kecil (0.001), grafik Binomial dan Poisson ($lambda = n dot.op p$) akan berimpit. Ini memudahkan perhitungan di sistem #emph[real-time].
- #strong[00:20 -- 01:10 | Pod Challenge: "Capacity & Anomaly"]
  - #strong[Skenario:] Anda admin server. Rata-rata #emph[request] per detik adalah $lambda = 50$. Kapasitas server 70 req/detik.
  - #strong[Tugas (Python):]
    + Hitung peluang server #emph[crash] (request \> 70) menggunakan #NormalTok("scipy.stats.poisson");.
    + #strong[Simulasi:] Generate trafik selama 24 jam (86400 detik). Berapa detik server akan #emph[down]?
    + #strong[Deteksi Serangan:] Jika tiba-tiba masuk 100 request, hitung probabilitasnya. Jika $P \( X gt.eq 100 \)$ sangat kecil (misal \< 0.0001), sistem harus otomatis memblokir IP (anggap serangan).
- #strong[01:10 -- 01:40 | Studi Kasus: Bug Hunter]
  - #strong[Masalah:] Probabilitas 1 baris kode punya bug = 0.001. Ada 1000 baris kode.
  - #strong[Hitungan:] Berapa peluang software "Clean" (0 bug)? Bandingkan hitungan #NormalTok("binom"); vs #NormalTok("poisson");.
- #strong[01:40 -- 01:50 | Showcase & Keputusan]
  - Pods mempresentasikan: "Berapa kapasitas server cadangan yang harus dibeli agar peluang crash \< 1%?"
- #strong[01:50 -- 02:00 | Exit Ticket]
  - Pertanyaan: "Berikan satu contoh kejadian di sekitarmu yang mengikuti distribusi Poisson." (Jawab: Chat masuk per jam, motor lewat per menit).

#horizontalrule

== #strong[Materi Kuliah: Konsep, Aplikasi, & Komputasi]
<materi-kuliah-konsep-aplikasi-komputasi-5>
=== #strong[\1. Konsep Dasar]
<konsep-dasar-4>
- #strong[Distribusi Bernoulli:] Unit dasar. 1 percobaan, Sukses ($p$) atau Gagal ($1 - p$).
- #strong[Distribusi Binomial (]$n \, p$): Jumlah sukses $k$ dalam $n$ percobaan Bernoulli yang saling independen.
  - Rumus: $P \( X = k \) = binom(n, k) p^k \( 1 - p \)^(n - k)$.
- #strong[Distribusi Poisson (]$lambda$): Jumlah kejadian dalam interval waktu/ruang tertentu.
  - Rumus: $P \( X = k \) = frac(e^(- lambda) lambda^k, k !)$.
  - #strong[Hukum Kejadian Jarang:] Poisson adalah limit dari Binomial saat $n arrow.r oo$ dan $p arrow.r 0$.

=== #strong[\2. Aplikasi Sistem Informasi]
<aplikasi-sistem-informasi-4>
- #strong[Reliabilitas Komunikasi:] Menghitung peluang paket data rusak (Bit Error Rate). Jika dikirim 1000 bit dan $p_(e r r o r) = 10^(- 3)$, peluang paket diterima sempurna bisa dihitung dengan Binomial/Poisson.
- #strong[Antrian Server:] Memodelkan kedatangan #emph[user] ke website. Jika rata-rata 10 user/menit ($lambda = 10$), kita bisa menghitung peluang tiba-tiba datang 20 user (lonjakan beban).
- #strong[Cybersecurity:] Deteksi anomali. Jika jumlah login gagal per menit biasanya $lambda = 0.5$, dan tiba-tiba ada 10 login gagal, probabilitas kejadian ini sangat rendah menurut Poisson, sehingga diklasifikasikan sebagai #emph[Brute Force Attack].

=== #strong[\3. Komputasi (Python)]
<komputasi-python-4>
- #strong[Library:] #NormalTok("scipy.stats"); (modul #NormalTok("binom"); dan #NormalTok("poisson");).
- #strong[Fungsi Kunci:]
  - #NormalTok("binom.pmf(k, n, p)");: Peluang tepat $k$ sukses.
  - #NormalTok("poisson.cdf(k, mu)");: Peluang kumulatif ( $lt.eq k$ kejadian). Berguna untuk menghitung "Peluang server #emph[tidak] overload".
  - #NormalTok("numpy.random.poisson(lam, size)");: Simulasi data dummy trafik.

#horizontalrule

== #strong[Tugas Kelompok (GitHub Classroom)]
<tugas-kelompok-github-classroom-5>
#strong[Judul:] #emph[Week 6: The Network Guardian]

#strong[Deskripsi:] Mahasiswa diberikan log data simulasi jaringan. Mereka harus memodelkan pola trafik normal dan membuat skrip otomatis untuk mendeteksi anomali.

#strong[Set Soal (Notebook):]

+ 1. #strong[Modeling (30 poin):]

  + \* Analisis data historis: Hitung rata-rata request/detik ($lambda$).

  + \* Visualisasikan histogram data vs kurva teoritis Poisson($lambda$). Apakah cocok?

+ 2. #strong[Capacity Planning (30 poin):]

  + \* Perusahaan ingin menjamin 99.9% waktu server aman.

  + \* Cari nilai $C$ (kapasitas) sedemikian rupa sehingga $P \( X lt.eq C \) gt.eq 0.999$.

+ 3. #strong[Anomaly Detection (40 poin):]

  + \* Buat fungsi #NormalTok("is_anomaly(current_requests)");.

  + \* Jika probabilitas kejadian tersebut $< 0.05 %$ berdasarkan distribusi Poisson, kembalikan #NormalTok("True");.

  + \* Uji fungsi tersebut pada dataset serangan (dataset kedua).

#horizontalrule

== #strong[15 Soal & Solusi]
<soal-solusi-4>
Berikut adalah 15 soal yang diambil dari referensi #emph[Desain Kurikulum Statistika Generasi Z] (Bagian Minggu 06)--.

=== #strong[A. Pertanyaan Konseptual]
<a.-pertanyaan-konseptual-5>
#strong[\1. Soal:] Apa syarat-syarat utama agar sebuah eksperimen dapat dimodelkan dengan distribusi Binomial?

- #strong[Solusi:] Eksperimen terdiri dari $n$ percobaan identik, setiap percobaan hanya memiliki dua hasil (sukses/gagal), probabilitas sukses $p$ konstan untuk setiap percobaan, dan setiap percobaan saling independen.

#strong[\2. Soal:] Mengapa distribusi Poisson sering disebut sebagai distribusi untuk kejadian langka?

- #strong[Solusi:] Karena Poisson sering diturunkan dari distribusi Binomial di mana jumlah percobaan $n$ sangat besar (menuju tak hingga) namun probabilitas sukses $p$ sangat kecil (menuju nol), sehingga kejadian "sukses" relatif jarang terjadi dibanding total kemungkinan.

#strong[\3. Soal:] Jelaskan hubungan antara distribusi Binomial dan distribusi Bernoulli.

- #strong[Solusi:] Distribusi Bernoulli adalah kasus khusus dari distribusi Binomial dengan jumlah percobaan $n = 1$. Distribusi Binomial adalah penjumlahan dari $n$ variabel acak Bernoulli yang independen dan identik.

#strong[\4. Soal:] Dalam kondisi apa distribusi Poisson dapat digunakan sebagai pendekatan untuk distribusi Binomial?

- #strong[Solusi:] Ketika jumlah percobaan $n$ sangat besar ($n gt.eq 30$ atau $n arrow.r oo$) dan probabilitas sukses $p$ sangat kecil ($p lt.eq 0.05$ atau $p arrow.r 0$), serta rata-rata $n p$ tetap konstan sebagai $lambda$.

#strong[\5. Soal:] Apa makna parameter $lambda$ dalam distribusi Poisson dalam konteks lalu lintas paket data?

- #strong[Solusi:] Parameter $lambda$ merepresentasikan rata-rata jumlah paket data yang tiba atau diproses per satuan waktu (misalnya: paket per detik) atau per satuan ruang.

=== #strong[B. Pertanyaan Aplikatif]
<b.-pertanyaan-aplikatif-5>
#strong[\6. Soal:] Sebuah sistem mengirimkan 10 paket data. Jika probabilitas satu paket rusak adalah 0,1, berapa probabilitas tepat 2 paket rusak?

- #strong[Solusi:] Gunakan Binomial($n = 10 \, p = 0.1$). $P \( X = 2 \) = binom(10, 2) \( 0.1 \)^2 \( 0.9 \)^8 = 45 dot.op 0.01 dot.op 0.430 = 0.1937$.

#strong[\7. Soal:] Rata-rata serangan siber yang terdeteksi pada firewall adalah 2 per jam. Berapa probabilitas tidak ada serangan dalam satu jam ke depan?

- #strong[Solusi:] Gunakan Poisson($lambda = 2$). $P \( X = 0 \) = frac(e^(- 2) 2^0, 0 !) = e^(- 2) approx 0.1353$.

#strong[\8. Soal:] Dalam pengujian software, probabilitas menemukan bug pada satu baris kode adalah 0,001. Jika ada 1.000 baris kode, gunakan pendekatan Poisson untuk menghitung probabilitas ada tepat 1 bug.

- #strong[Solusi:] $lambda = n dot.op p = 1000 dot.op 0.001 = 1$. $P \( X = 1 \) = frac(e^(- 1) 1^1, 1 !) = e^(- 1) approx 0.3679$.

#strong[\9. Soal:] Sebuah database melayani rata-rata 50 query per detik. Hitung probabilitas server menerima lebih dari 60 query dalam satu detik tertentu.

- #strong[Solusi:] Gunakan Poisson($lambda = 50$). Kita cari $P \( X > 60 \) = 1 - P \( X lt.eq 60 \)$. Ini biasanya dihitung menggunakan tabel atau komputer (#NormalTok("1 - poisson.cdf(60, 50)");), hasilnya sekitar 0.072 (7.2%).

#strong[\10. Soal:] Analisis probabilitas jumlah user yang mengklik iklan dalam 100 impresi jika #emph[click-through rate] (CTR) adalah 2%.

- #strong[Solusi:] Ini model Binomial($n = 100 \, p = 0.02$). Kita bisa menghitung peluang untuk berbagai jumlah klik (0, 1, 2, dst) untuk memprediksi performa iklan. Rata-rata klik yang diharapkan adalah $E \[ X \] = 100 dot.op 0.02 = 2$ klik.

=== #strong[C. Pertanyaan Komputasional]
<c.-pertanyaan-komputasional-5>
#strong[\11. Soal:] Gunakan #NormalTok("scipy.stats.binom.pmf"); untuk memplot probabilitas jumlah sukses dari 0 hingga 20 dalam eksperimen dengan $n = 20$ dan $p = 0.5$. \*

- #strong[Solusi:]

#Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" binom");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("21");#NormalTok(")");],
[#NormalTok("plt.bar(x, binom.pmf(x, ");#DecValTok("20");#NormalTok(", ");#FloatTok("0.5");#NormalTok("))");],
[#NormalTok("plt.show()");],));
#box(image("ch/06-Variabel_Acak_Diskrit_files/figure-typst/cell-3-output-1.svg"))

#strong[\12. Soal:] Tulis program Python yang membandingkan hasil perhitungan distribusi Binomial dan pendekatan Poisson untuk $n = 100$ dan $p = 0.01$.

- #strong[Solusi:]

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" binom, poisson");],
[#NormalTok("n, p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");#NormalTok(", ");#FloatTok("0.01");],
[#NormalTok("mu ");#OperatorTok("=");#NormalTok(" n ");#OperatorTok("*");#NormalTok(" p");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Binom P(X=2): ");#SpecialCharTok("{");#NormalTok("binom");#SpecialCharTok(".");#NormalTok("pmf(");#DecValTok("2");#NormalTok(", n, p)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Poisson P(X=2): ");#SpecialCharTok("{");#NormalTok("poisson");#SpecialCharTok(".");#NormalTok("pmf(");#DecValTok("2");#NormalTok(", mu)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Binom P(X=2): 0.18486481882486347");],
[#NormalTok("Poisson P(X=2): 0.18393972058572114");],));
]
]
#strong[\13. Soal:] Simulasikan proses kedatangan Poisson dengan membangkitkan bilangan acak dan hitung jumlah kejadian dalam interval waktu tertentu.

- #strong[Solusi:]

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#CommentTok("# Simulasi 1000 jam, rata-rata 5 event/jam");],
[#NormalTok("simulasi ");#OperatorTok("=");#NormalTok(" np.random.poisson(lam");#OperatorTok("=");#DecValTok("5");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Rata-rata simulasi: ");#SpecialCharTok("{");#NormalTok("np");#SpecialCharTok(".");#NormalTok("mean(simulasi)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Rata-rata simulasi: 5.004");],));
]
]
#strong[\14. Soal:] Visualisasikan perubahan bentuk distribusi Binomial saat parameter $p$ bervariasi dari 0,1 hingga 0,9.

- #strong[Solusi:]

#Skylighting(([#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("20");],
[#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" [");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.9");#NormalTok("]:");],
[#NormalTok("    plt.plot(binom.pmf(");#BuiltInTok("range");#NormalTok("(n");#OperatorTok("+");#DecValTok("1");#NormalTok("), n, p), label");#OperatorTok("=");#SpecialStringTok("f'p=");#SpecialCharTok("{");#NormalTok("p");#SpecialCharTok("}");#SpecialStringTok("'");#NormalTok(")");],
[#NormalTok("plt.legend()");#OperatorTok(";");#NormalTok(" plt.show()");],));
#box(image("ch/06-Variabel_Acak_Diskrit_files/figure-typst/cell-6-output-1.svg"))

#strong[\15. Soal:] Implementasikan fungsi untuk menghitung probabilitas kumulatif Binomial tanpa menggunakan pustaka eksternal.

#strong[Solusi:]

#block[
#Skylighting(([#KeywordTok("def");#NormalTok(" factorial(n):");],
[#NormalTok("    result ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("2");#NormalTok(", n ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("        result ");#OperatorTok("*=");#NormalTok(" i");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" result");],
[],
[],
[#KeywordTok("def");#NormalTok(" combination(n, k):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" factorial(n) ");#OperatorTok("//");#NormalTok(" (factorial(k) ");#OperatorTok("*");#NormalTok(" factorial(n ");#OperatorTok("-");#NormalTok(" k))");],
[],
[],
[#KeywordTok("def");#NormalTok(" binomial_pmf(n, k, p):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" combination(n, k) ");#OperatorTok("*");#NormalTok(" (p ");#OperatorTok("**");#NormalTok(" k) ");#OperatorTok("*");#NormalTok(" ((");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p) ");#OperatorTok("**");#NormalTok(" (n ");#OperatorTok("-");#NormalTok(" k))");],
[],
[],
[#KeywordTok("def");#NormalTok(" binomial_cdf(n, k, p):");],
[#NormalTok("    total ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(k ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("        total ");#OperatorTok("+=");#NormalTok(" binomial_pmf(n, i, p)");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" total");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");#NormalTok("      ");#CommentTok("# jumlah percobaan");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.5");#NormalTok("     ");#CommentTok("# probabilitas sukses");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3");#NormalTok("       ");#CommentTok("# batas kumulatif");],
[],
[#NormalTok("prob ");#OperatorTok("=");#NormalTok(" binomial_cdf(n, k, p)");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(X <= ");#SpecialCharTok("{");#NormalTok("k");#SpecialCharTok("}");#SpecialStringTok(") = ");#SpecialCharTok("{");#NormalTok("prob");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("P(X <= 3) = 0.171875");],));
]
]
Versi lebih stabil tanpa factorial

#block[
#Skylighting(([#KeywordTok("def");#NormalTok(" binomial_cdf_stable(n, k, p):");],
[#NormalTok("    ");#CommentTok("# mulai dari P(X=0)");],
[#NormalTok("    prob ");#OperatorTok("=");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p) ");#OperatorTok("**");#NormalTok(" n");],
[#NormalTok("    total ");#OperatorTok("=");#NormalTok(" prob");],
[],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("0");#NormalTok(", k):");],
[#NormalTok("        prob ");#OperatorTok("=");#NormalTok(" prob ");#OperatorTok("*");#NormalTok(" (n ");#OperatorTok("-");#NormalTok(" i) ");#OperatorTok("/");#NormalTok(" (i ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#OperatorTok("*");#NormalTok(" (p ");#OperatorTok("/");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p))");],
[#NormalTok("        total ");#OperatorTok("+=");#NormalTok(" prob");],
[],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" total");],
[],
[#BuiltInTok("print");#NormalTok("(binomial_cdf_stable(");#DecValTok("10");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#FloatTok("0.5");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("0.171875");],));
]
]
= Minggu 07: Variabel Acak Kontinu
<minggu-07-variabel-acak-kontinu>
Normal Distribution, Exponential Distribution

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image7.png"))
], caption: figure.caption(
position: bottom, 
[
“Lampu rata-rata hidup 900 jam, simpangan 50 jam. Kamu mau kasih garansi 700 jam, 800 jam, atau 900 jam? Ini bukan sekadar ‘baik hati'---ini strategi biaya klaim. Normal sering muncul di data pengukuran; eksponensial sering muncul di waktu tunggu. Hari ini kamu belajar menghitung peluang rusak sebelum waktu T, lalu menentukan T yang masuk akal untuk target klaim. Kamu akan melihat: statistik bisa jadi alat desain produk.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-4>
Distribusi Normal (kurva lonceng) untuk data pengukuran alami, Distribusi Eksponensial untuk waktu tunggu antar kejadian.

== 2. Tipikal Problem
<tipikal-problem-4>
Menentukan garansi produk lampu. Diketahui masa hidup lampu berdistribusi Normal dengan rata-rata 900 jam dan standar deviasi 50 jam.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-4>
Menghitung peluang lampu mati sebelum waktu tertentu (misal P(X \< 700)). Perusahaan menetapkan masa garansi di titik di mana hanya sebagian kecil (misal 1%) lampu yang akan rusak, untuk meminimalkan biaya penggantian klaim garansi.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-6>
== Live Coding: "Normal is Everywhere"
<live-coding-normal-is-everywhere>
Misalnya suatu pabrik bisa menghasilkan 10000 lampu pertahun yang bisa bekerja rata-rata 900 jam, meskipun dalam kenyataanya kapan individual lampu bisa mati bervariasi. Seberapa besar variasi ini diukur oleh besaran deviasi, misalnya deviasi 50 jam yang berarti variance 2500 jam^2.

Untuk menang bersaing, harga harus murah dan garansi harus panjang. Bila ongkos produksi perlampu \$5, biaya penggantian (termasuk produksi dan pengiriman) \$7 per lampu yang rusak dalam mas garansi. Supaya untung paling besar mau dijual berapa dan garansi berapa lama? Misalnya pilihan harga \[\$12, \$13.5, atau \$15\]. Pilihan garansi \[750 jam, 800 jam, 850 jam\]. Maka profit dihitung dari jumlah yang laku, harga, biaya produksi, jumlah yang rusak, dan kewajiban garansi.

Ada sebuah random variable di sini: X = usia lampu, sehingga E(X) = 900 jam. Kita ingin tahu berapa peluang P\[X \< T\] jumlah unit yang harus diganti karena usia lampu tidak berhasil mencapai batas garansi w.

Kita misalnya mengukur usia lampu di laboratorium dan kita menemukan distribusi kumulatif menurut tabel ini:

#block[
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([durasi], [kumulatif],),
  table.hline(),
  [500], [0.05],
  [600], [0.10],
  [700], [0.20],
  [800], [0.3],
  [900], [0.34],
  [1000], [0.55],
  [1100], [0.7],
  [1200], [1.0],
)
Tabel hasil pengukuran durasi lampu disajikan secara kumulatif

] <tab-rvk-tabel>
Bagaimana memodelkan pengaruh harga dan garansi terhadap profit? Untuk praktik, saya sarankan:

- pakai #strong[profit per unit ekspektasian]: $p - c - g F \( w \)$

- pakai #strong[market share logit sederhana]: $s \( p \, w \) = frac(e^(- b p + d w), e^(- b p + d w) + K)$

- maksimalkan: $Pi \( p \, w \) = M \, s \( p \, w \) \, \[ p - c - g F \( w \) \]$

Karena model ini:

- sederhana
- masuk akal
- mudah dikalibrasi dari data pasar
- mudah disimulasikan

Kode menjadi:

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" math");],
[],
[#NormalTok("M ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100000");],
[#NormalTok("c ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("g ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[#NormalTok("prices ");#OperatorTok("=");#NormalTok(" [");#DecValTok("12");#NormalTok(", ");#FloatTok("13.5");#NormalTok(", ");#DecValTok("15");#NormalTok("]");],
[#NormalTok("warranties ");#OperatorTok("=");#NormalTok(" [");#DecValTok("8000");#NormalTok(", ");#DecValTok("9000");#NormalTok("]");],
[],
[],
[#KeywordTok("def");#NormalTok(" market_share(p, w):");],
[#NormalTok("    A ");#OperatorTok("=");#NormalTok(" math.exp(");#OperatorTok("-");#FloatTok("0.25");#NormalTok(" ");#OperatorTok("*");#NormalTok(" p ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.00015");#NormalTok(" ");#OperatorTok("*");#NormalTok(" w)");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" A ");#OperatorTok("/");#NormalTok(" (A ");#OperatorTok("+");#NormalTok(" ");#FloatTok("1.5");#NormalTok(")");],
[],
[#KeywordTok("def");#NormalTok(" F_uniform(w):");],
[#NormalTok("    A");#OperatorTok("=");#DecValTok("0");],
[#NormalTok("    B");#OperatorTok("=");#DecValTok("20000");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" (w");#OperatorTok("-");#NormalTok("A)");#OperatorTok("/");#NormalTok("(B");#OperatorTok("-");#NormalTok("A)");],
[],
[#KeywordTok("def");#NormalTok(" F_normal(w):");],
[#NormalTok("    z ");#OperatorTok("=");#NormalTok(" (w ");#OperatorTok("-");#NormalTok(" ");#DecValTok("10000");#NormalTok(") ");#OperatorTok("/");#NormalTok(" ");#DecValTok("1000");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" ");#FloatTok("0.5");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" math.erf(z ");#OperatorTok("/");#NormalTok(" math.sqrt(");#DecValTok("2");#NormalTok(")))");],
[],
[],
[#KeywordTok("def");#NormalTok(" F_exponential(w):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" math.exp(");#OperatorTok("-");#FloatTok("0.00005");#NormalTok(" ");#OperatorTok("*");#NormalTok(" w)");],
[],
[],
[#KeywordTok("def");#NormalTok(" F_weibull(w, k");#OperatorTok("=");#DecValTok("2");#NormalTok(", eta");#OperatorTok("=");#DecValTok("11000");#NormalTok("):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" math.exp(");#OperatorTok("-");#NormalTok(" (w ");#OperatorTok("/");#NormalTok(" eta) ");#OperatorTok("**");#NormalTok(" k)");],
[],
[],
[#KeywordTok("def");#NormalTok(" profit_per_unit(p, w, F):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" p ");#OperatorTok("-");#NormalTok(" c ");#OperatorTok("-");#NormalTok(" g ");#OperatorTok("*");#NormalTok(" F(w)");],
[],
[],
[#KeywordTok("def");#NormalTok(" total_profit(p, w, F):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" M ");#OperatorTok("*");#NormalTok(" market_share(p, w) ");#OperatorTok("*");#NormalTok(" profit_per_unit(p, w, F)");],
[],
[],
[#NormalTok("models ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"Uniform\"");#NormalTok(":F_uniform,");],
[#NormalTok("    ");#StringTok("\"Normal\"");#NormalTok(": F_normal,");],
[#NormalTok("    ");#StringTok("\"Eksponensial\"");#NormalTok(": F_exponential,");],
[#NormalTok("    ");#StringTok("\"Weibull\"");#NormalTok(": F_weibull,");],
[#NormalTok("}");],
[],
[#ControlFlowTok("for");#NormalTok(" name, F ");#KeywordTok("in");#NormalTok(" models.items():");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"");#CharTok("\\n");#SpecialStringTok("=== ");#SpecialCharTok("{");#NormalTok("name");#SpecialCharTok("}");#SpecialStringTok(" ===\"");#NormalTok(")");],
[#NormalTok("    best ");#OperatorTok("=");#NormalTok(" ");#VariableTok("None");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" prices:");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" w ");#KeywordTok("in");#NormalTok(" warranties:");],
[#NormalTok("            claim ");#OperatorTok("=");#NormalTok(" F(w)");],
[#NormalTok("            share ");#OperatorTok("=");#NormalTok(" market_share(p, w)");],
[#NormalTok("            unit_profit ");#OperatorTok("=");#NormalTok(" profit_per_unit(p, w, F)");],
[#NormalTok("            total ");#OperatorTok("=");#NormalTok(" total_profit(p, w, F)");],
[#NormalTok("            ");#BuiltInTok("print");#NormalTok("(");],
[#NormalTok("                ");#SpecialStringTok("f\"p=");#SpecialCharTok("{");#NormalTok("p");#SpecialCharTok(":>4}");#SpecialStringTok(", w=");#SpecialCharTok("{");#NormalTok("w");#SpecialCharTok(":>4}");#SpecialStringTok(", F=");#SpecialCharTok("{");#NormalTok("claim");#SpecialCharTok(":.4f}");#SpecialStringTok(", share=");#SpecialCharTok("{");#NormalTok("share");#SpecialCharTok(":.4f}");#SpecialStringTok(", \"");],
[#NormalTok("                ");#SpecialStringTok("f\"pi=");#SpecialCharTok("{");#NormalTok("unit_profit");#SpecialCharTok(":.4f}");#SpecialStringTok(", Pi=");#SpecialCharTok("{");#NormalTok("total");#SpecialCharTok(":,.2f}");#SpecialStringTok("\"");],
[#NormalTok("            )");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" best ");#KeywordTok("is");#NormalTok(" ");#VariableTok("None");#NormalTok(" ");#KeywordTok("or");#NormalTok(" total ");#OperatorTok(">");#NormalTok(" best[");#OperatorTok("-");#DecValTok("1");#NormalTok("]:");],
[#NormalTok("                best ");#OperatorTok("=");#NormalTok(" (p, w, total)");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Best: price=");#SpecialCharTok("{");#NormalTok("best[");#DecValTok("0");#NormalTok("]");#SpecialCharTok("}");#SpecialStringTok(", warranty=");#SpecialCharTok("{");#NormalTok("best[");#DecValTok("1");#NormalTok("]");#SpecialCharTok("}");#SpecialStringTok(", total profit=");#SpecialCharTok("{");#NormalTok("best[");#DecValTok("2");#NormalTok("]");#SpecialCharTok(":,.2f}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("=== Uniform ===");],
[#NormalTok("p=  12, w=8000, F=0.4000, share=0.0993, pi=3.0000, Pi=29,778.24");],
[#NormalTok("p=  12, w=9000, F=0.4500, share=0.1135, pi=2.5000, Pi=28,375.33");],
[#NormalTok("p=13.5, w=8000, F=0.4000, share=0.0704, pi=4.5000, Pi=31,682.83");],
[#NormalTok("p=13.5, w=9000, F=0.4500, share=0.0809, pi=4.0000, Pi=32,351.55");],
[#NormalTok("p=  15, w=8000, F=0.4000, share=0.0495, pi=6.0000, Pi=29,687.31");],
[#NormalTok("p=  15, w=9000, F=0.4500, share=0.0570, pi=5.5000, Pi=31,366.26");],
[#NormalTok("Best: price=13.5, warranty=9000, total profit=32,351.55");],
[],
[#NormalTok("=== Normal ===");],
[#NormalTok("p=  12, w=8000, F=0.0228, share=0.0993, pi=6.7725, Pi=67,224.36");],
[#NormalTok("p=  12, w=9000, F=0.1587, share=0.1135, pi=5.4134, Pi=61,443.35");],
[#NormalTok("p=13.5, w=8000, F=0.0228, share=0.0704, pi=8.2725, Pi=58,243.59");],
[#NormalTok("p=13.5, w=9000, F=0.1587, share=0.0809, pi=6.9134, Pi=55,915.19");],
[#NormalTok("p=  15, w=8000, F=0.0228, share=0.0495, pi=9.7725, Pi=48,353.20");],
[#NormalTok("p=  15, w=9000, F=0.1587, share=0.0570, pi=8.4134, Pi=47,981.53");],
[#NormalTok("Best: price=12, warranty=8000, total profit=67,224.36");],
[],
[#NormalTok("=== Eksponensial ===");],
[#NormalTok("p=  12, w=8000, F=0.3297, share=0.0993, pi=3.7032, Pi=36,758.26");],
[#NormalTok("p=  12, w=9000, F=0.3624, share=0.1135, pi=3.3763, Pi=38,321.24");],
[#NormalTok("p=13.5, w=8000, F=0.3297, share=0.0704, pi=5.2032, Pi=36,633.80");],
[#NormalTok("p=13.5, w=9000, F=0.3624, share=0.0809, pi=4.8763, Pi=39,438.82");],
[#NormalTok("p=  15, w=8000, F=0.3297, share=0.0495, pi=6.7032, Pi=33,166.66");],
[#NormalTok("p=  15, w=9000, F=0.3624, share=0.0570, pi=6.3763, Pi=36,363.66");],
[#NormalTok("Best: price=13.5, warranty=9000, total profit=39,438.82");],
[],
[#NormalTok("=== Weibull ===");],
[#NormalTok("p=  12, w=8000, F=0.4108, share=0.0993, pi=2.8924, Pi=28,709.96");],
[#NormalTok("p=  12, w=9000, F=0.4880, share=0.1135, pi=2.1200, Pi=24,062.81");],
[#NormalTok("p=13.5, w=8000, F=0.4108, share=0.0704, pi=4.3924, Pi=30,925.09");],
[#NormalTok("p=13.5, w=9000, F=0.4880, share=0.0809, pi=3.6200, Pi=29,278.54");],
[#NormalTok("p=  15, w=8000, F=0.4108, share=0.0495, pi=5.8924, Pi=29,154.80");],
[#NormalTok("p=  15, w=9000, F=0.4880, share=0.0570, pi=5.1200, Pi=29,199.41");],
[#NormalTok("Best: price=13.5, warranty=8000, total profit=30,925.09");],));
]
]
Week 07: Distribusi Kontinu: Kurva Normal dan Eksponensial dalam Rekayasa

== Agenda Perkuliahan Minggu 7
<agenda-perkuliahan-minggu-7>
#strong[Tema Misi:] "Predicting the Unpredictable: From Bell Curves to Waiting Games"

=== Pertemuan 1: Senin (1 Jam) - The Intuition & The Bell Curve
<pertemuan-1-senin-1-jam---the-intuition-the-bell-curve>
#strong[Fokus:] Memahami mengapa Distribusi Normal adalah "raja" distribusi dan kapan menggunakan Eksponensial untuk waktu.

- #strong[00:00 - 00:10 | The Hook: "Misteri Tinggi Badan & Error GPS"]
  - Aktivitas: Tampilkan histogram data tinggi badan 10.000 orang (atau data error GPS). Bentuknya selalu lonceng simetris.
  - Pertanyaan: "Kenapa fenomena yang tampak acak ini selalu membentuk pola yang sama? Kenapa tidak kotak atau segitiga?"
  - Konsep: Perkenalkan Distribusi Normal (Gaussian) sebagai hasil akumulasi banyak faktor kecil (prekursor Teorema Limit Pusat).
- #strong[00:10 - 00:30 | Live Coding: "Normal is Everywhere"]
  - Dosen (Python Demo):
    + Generate data acak #NormalTok("numpy.random.normal");.
    + Tunjukkan aturan empiris: 68% data ada di $mu plus.minus sigma$, 95% di $mu plus.minus 2 sigma$.
    + Visualisasi: Plot kurva lonceng dengan seaborn dan arsir area probabilitas.
- #strong[00:30 - 00:50 | Deep Dive: Menunggu Bus (Eksponensial)]
  - Skenario: "Kamu menunggu bus. Sudah 10 menit berlalu. Apakah peluang bus datang 5 menit lagi jadi lebih besar?"
  - Konsep: Perkenalkan Distribusi Eksponensial dan sifat #emph[Memoryless]. Jika bus datang secara acak (Poisson), waktu tunggunya tidak peduli masa lalu.
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Warranty Game". Mahasiswa harus menentukan masa garansi produk agar perusahaan tidak rugi bandar.

=== Pertemuan 2: Rabu (2 Jam) - Simulation Lab
<pertemuan-2-rabu-2-jam---simulation-lab-1>
#strong[Fokus:] Menggunakan Python untuk analisis reliabilitas produk dan menghitung probabilitas 'ekor' (#emph[tail events]).

- #strong[00:00 - 00:20 | Setup & Micro-Lecture: PDF vs Probabilitas]
  - Konsep: Ingatkan bahwa untuk kontinu, $P \( X = x \) = 0$. Probabilitas adalah Luas Area ($P \( a < X < b \)$).
  - Python Tool: #NormalTok("scipy.stats.norm.cdf"); (Cumulative Distribution Function) adalah teman terbaik kita.
- #strong[00:20 - 01:10 | Pod Challenge: "Product Reliability Engineer"]
  - Skenario: Anda Insinyur Kualitas di pabrik SSD (Solid State Drive).
  - Data: Umur SSD berdistribusi Normal ($mu = 5$ tahun, $sigma = 1$ tahun).
  - Tugas (Python):
    + Hitung berapa persen SSD yang rusak sebelum 3 tahun.
    + Tentukan masa garansi (dalam tahun) agar klaim garansi maksimal hanya 1% dari total produksi (Cari $x$ dimana $P \( X < x \) = 0.01$).
    + Simulasi: Generate 10.000 umur SSD, hitung biaya penggantian jika garansi diset 3 tahun vs 2 tahun.
- #strong[01:10 - 01:40 | Studi Kasus: "Latency & SLA"]
  - Analisis performa server. Jika latency rata-rata 200ms ($sigma = 50$ms), berapa peluang request timeout (\>350ms)? (Aplikasi Z-score).
- #strong[01:40 - 01:50 | Share & Interpretasi]
  - Pods mempresentasikan keputusan garansi mereka.
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Sebutkan satu kejadian di dunia nyata yang kira-kira mengikuti distribusi Normal dan satu yang Eksponensial."

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-6>
=== 1. Konsep Dasar
<konsep-dasar-5>
- #strong[Distribusi Normal (Gaussian):] Distribusi paling penting, berbentuk lonceng simetris. Ditentukan oleh dua parameter: Mean ($mu$) menentukan pusat, Standar Deviasi ($sigma$) menentukan lebar/sebaran.
  - #strong[Standard Normal (Z):] Distribusi normal dengan $mu = 0 \, sigma = 1$.
- #strong[Distribusi Eksponensial:] Memodelkan waktu tunggu antar kejadian dalam proses Poisson. Parameter $lambda$ (laju kejadian).
  - #strong[Sifat Memoryless:] $P \( X > t + s \| X > t \) = P \( X > s \)$. Sejarah tidak mempengaruhi masa depan.
- #strong[Probabilitas Kontinu:] Peluang pada satu titik spesifik adalah nol. Peluang dihitung sebagai integral dari fungsi kepadatan peluang (PDF).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-5>
- #strong[SLA (Service Level Agreement):] Menjamin bahwa "99% request akan selesai dalam \< 300ms". Ini menggunakan perhitungan ekor distribusi Normal/Log-Normal.
- #strong[MTTF (Mean Time To Failure):] Memodelkan umur komponen perangkat keras (hard disk, server) menggunakan distribusi Eksponensial untuk perencanaan maintenance.
- #strong[Anomaly Detection:] Menggunakan skor-Z. Jika data poin memiliki $\| Z \| > 3$ (jauh dari rata-rata), itu dicurigai sebagai anomali atau serangan siber.

=== 3. Komputasi (Python)
<komputasi-python-5>
- #strong[Scipy Stats:]
  - #NormalTok("norm.pdf(x, loc, scale)");: Tinggi kurva.
  - #NormalTok("norm.cdf(x, loc, scale)");: Luas area di kiri $x$ (Probabilitas kumulatif).
  - #NormalTok("norm.ppf(q, loc, scale)");: Kebalikan CDF (Mencari nilai $x$ dari persentase).
- #strong[Visualisasi:] Menggunakan #NormalTok("seaborn.kdeplot"); untuk melihat apakah data empiris mendekati bentuk lonceng.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-6>
#strong[Judul:] Week 7: The Guarantee Gambler - Optimizing Warranty Risks

#strong[Deskripsi:] Mahasiswa berperan sebagai tim Analis Risiko untuk peluncuran Smart Lamp baru. Mereka harus menyeimbangkan antara daya tarik marketing (garansi lama) dan risiko kebangkrutan (klaim garansi meledak).

#strong[Set Soal (Notebook):]

+ 1. #strong[Analisis Normal (30 poin):]

  + - Diketahui umur lampu $N \( mu = 10.000 upright(" jam") \, sigma = 1.000 upright(" jam") \)$.

  + - Hitung probabilitas lampu mati sebelum 8.000 jam.

  + - Cari "titik aman" jam ke berapa sehingga 95% lampu masih hidup.

+ 2. #strong[Analisis Eksponensial (30 poin):]

  + - Modul Wi-Fi pada lampu memiliki laju kegagalan $lambda = 0.00005$ per jam.

  + - Hitung probabilitas modul ini bertahan lebih dari 20.000 jam.

  + - Buktikan sifat #emph[memoryless] dengan simulasi: Bandingkan peluang bertahan 1000 jam lagi untuk modul baru vs modul yang sudah nyala 5000 jam.

+ 3. #strong[Keputusan Bisnis (40 poin):]

  + - Biaya produksi = \$5. Harga jual = \$15. Biaya ganti rugi garansi = \$10 (rugi total).

  + - Simulasikan profit total untuk 10.000 unit dengan opsi Garansi A (9.000 jam) vs Garansi B (8.000 jam).

  + - Buat rekomendasi: Mana yang memberikan profit bersih terbesar?

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-5>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-6>
+ #strong[Soal:] Mengapa probabilitas $P \( X = x \)$ pada distribusi kontinu selalu bernilai nol?
  - #strong[Solusi:] Karena pada distribusi kontinu, probabilitas didefinisikan sebagai luas area di bawah kurva PDF. Untuk satu titik tunggal (garis vertikal), lebarnya adalah nol, sehingga luas areanya (integral dari $x$ ke $x$) adalah nol. Probabilitas hanya bermakna dalam interval $P \( a < X < b \)$.
+ #strong[Soal:] Jelaskan makna fisis dari parameter $mu$ dan $sigma$ pada kurva lonceng distribusi Normal.
  - #strong[Solusi:]
    - $mu$ (Mean): Menunjukkan lokasi pusat atau puncak dari kurva lonceng (nilai yang paling mungkin muncul).
    - $sigma$ (Standar Deviasi): Menunjukkan seberapa lebar atau gemuk kurva tersebut. $sigma$ besar berarti kurva landai (data menyebar), $sigma$ kecil berarti kurva lancip (data terpusat di sekitar mean).
+ #strong[Soal:] Apa itu skor-Z dan mengapa kita perlu menstandarisasi variabel acak Normal?
  - #strong[Solusi:] Skor-Z ($z = \( x - mu \) \/ sigma$) mengukur berapa standar deviasi suatu nilai data berada dari rata-ratanya. Kita menstandarisasi variabel ke Normal Standar ($Z tilde.op N \( 0 \, 1 \)$) agar bisa membandingkan data dari distribusi yang berbeda (misal: membandingkan nilai ujian Matematika dan Fisika) dan menggunakan tabel probabilitas standar.
+ #strong[Soal:] Jelaskan sifat memoryless (tidak memiliki memori) pada distribusi Eksponensial dalam konteks kegagalan komponen.
  - #strong[Solusi:] Sifat memoryless berarti peluang komponen akan rusak dalam $t$ jam ke depan tidak dipengaruhi oleh sudah berapa lama komponen itu bekerja. Komponen bekas (yang masih berfungsi) dianggap memiliki reliabilitas yang sama dengan komponen baru. $P \( X > t + s \| X > s \) = P \( X > t \)$.
+ #strong[Soal:] Bagaimana hubungan antara distribusi Normal dan Teorema Limit Pusat secara intuitif?
  - #strong[Solusi:] Teorema Limit Pusat (CLT) menyatakan bahwa jika kita menjumlahkan banyak variabel acak independen (apa pun distribusi aslinya), hasil penjumlahannya akan cenderung berdistribusi Normal. Ini menjelaskan mengapa distribusi Normal muncul di mana-mana di alam (seperti tinggi badan), karena fenomena tersebut adalah hasil akumulasi dari banyak faktor genetik dan lingkungan yang kecil-kecil.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-6>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Waktu respons server berdistribusi Normal dengan mean 200ms dan standar deviasi 50ms. Berapa persen respons yang memakan waktu lebih dari 300ms?
  - #strong[Solusi:] Hitung skor-Z: $Z = \( 300 - 200 \) \/ 50 = 2$. Cari peluang $P \( Z > 2 \)$. Dari tabel/rumus, $P \( Z < 2 \) approx 0.9772$. Maka $P \( X > 300 \) = 1 - 0.9772 = 0.0228$ atau 2.28%.
+ #strong[Soal:] Umur pakai sebuah baterai laptop berdistribusi Eksponensial dengan rata-rata 5 tahun. Berapa probabilitas baterai bertahan lebih dari 8 tahun?
  - #strong[Solusi:] Rata-rata ($mu$) = $1 \/ lambda = 5 arrow.r lambda = 0.2$. Fungsi reliabilitas (survival): $P \( X > x \) = e^(- lambda x)$. $P \( X > 8 \) = e^(- 0.2 times 8) = e^(- 1.6) approx 0.2019$ atau 20.19%.
+ #strong[Soal:] Skor ujian masuk sebuah universitas berdistribusi Normal dengan rata-rata 500 dan simpangan baku 100. Jika diambil 10% terbaik, berapakah skor minimumnya?
  - #strong[Solusi:] Kita mencari nilai $x$ dimana $P \( X > x \) = 0.10$, atau $P \( X < x \) = 0.90$. Dari tabel Z invers, nilai Z untuk area 0.90 adalah $approx 1.28$. $x = mu + Z sigma = 500 + \( 1.28 times 100 \) = 628$. Skor minimum 628.
+ #strong[Soal:] Analisis lebar pita (bandwidth) yang digunakan oleh user di mana penggunaan rata-rata adalah 10 Mbps dengan distribusi Normal.
  - #strong[Solusi:] Karena bandwidth tidak bisa negatif, distribusi Normal murni mungkin kurang tepat jika $sigma$ besar (karena ekor kiri bisa masuk area negatif). Namun, sebagai pendekatan, kita bisa menghitung peluang penggunaan melebihi kapasitas tertentu (misal 15 Mbps) untuk capacity planning.
+ #strong[Soal:] Gunakan distribusi Eksponensial untuk memodelkan waktu antar-kedatangan (inter-arrival time) permintaan ke server web.
  - #strong[Solusi:] Jika server menerima rata-rata 5 request per detik ($lambda = 5$), maka waktu antar-kedatangan mengikuti Exp(5). Rata-rata waktu tunggu antar request adalah $1 \/ 5 = 0.2$ detik. Probabilitas menunggu lebih dari 1 detik sangat kecil: $e^(- 5 \( 1 \)) = 0.0067$.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-6>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Gunakan #NormalTok("scipy.stats.norm.cdf"); untuk menghitung probabilitas di antara dua nilai pada distribusi Normal.

  - #strong[Solusi:]

  #block[
  #Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" norm  ");],
  [#NormalTok("mu, sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");#NormalTok(", ");#DecValTok("15");#NormalTok("  ");],
  [#CommentTok("# P(85 < X < 115)  ");],
  [#NormalTok("prob ");#OperatorTok("=");#NormalTok(" norm.cdf(");#DecValTok("115");#NormalTok(", mu, sigma) ");#OperatorTok("-");#NormalTok(" norm.cdf(");#DecValTok("85");#NormalTok(", mu, sigma)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Probabilitas: ");#SpecialCharTok("{");#NormalTok("prob");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")  ");],));
  #block[
  #Skylighting(([#NormalTok("Probabilitas: 0.6827");],));
  ]
  ]

+ #strong[Soal:] Tulis skrip Python untuk menghasilkan plot distribusi Normal Standar dan arsirlah area di bawah kurva untuk $P \( - 1 < Z < 1 \)$.

  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");#OperatorTok(";");#NormalTok(" ");#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" norm  ");],
  [#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("3");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("100");#NormalTok(")  ");],
  [#NormalTok("plt.plot(x, norm.pdf(x))  ");],
  [#NormalTok("x_fill ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("100");#NormalTok(")  ");],
  [#NormalTok("plt.fill_between(x_fill, norm.pdf(x_fill), alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
  #box(image("ch/07-Variabel_Acak_Kontinu_files/figure-typst/cell-4-output-1.svg"))

+ #strong[Soal:] Implementasikan fungsi untuk menghitung skor-Z dari sekumpulan data numerik menggunakan numpy.

  - #strong[Solusi:]

  #block[
  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#KeywordTok("def");#NormalTok(" calculate_z_scores(data):  ");],
  [#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" (data ");#OperatorTok("-");#NormalTok(" np.mean(data)) ");#OperatorTok("/");#NormalTok(" np.std(data)  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok("]  ");],
  [#BuiltInTok("print");#NormalTok("(calculate_z_scores(data))  ");],));
  #block[
  #Skylighting(([#NormalTok("[-1.41421356 -0.70710678  0.          0.70710678  1.41421356]");],));
  ]
  ]

+ #strong[Soal:] Buat simulasi untuk membuktikan sifat memoryless dari distribusi Eksponensial dengan membangkitkan data acak.

  - #strong[Solusi:]

  #block[
  #Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" expon  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" expon.rvs(scale");#OperatorTok("=");#DecValTok("10");#NormalTok(", size");#OperatorTok("=");#DecValTok("10000");#NormalTok(") ");#CommentTok("# Mean=10  ");],
  [#CommentTok("# Peluang X > 15  ");],
  [#NormalTok("p_tot ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data[data ");#OperatorTok(">");#NormalTok(" ");#DecValTok("15");#NormalTok("]) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data)  ");],
  [#CommentTok("# Peluang X > 15 GIVEN X > 5 (sisa 10)  ");],
  [#NormalTok("subset ");#OperatorTok("=");#NormalTok(" data[data ");#OperatorTok(">");#NormalTok(" ");#DecValTok("5");#NormalTok("]  ");],
  [#NormalTok("p_cond ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(subset[subset ");#OperatorTok(">");#NormalTok(" ");#DecValTok("15");#NormalTok("]) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(subset)  ");],
  [#CommentTok("# Bandingkan dengan P(X > 10)  ");],
  [#NormalTok("p_ref ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data[data ");#OperatorTok(">");#NormalTok(" ");#DecValTok("10");#NormalTok("]) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(X>10): ");#SpecialCharTok("{");#NormalTok("p_ref");#SpecialCharTok(":.3f}");#SpecialStringTok(", P(X>15|X>5): ");#SpecialCharTok("{");#NormalTok("p_cond");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")  ");],));
  #block[
  #Skylighting(([#NormalTok("P(X>10): 0.369, P(X>15|X>5): 0.367");],));
  ]
  ]

+ #strong[Soal:] Visualisasikan bagaimana perubahan $sigma$ mempengaruhi "keruncingan" kurva Normal menggunakan matplotlib.

  - #strong[Solusi:]

  #Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("10");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("200");#NormalTok(")  ");],
  [#NormalTok("plt.plot(x, norm.pdf(x, ");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("'Sigma=1'");#NormalTok(")  ");],
  [#NormalTok("plt.plot(x, norm.pdf(x, ");#DecValTok("0");#NormalTok(", ");#FloatTok("0.5");#NormalTok("), label");#OperatorTok("=");#StringTok("'Sigma=0.5 (Lancip)'");#NormalTok(")  ");],
  [#NormalTok("plt.plot(x, norm.pdf(x, ");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok("), label");#OperatorTok("=");#StringTok("'Sigma=2 (Landai)'");#NormalTok(")  ");],
  [#NormalTok("plt.legend()");#OperatorTok(";");#NormalTok(" plt.show()  ");],));
  #box(image("ch/07-Variabel_Acak_Kontinu_files/figure-typst/cell-7-output-1.svg"))
]

= Minggu 08: Ujian Tengah Semester
<minggu-08-ujian-tengah-semester>
Midterm Exam

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image8.png"))
], caption: figure.caption(
position: bottom, 
[
“Hari ini bukan ujian hafalan. Ini ujian keputusan. Kamu akan diberi kasus seperti episode-episode sebelumnya: stok, reliability, alarm, risiko, cacat, garansi. Tugasmu: pilih model yang tepat, hitung, lalu jelaskan keputusan dengan kalimat yang tegas. Nilai tertinggi bukan dari rumus paling panjang, tapi dari reasoning paling bersih.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-5>
Evaluasi materi minggu 1-7.

== 2. Tipikal Problem
<tipikal-problem-5>
Ujian tertulis dan komputasi.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-5>
Mengerjakan soal evaluasi dengan pendekatan probabilitas dan statistik.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-7>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 08!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 08!");],));
]
]
Week 08: Pengujian Hipotesis Statistik

== Agenda Perkuliahan Minggu 08
<agenda-perkuliahan-minggu-08>
#strong[Topik:] Pengujian Hipotesis Statistik (#emph[Hypothesis Testing]) #strong[Tema Misi:] "Myth Busters: Is It Real or Just Random Noise?"

=== Pertemuan 1: Senin (1 Jam) - The Intuition & The Logic
<pertemuan-1-senin-1-jam---the-intuition-the-logic>
#strong[Fokus:] Membangun intuisi tentang P-value dan keputusan biner tanpa terjebak rumus rumit di awal.

- #strong[00:00 - 00:10 | The Hook: "Skepticism as a Tool"]
  - Aktivitas: Tampilkan klaim marketing bombastis, misal: "Algoritma baru kami meningkatkan kecepatan internet 200%!"
  - Diskusi: "Sebagai engineer, bagaimana kita membuktikan ini bohong atau benar? Apakah cukup dengan satu kali tes speedtest?"
  - Konsep: Perkenalkan $H_0$ (Status Quo/Skeptis) vs $H_1$ (Klaim Baru). Sikap dasar statistik adalah skeptis sampai data memaksanya percaya.
- #strong[00:10 - 00:30 | Live Demo: "The Coin Toss Judge"]
  - Dosen (Python): Simulasikan koin yang diklaim "curang". Lakukan 10 lemparan, dapat 8 Heads.
  - Pertanyaan: "Apakah koin ini curang, atau kita sedang beruntung?"
  - Simulasi: Jalankan 10.000 kali lemparan koin fair di Python. Hitung berapa kali muncul 8 Heads secara kebetulan.
  - Hasil: Jika kejadian itu sering muncul (misal 5%), kita tidak bisa menuduh koin curang. Inilah intuisi P-value.
- #strong[00:30 - 00:50 | Konsep: P-value & Error Types]
  - Jelaskan Galat Tipe I (Menuduh orang tidak bersalah/False Positive) dan Galat Tipe II (Membebaskan penjahat/False Negative).
  - Definisikan Signifikansi ($alpha$): Batas toleransi kita terhadap risiko menuduh salah (biasanya 0.05 atau 5%).
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The A/B Test Analyst". Mahasiswa akan menganalisis data eksperimen UI/UX untuk memutuskan fitur mana yang dirilis ke publik.

=== Pertemuan 2: Rabu (2 Jam) - Decision Lab
<pertemuan-2-rabu-2-jam---decision-lab>
#strong[Fokus:] Menggunakan Python (#NormalTok("scipy.stats");) untuk melakukan A/B Testing pada data riil.

- #strong[00:00 - 00:20 | Micro-Lecture: T-Test Setup]
  - Konsep: Kapan pakai Z-test (populasi tahu) vs T-test (sampel kecil/populasi tidak tahu). Di dunia IT, kita hampir selalu pakai T-test.
  - Python Tool: #NormalTok("scipy.stats.ttest_ind"); (untuk dua grup independen).
- #strong[00:20 - 01:10 | Pod Challenge: "Dark Mode vs.~Light Mode"]
  - Skenario: Tim desain mengklaim "Dark Mode" menghemat baterai HP user secara signifikan.
  - Data: Dua dataset array (konsumsi baterai grup A/Light dan grup B/Dark).
  - Tugas (Python):
    + Visualisasikan kedua distribusi (Histogram tumpang tindih).
    + Lakukan Uji Hipotesis (T-test).
    + Cek P-value. Jika $P < 0.05$, apakah perbedaan itu "signifikan"?
    + Critical Thinking: Apakah perbedaan 1% baterai walau signifikan secara statistik, signifikan secara bisnis?
- #strong[01:10 - 01:40 | Studi Kasus: "Server Response Time"]
  - Membandingkan performa server lama vs server baru. Hati-hati dengan jumlah sampel ($n$). Sampel terlalu besar bisa membuat beda kecil (0.001 ms) jadi "signifikan" (P-value hacking).
- #strong[01:40 - 01:50 | Debat & Keputusan]
  - Perwakilan Pods mempresentasikan keputusan rilis fitur mereka. "Launch" atau "Rollback"?
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Jelaskan P-value kepada nenekmu." (Jawaban ideal: Seberapa kaget kita melihat data ini jika tebakan awal kita benar).

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-7>
=== 1. Konsep Dasar
<konsep-dasar-6>
- #strong[Hipotesis Nol ($H_0$):] Asumsi dasar bahwa tidak ada efek atau perbedaan (misal: "Obat tidak bekerja", "Server baru sama saja").
- #strong[Hipotesis Alternatif ($H_1$):] Klaim yang ingin dibuktikan (misal: "Obat efektif", "Server baru lebih cepat").
- #strong[P-value:] Probabilitas melihat data se-ekstrim ini jika $H_0$ benar. P-value kecil (\< 0.05) $arrow.r$ Data sangat aneh/jarang $arrow.r$ Tolak $H_0$.
- #strong[Galat Tipe I ($alpha$):] False Positive. Menolak $H_0$ padahal $H_0$ benar (Melaporkan bug padahal tidak ada).
- #strong[Galat Tipe II ($beta$):] False Negative. Gagal menolak $H_0$ padahal $H_1$ benar (Melewatkan bug yang ada).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-6>
- #strong[A/B Testing:] Standar industri untuk peluncuran fitur (Google, Netflix, Tokopedia). Membandingkan metrik (klik, durasi tonton) antara Grup Kontrol dan Eksperimen.
- #strong[Performance Benchmarking:] Membuktikan secara statistik bahwa algoritma kompresi baru lebih cepat daripada yang lama, bukan sekadar kebetulan pada satu file.
- #strong[Security Anomaly:] Menguji apakah lonjakan trafik pada jam 2 pagi berbeda signifikan dari rata-rata historis (potensi DDoS).

=== 3. Komputasi (Python)
<komputasi-python-6>
- #strong[Library:] #NormalTok("scipy.stats"); adalah alat utama.
- #strong[Fungsi:]
  - #NormalTok("ttest_1samp");: Uji satu sampel terhadap rata-rata populasi.
  - #NormalTok("ttest_ind");: Uji dua sampel independen (A/B Testing).
  - #NormalTok("ttest_rel");: Uji pasangan (Before/After pada user yang sama).
- #strong[Interpretasi:] Python memberikan #NormalTok("statistic"); dan #NormalTok("pvalue");. Mahasiswa harus membandingkan #NormalTok("pvalue"); dengan alpha (0.05) untuk mengambil keputusan Boolean (Tolak/Terima).

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-7>
#strong[Judul:] Week 8 Mission: The Data-Driven Product Manager

#strong[Deskripsi:] Mahasiswa diberikan data log dari aplikasi e-commerce yang baru saja mengubah tata letak tombol "Beli". Tugas mereka adalah menentukan apakah perubahan ini meningkatkan penjualan atau justru membingungkan user.

#strong[Soal Python (Notebook):] 1. #strong[Data Exploration:] Load data #NormalTok("ab_test_data.csv");. Hitung rata-rata konversi (#emph[conversion\_rate]) untuk Grup A (Lama) dan Grup B (Baru). Buat boxplot perbandingan. 2. #strong[Hypothesis Formulation:] Tuliskan $H_0$ dan $H_1$ dalam kalimat bisnis dan simbol matematika. Tentukan $alpha$. 3. #strong[Testing:] - Gunakan #NormalTok("ttest_ind"); untuk menguji perbedaan rata-rata. - Hitung Confidence Interval selisih rata-rata kedua grup. 4. #strong[Business Decision:] - Jika P-value \< 0.05, apakah kita pasti harus rilis fitur baru? - Hitung Lift (kenaikan persentase). Jika kenaikan hanya 0.1% tapi signifikan, apakah sepadan dengan biaya dev? Tulis rekomendasi akhir kepada CTO.

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-6>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-7>
+ #strong[Soal:] Jelaskan perbedaan filosofis antara hipotesis nol ($H_0$) dan hipotesis alternatif ($H_1$).
  - #strong[Solusi:] $H_0$ adalah pernyataan "status quo" atau "tidak ada efek" yang diasumsikan benar sampai terbukti salah (pendekatan skeptis). $H_1$ adalah klaim baru atau efek yang ingin dibuktikan oleh peneliti. Kita hanya bisa menolak $H_0$, tidak pernah "membuktikan" $H_0$ benar.
+ #strong[Soal:] Apa yang dimaksud dengan tingkat signifikansi ($alpha$) dan hubungannya dengan Galat Tipe I?
  - #strong[Solusi:] Tingkat signifikansi ($alpha$) adalah probabilitas maksimum yang kita izinkan untuk melakukan Galat Tipe I (False Positive). Jika kita set $alpha = 0.05$, kita rela salah menuduh ada efek (padahal tidak ada) sebanyak 5% dari waktu eksperimen.
+ #strong[Soal:] Jelaskan konsep p-value dan bagaimana ia digunakan sebagai dasar penolakan $H_0$.
  - #strong[Solusi:] P-value adalah peluang mendapatkan data seperti yang kita amati (atau lebih ekstrim) jika $H_0$ benar. Jika p-value sangat kecil ($< alpha$), artinya data tersebut sangat mustahil terjadi secara kebetulan, sehingga kita menolak $H_0$.
+ #strong[Soal:] Apa itu Galat Tipe II ($beta$) dan bagaimana hubungannya dengan kekuatan uji (power of test)?
  - #strong[Solusi:] Galat Tipe II adalah kegagalan menolak $H_0$ padahal $H_1$ benar (gagal mendeteksi efek yang nyata). Kekuatan uji (Power) adalah $1 - beta$, yaitu kemampuan tes untuk mendeteksi efek jika efek itu benar-benar ada.
+ #strong[Soal:] Mengapa pengujian satu arah (one-tailed) terkadang lebih kuat daripada pengujian dua arah (two-tailed)?
  - #strong[Solusi:] Karena pada uji satu arah, seluruh wilayah kritis ($alpha$) dikumpulkan di satu sisi ekor distribusi. Ini membuat nilai kritis lebih mudah dicapai (lebih sensitif) untuk mendeteksi perubahan ke arah tertentu, namun butuh asumsi kuat bahwa perubahan ke arah sebaliknya tidak mungkin/tidak relevan.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-7>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah ISP mengklaim kecepatan rata-rata mereka adalah 100 Mbps. Dari sampel 50 user, didapat rata-rata 95 Mbps. Ujilah klaim ISP tersebut dengan $alpha = 0.05$.
  - #strong[Solusi:]
    - $H_0 : mu = 100$, $H_1 : mu eq.not 100$.
    - Hitung statistik t: $t = \( 95 - 100 \) \/ \( s \/ sqrt(50) \)$.
    - Bandingkan dengan $t_(k r i t i s)$. Jika $\| t \| > t_(k r i t i s)$ atau p-value \< 0.05, klaim ditolak (kecepatan tidak sama dengan 100).
+ #strong[Soal:] Perusahaan startup mengklaim fitur baru mereka meningkatkan durasi sesi user. Lakukan uji hipotesis untuk membandingkan rata-rata durasi sebelum dan sesudah fitur dirilis.
  - #strong[Solusi:] Gunakan Paired T-test (Uji t berpasangan) karena subjeknya sama (sebelum vs sesudah). $H_0 : mu_(d i f f) lt.eq 0$, $H_1 : mu_(d i f f) > 0$ (One-tailed). Jika p-value \< $alpha$, fitur terbukti meningkatkan durasi.
+ #strong[Soal:] Analisis apakah proporsi kegagalan transaksi di sistem pembayaran baru lebih kecil daripada sistem lama dengan tingkat signifikansi 1%.
  - #strong[Solusi:] Gunakan Z-test untuk dua proporsi.
    - $H_0 : p_(b a r u) gt.eq p_(l a m a)$. $H_1 : p_(b a r u) < p_(l a m a)$.
    - Jika Z-score berada di wilayah penolakan (kiri jauh) dengan $alpha = 0.01$, maka sistem baru terbukti lebih andal.
+ #strong[Soal:] Uji apakah rata-rata penggunaan data mahasiswa STI berbeda secara signifikan dari rata-rata mahasiswa program studi lain.
  - #strong[Solusi:] Gunakan Independent T-test (dua sampel bebas). Asumsikan varians bisa sama atau beda (Welch's t-test lebih aman). $H_0 : mu_(S T I) = mu_(L a i n)$. Cari p-value dua arah.
+ #strong[Soal:] Gunakan uji hipotesis untuk memvalidasi apakah sebuah koin adil atau berat sebelah berdasarkan 100 lemparan.
  - #strong[Solusi:] Uji proporsi satu sampel.
    - $H_0 : p = 0.5$. $H_1 : p eq.not 0.5$.
    - Jika dari 100 lemparan muncul 60 Heads, hitung Z-score. Jika p-value \> 0.05, kita tidak punya cukup bukti untuk mengatakan koin curang (terima $H_0$).
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-7>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Tulis skrip Python untuk menghitung nilai t-statistik dan p-value secara manual untuk uji satu sampel.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" [");#DecValTok("52");#NormalTok(", ");#DecValTok("55");#NormalTok(", ");#DecValTok("49");#NormalTok(", ");#DecValTok("58");#NormalTok(", ");#DecValTok("54");#NormalTok("]  ");],
  [#NormalTok("mu_0 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");#NormalTok("  ");],
  [#NormalTok("t_stat ");#OperatorTok("=");#NormalTok(" (np.mean(data) ");#OperatorTok("-");#NormalTok(" mu_0) ");#OperatorTok("/");#NormalTok(" (np.std(data, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(") ");#OperatorTok("/");#NormalTok(" np.sqrt(");#BuiltInTok("len");#NormalTok("(data)))  ");],
  [#NormalTok("p_val ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.t.cdf(");#BuiltInTok("abs");#NormalTok("(t_stat), df");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(data)");#OperatorTok("-");#DecValTok("1");#NormalTok("))  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"t-stat: ");#SpecialCharTok("{");#NormalTok("t_stat");#SpecialCharTok("}");#SpecialStringTok(", p-val: ");#SpecialCharTok("{");#NormalTok("p_val");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Gunakan #NormalTok("scipy.stats.ttest_ind"); untuk melakukan uji t dua sampel independen pada dataset performa server.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats  ");],
  [#NormalTok("server_A ");#OperatorTok("=");#NormalTok(" [");#DecValTok("120");#NormalTok(", ");#DecValTok("115");#NormalTok(", ");#DecValTok("122");#NormalTok(", ");#DecValTok("118");#NormalTok(", ");#DecValTok("119");#NormalTok("]  ");],
  [#NormalTok("server_B ");#OperatorTok("=");#NormalTok(" [");#DecValTok("110");#NormalTok(", ");#DecValTok("112");#NormalTok(", ");#DecValTok("108");#NormalTok(", ");#DecValTok("115");#NormalTok(", ");#DecValTok("111");#NormalTok("]  ");],
  [#NormalTok("stat, pval ");#OperatorTok("=");#NormalTok(" stats.ttest_ind(server_A, server_B)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P-value: ");#SpecialCharTok("{");#NormalTok("pval");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],
  [#CommentTok("# Jika pval < 0.05, performa berbeda signifikan.  ");],));
+ #strong[Soal:] Visualisasikan daerah penolakan pada kurva distribusi Normal untuk uji dua arah.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" norm  ");],
  [#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("1000");#NormalTok(")  ");],
  [#NormalTok("plt.plot(x, norm.pdf(x))  ");],
  [#NormalTok("plt.fill_between(x, ");#DecValTok("0");#NormalTok(", norm.pdf(x), where");#OperatorTok("=");#NormalTok("(x ");#OperatorTok(">");#NormalTok(" ");#FloatTok("1.96");#NormalTok(") ");#OperatorTok("|");#NormalTok(" (x ");#OperatorTok("<");#NormalTok(" ");#OperatorTok("-");#FloatTok("1.96");#NormalTok("), color");#OperatorTok("=");#StringTok("'red'");#NormalTok(")  ");],
  [#NormalTok("plt.title(");#StringTok("\"Daerah Penolakan (Alpha=0.05)\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
+ #strong[Soal:] Buat simulasi untuk menghitung probabilitas Galat Tipe I dengan melakukan pengujian berulang pada data yang ditarik dari populasi yang sama.
  - #strong[Solusi:]

  #Skylighting(([#CommentTok("# Simulasi A/A Testing  ");],
  [#NormalTok("false_positives ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok("  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok("):  ");],
  [#CommentTok("# Ambil 2 sampel dari populasi SAMA  ");],
  [#NormalTok("a ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("100");#NormalTok(")  ");],
  [#NormalTok("b ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("100");#NormalTok(")  ");],
  [#NormalTok("_, p ");#OperatorTok("=");#NormalTok(" stats.ttest_ind(a, b)  ");],
  [#ControlFlowTok("if");#NormalTok(" p ");#OperatorTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(": false_positives ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Type I Error Rate: ");#SpecialCharTok("{");#NormalTok("false_positives");#OperatorTok("/");#DecValTok("1000");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],
  [#CommentTok("# Hasil harus mendekati 0.05  ");],));
+ #strong[Soal:] Implementasikan uji proporsi dua sampel menggunakan pustaka statsmodels.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" statsmodels.stats.proportion ");#ImportTok("import");#NormalTok(" proportions_ztest  ");],
  [#CommentTok("# Sukses A=40/100, Sukses B=50/100  ");],
  [#NormalTok("count ");#OperatorTok("=");#NormalTok(" [");#DecValTok("40");#NormalTok(", ");#DecValTok("50");#NormalTok("]  ");],
  [#NormalTok("nobs ");#OperatorTok("=");#NormalTok(" [");#DecValTok("100");#NormalTok(", ");#DecValTok("100");#NormalTok("]  ");],
  [#NormalTok("stat, pval ");#OperatorTok("=");#NormalTok(" proportions_ztest(count, nobs)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P-value: ");#SpecialCharTok("{");#NormalTok("pval");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
]

= Minggu 09: Fungsi Variabel Acak
<minggu-09-fungsi-variabel-acak>
Function of Random Variables, PDF of new random variable

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image9.png"))
], caption: figure.caption(
position: bottom, 
[
“Kesalahan ukur arus itu kecil. Tapi daya listrik P = I²R. Kuadrat itu pengganda masalah. Jadi, kalau I random, P jadi random dengan karakter berbeda. Hari ini kamu belajar trik penting: kalau Y = g(X), bagaimana distribusi Y? Ini skill yang sering dipakai untuk batas toleransi keamanan komponen. Kita mau jawab: seberapa sering P melewati batas berbahaya? Ini statistik yang langsung nyambung ke keselamatan.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-6>
Menentukan distribusi probabilitas dari variabel baru Y yang merupakan fungsi dari variabel acak X (misal Y = g(X)).

== 2. Tipikal Problem
<tipikal-problem-6>
Diketahui distribusi kesalahan pengukuran arus listrik (X). Bagaimana distribusi kesalahan daya listrik (P), jika P = I^2 \* R?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-6>
Menggunakan metode transformasi atau fungsi pembangkit momen untuk menurunkan PDF dari P. Ini penting bagi insinyur untuk menentukan batas toleransi keamanan komponen agar tidak terbakar akibat fluktuasi daya.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-8>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 09!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 09!");],));
]
]
Week 09: Fungsi Variabel Acak dan Distribusi Bivariat

== Agenda Perkuliahan Minggu 9
<agenda-perkuliahan-minggu-9>
#strong[Topik:] Fungsi Variabel Acak & Distribusi Bivariat #strong[Tema Misi:] "Metamorphosis of Data: How Input Noise Becomes Output Risk"

=== Pertemuan 1: Senin (1 Jam) - The Intuition & The Warp
<pertemuan-1-senin-1-jam---the-intuition-the-warp>
#strong[Fokus:] Memahami bagaimana fungsi matematika mengubah bentuk distribusi data (Transformasi) dan hubungan antar dua variabel.

- #strong[00:00 - 00:10 | The Hook: "The Flaw of Averages 2.0"]
  - Masalah: "Jika arus listrik (I) rata-rata 10 Ampere (Normal), apakah Daya ($P = I^2 R$) juga berdistribusi Normal?"
  - Visual: Tunjukkan animasi input kurva lonceng yang melewati fungsi kuadrat, menghasilkan output yang "miring" (skewed).
  - Poin: Fungsi non-linear "memelintir" distribusi. Menggunakan rata-rata input saja untuk menghitung rata-rata output seringkali salah ($E \[ X^2 \] eq.not \( E \[ X \] \)^2$).
- #strong[00:10 - 00:30 | Live Demo: "Joint Distribution & Correlation"]
  - Dosen (Python): Generate dua variabel acak (misal: Server Load vs Latency).
  - Visualisasi: Gunakan #NormalTok("seaborn.jointplot"); untuk menampilkan Joint PDF (peta kontur) dan Marginal PDF (histogram di pinggir).
  - Konsep: Independen vs Berkorelasi. Tunjukkan bagaimana awan data menjadi "gepeng" saat korelasi tinggi.
- #strong[00:30 - 00:50 | Konsep: Transformasi Variabel]
  - Metode CDF: $F_Y \( y \) = P \( g \( X \) lt.eq y \)$.
  - Propagasi Ketidakpastian (Intro): Bagaimana noise pada sensor suhu merambat menjadi error pada prediksi cuaca.
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Uncertainty Architect". Mahasiswa harus memodelkan risiko sistem yang bergantung pada dua input acak yang saling berkorelasi.

=== Pertemuan 2: Rabu (2 Jam) - Transformation Lab
<pertemuan-2-rabu-2-jam---transformation-lab>
#strong[Fokus:] Simulasi Monte Carlo untuk menyelesaikan transformasi kompleks dan analisis Bivariat.

- #strong[00:00 - 00:20 | Micro-Lecture: Sum of Random Variables]
  - Masalah: Total waktu proses = Waktu Download (X) + Waktu Render (Y).
  - Konsep: Konvolusi (secara teori) vs Penjumlahan Vektor (secara komputasi). Jika X,Y Normal, X+Y Normal. Tapi jika X,Y Uniform? (Segitiga).
- #strong[00:20 - 01:10 | Pod Challenge: "Predicting Server Load"]
  - Skenario: Beban server dipengaruhi oleh User Count (X) dan Transaction Size (Y).
  - Model: Beban Total $Z = a X + b Y + c X Y$.
  - Tugas (Python):
    + Generate X dan Y (asumsikan berkorelasi positif, gunakan #NormalTok("numpy.random.multivariate_normal");).
    + Hitung Z untuk setiap titik data.
    + Plot distribusi Z. Apakah masih Normal?
    + Hitung peluang $Z >$ Kapasitas Kritis (Overload Probability).
- #strong[01:10 - 01:40 | Studi Kasus: Transformasi Skor ML (Logits to Probability)]
  - Membahas Aplikasi 11: Bagaimana mengubah raw score dari model regresi linear ($- oo \, oo$) menjadi probabilitas (0,1) menggunakan fungsi Sigmoid. Analisis dampaknya terhadap threshold keputusan.
- #strong[01:40 - 01:50 | Showcase]
  - Pods mempresentasikan grafik Joint Plot mereka dan strategi mitigasi risiko overload.
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Jika X dan Y independen, apa yang terjadi dengan Kovariansinya? Apakah sebaliknya berlaku?"

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-8>
=== 1. Konsep Dasar
<konsep-dasar-7>
- #strong[Variabel Acak Bivariat:] Pasangan (X,Y) dengan Joint PDF $f \( x \, y \)$. Peluang dihitung sebagai volume di bawah permukaan $f \( x \, y \)$.
- #strong[Marginal PDF:] Distribusi X sendirian, didapat dengan "membuang" (mengintegralkan) Y. $ f_X \( x \) = integral_(- oo)^oo f \( x \, y \) d y $
- #strong[Independensi:] X dan Y independen jika dan hanya jika $f \( x \, y \) = f_X \( x \) dot.op f_Y \( y \)$.
- #strong[Transformasi Variabel (Y=g(X)):] Jika $y = g \( x \)$ monoton, PDF baru dapat dicari dengan: $ f_Y \( y \) = f_X \( g^(- 1) \( y \) \) lr(|frac(d, d y) g^(- 1) \( y \)|) $ Namun, pendekatan simulasi (Monte Carlo) lebih disukai di IT untuk fungsi kompleks.

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-7>
- #strong[Propagasi Error (FOSM):] Mengestimasi variansi output model (Y) berdasarkan variansi input (X). Misal: Prediksi bandwidth (Y) berdasarkan jumlah user (X) yang estimasinya punya error.
- #strong[Load Balancing:] Menganalisis distribusi beban gabungan pada dua server. Jika beban server A tinggi, apakah beban server B cenderung tinggi juga? (Korelasi positif buruk untuk redundansi).
- #strong[Machine Learning:] Transformasi fitur (misal: Log-transform pada data skewed seperti income atau latency) agar lebih mendekati Normal sebelum dilatih.

=== 3. Komputasi (Python)
<komputasi-python-7>
- #strong[Multivariate Normal:] #NormalTok("np.random.multivariate_normal(mean, cov, size)"); untuk membangkitkan data berkorelasi.
- #strong[Correlation Matrix:] #NormalTok("np.corrcoef(x, y)"); atau #NormalTok("df.corr()");.
- #strong[Visualisasi:] #NormalTok("seaborn.jointplot(kind='kde')"); atau #NormalTok("kind='hex'"); untuk melihat densitas gabungan.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-8>
#strong[Judul:] Week 9 Mission: The Risk Propagator

#strong[Deskripsi:] Mahasiswa menganalisis risiko finansial cloud computing. Biaya total bulanan bergantung pada Storage Used (GB) dan Compute Hours (CPU), di mana keduanya adalah variabel acak yang tidak pasti dan berkorelasi.

#strong[Set Soal (Notebook):] 1. #strong[Data Generation (25 poin):] - Buat 10.000 sampel data bivariat (S,C) dimana S (Storage) dan C (Compute) memiliki korelasi $rho = 0.7$. - Tampilkan Joint Plot untuk membuktikan korelasi. 2. #strong[Transformation (25 poin):] - Fungsi Biaya: $C o s t = 0.1 times S + 0.5 times C + 0.01 times \( S times C \)$ (Termasuk biaya transfer data interaksi $S times C$). - Hitung array Cost dan plot histogramnya. 3. #strong[Analytical Check (20 poin):] - Hitung Mean dan Variansi dari Cost secara empiris. - Bandingkan dengan properti ekspektasi: $E \[ S + C \] = E \[ S \] + E \[ C \]$. Apakah $E \[ S times C \] = E \[ S \] times E \[ C \]$? (Hint: Ingat korelasi). 4. #strong[Decision Making (30 poin):] - Tentukan Budget bulanan agar peluang Overbudget $lt.eq 5 %$. - Apa yang terjadi dengan risiko Overbudget jika kita berhasil membuat S dan C menjadi independen ($rho = 0$)? Simulasikan dan jelaskan.

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-7>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-8>
+ #strong[Soal:] Apa yang dimaksud dengan fungsi padat probabilitas gabungan (joint PDF) dan bagaimana cara mendapatkan PDF marginal darinya?
  - #strong[Solusi:] Joint PDF $f \( x \, y \)$ mendeskripsikan peluang densitas bahwa variabel acak X bernilai x DAN Y bernilai y secara bersamaan. PDF marginal (misal $f_X \( x \)$) didapatkan dengan "menjumlahkan" (mengintegralkan) peluang gabungan terhadap seluruh kemungkinan nilai variabel lainnya (Y). Rumusnya: $f_X \( x \) = integral_(- oo)^oo f \( x \, y \) d y$.
+ #strong[Soal:] Jelaskan konsep independensi antara dua variabel acak dalam konteks fungsi probabilitas gabungan.
  - #strong[Solusi:] Dua variabel acak X dan Y dikatakan independen jika dan hanya jika fungsi densitas gabungan mereka dapat difaktorkan menjadi perkalian fungsi densitas marginal masing-masing untuk setiap x dan y. Secara matematis: $f \( x \, y \) = f_X \( x \) dot.op f_Y \( y \)$.
+ #strong[Soal:] Apa perbedaan antara kovariansi dan korelasi dalam mengukur hubungan antara dua variabel?
  - #strong[Solusi:] Kovariansi mengukur arah hubungan linear (positif/negatif) tetapi nilainya bergantung pada satuan data (misal: meter vs cm). Korelasi (Pearson) adalah versi kovariansi yang dinormalisasi (dibagi standar deviasi masing-masing), sehingga nilainya selalu antara -1 hingga +1 dan bebas dimensi, menunjukkan kekuatan dan arah hubungan linear.
+ #strong[Soal:] Bagaimana teknik transformasi variabel digunakan untuk menemukan distribusi dari $Y = X^2$?
  - #strong[Solusi:] Jika X adalah variabel acak dengan PDF $f_X \( x \)$, distribusi $Y = X^2$ tidak bisa langsung didapat dengan mengkuadratkan PDF. Kita harus menggunakan metode perubahan variabel yang melibatkan turunan fungsi invers (Jacobian). Untuk $Y = X^2$, kita perlu memperhitungkan bahwa dua nilai X (+x dan -x) memetakan ke satu nilai Y.
+ #strong[Soal:] Jelaskan konsep ekspektasi kondisional $E \[ Y \| X \]$ dan kegunaannya dalam prediksi sederhana.
  - #strong[Solusi:] $E \[ Y \| X = x \]$ adalah rata-rata nilai Y ketika kita tahu bahwa X bernilai x. Ini adalah dasar dari regresi dan prediksi. Dalam konteks prediksi, $E \[ Y \| X \]$ adalah "tebakan terbaik" (prediktor yang meminimalkan MSE) untuk nilai Y jika informasi X tersedia.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-8>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Analisis hubungan antara latensi jaringan (X) dan ukuran paket (Y) pada server cloud.
  - #strong[Solusi:] Kita memodelkan (X,Y) sebagai distribusi bivariat. Biasanya terdapat korelasi positif: paket yang lebih besar (Y tinggi) cenderung menyebabkan latensi lebih tinggi (X tinggi) karena waktu transmisi dan pemrosesan. Analisis Joint PDF membantu mendeteksi anomali, misal paket kecil tapi latensi tinggi (indikasi congestion).
+ #strong[Soal:] Jika X dan Y adalah waktu proses di dua server independen, tentukan distribusi dari waktu total $T = X + Y$.
  - #strong[Solusi:] Karena independen, PDF dari jumlah $T = X + Y$ adalah konvolusi dari PDF X dan PDF Y: $f_T \( t \) = integral f_X \( x \) f_Y \( t - x \) d x$. Jika keduanya Normal, T juga Normal.
+ #strong[Soal:] Hitung korelasi antara jumlah jam belajar mahasiswa STI dan nilai ujian akhir mereka berdasarkan data sampel.
  - #strong[Solusi:] Gunakan rumus korelasi sampel Pearson: $r = frac(sum \( x_i - macron(x) \) \( y_i - macron(y) \), sqrt(sum \( x_i - macron(x) \)^2 sum \( y_i - macron(y) \)^2))$. Nilai mendekati +1 menunjukkan hubungan linear positif kuat.
+ #strong[Soal:] Tentukan probabilitas gabungan bahwa sebuah request database memakan waktu $< 10$ ms DAN ukuran hasilnya $> 1$ MB.
  - #strong[Solusi:] Kita perlu mengintegralkan Joint PDF $f \( t \, s \)$ pada daerah $0 < t < 10$ dan $s > 1$. $P \( upright("Cepat & Besar") \) = integral_1^oo integral_0^10 f \( t \, s \) thin d t thin d s$.
+ #strong[Soal:] Evaluasi efektivitas algoritma load balancing dengan menganalisis distribusi bivariat beban pada dua node server.
  - #strong[Solusi:] Idealnya, beban pada Node A dan Node B harus memiliki korelasi negatif atau nol jika balancer bekerja sempurna membagi beban. Jika korelasinya positif tinggi (keduanya naik/turun bersamaan), berarti sistem rentan terhadap lonjakan trafik global (common mode failure) dan balancer mungkin hanya membagi rata, bukan menyeimbangkan secara dinamis.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-8>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Gunakan numpy untuk menghitung matriks kovariansi dan matriks korelasi dari dataset bivariat.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" np.array([[");#DecValTok("9");#NormalTok(", ");#DecValTok("10");#NormalTok("], [");#DecValTok("11");#NormalTok(", ");#DecValTok("12");#NormalTok("], [");#DecValTok("13");#NormalTok(", ");#DecValTok("14");#NormalTok("]]) ");#CommentTok("# Kolom X, Kolom Y  ");],
  [#NormalTok("cov_matrix ");#OperatorTok("=");#NormalTok(" np.cov(data, rowvar");#OperatorTok("=");#VariableTok("False");#NormalTok(")  ");],
  [#NormalTok("corr_matrix ");#OperatorTok("=");#NormalTok(" np.corrcoef(data, rowvar");#OperatorTok("=");#VariableTok("False");#NormalTok(")  ");],
  [#BuiltInTok("print");#NormalTok("(");#StringTok("\"Cov:");#CharTok("\\n");#StringTok("\"");#NormalTok(", cov_matrix)  ");],
  [#BuiltInTok("print");#NormalTok("(");#StringTok("\"Corr:");#CharTok("\\n");#StringTok("\"");#NormalTok(", corr_matrix)  ");],));
+ #strong[Soal:] Visualisasikan distribusi gabungan dua variabel acak menggunakan jointplot dari pustaka seaborn.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" seaborn ");#ImportTok("as");#NormalTok(" sns, pandas ");#ImportTok("as");#NormalTok(" pd, numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("'X'");#NormalTok(": np.random.randn(");#DecValTok("100");#NormalTok("), ");#StringTok("'Y'");#NormalTok(": np.random.randn(");#DecValTok("100");#NormalTok(")})  ");],
  [#NormalTok("sns.jointplot(data");#OperatorTok("=");#NormalTok("data, x");#OperatorTok("=");#StringTok("'X'");#NormalTok(", y");#OperatorTok("=");#StringTok("'Y'");#NormalTok(", kind");#OperatorTok("=");#StringTok("'kde'");#NormalTok(")  ");],
  [#CommentTok("# Menampilkan kontur densitas  ");],));
+ #strong[Soal:] Implementasikan fungsi untuk menghitung PDF marginal secara numerik dari tabel probabilitas gabungan diskrit.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#CommentTok("# Tabel P(X,Y): Baris=X, Kolom=Y  ");],
  [#NormalTok("joint_prob ");#OperatorTok("=");#NormalTok(" np.array([[");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.2");#NormalTok("], [");#FloatTok("0.3");#NormalTok(", ");#FloatTok("0.4");#NormalTok("]])  ");],
  [#NormalTok("marginal_X ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(joint_prob, axis");#OperatorTok("=");#DecValTok("1");#NormalTok(") ");#CommentTok("# Jumlahkan per baris  ");],
  [#BuiltInTok("print");#NormalTok("(");#StringTok("\"P(X):\"");#NormalTok(", marginal_X) ");#CommentTok("# Output: [0.3, 0.7]  ");],));
+ #strong[Soal:] Simulasikan distribusi dari jumlah dua variabel acak Uniform yang independen dan tunjukkan konvergensinya ke bentuk segitiga.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("10000");#NormalTok(")  ");],
  [#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("10000");#NormalTok(")  ");],
  [#NormalTok("z ");#OperatorTok("=");#NormalTok(" x ");#OperatorTok("+");#NormalTok(" y  ");],
  [#NormalTok("plt.hist(z, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")  ");],
  [#NormalTok("plt.title(");#StringTok("\"Sum of 2 Uniforms = Triangle\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
+ #strong[Soal:] Tulis skrip untuk melakukan transformasi variabel acak menggunakan metode invers transformasi CDF.
  - #strong[Solusi:]

  #Skylighting(([#CommentTok("# Contoh: Transformasi Uniform(0,1) ke Eksponensial(lambda=1)  ");],
  [#CommentTok("# F(x) = 1 - e^-x  =>  x = -ln(1-u)  ");],
  [#NormalTok("u ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("1000");#NormalTok(")  ");],
  [#NormalTok("x_exp ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("-");#NormalTok("np.log(");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" u)  ");],
  [#NormalTok("plt.hist(x_exp, bins");#OperatorTok("=");#DecValTok("20");#NormalTok(")");#OperatorTok(";");#NormalTok(" plt.show()  ");],));
]

= Minggu 10: Distribusi Sampling dan Teorema Limit Pusat
<minggu-10-distribusi-sampling-dan-teorema-limit-pusat>
Sampling Distribution, Central Limit Theorem (CLT)

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image10.png"))
], caption: figure.caption(
position: bottom, 
[
“Tulisan ‘maks 15 orang' itu ngarang atau sains? Kalau berat orang random, total berat 20 orang juga random. CLT bilang: total/rata-rata sampel cenderung normal kalau n cukup besar. Jadi kita bisa hitung peluang overload. Hari ini kamu belajar ‘sains di balik aturan': bukan sekadar angka, tapi probabilitas risiko. Output akhirnya: rekomendasi batas penumpang yang membuat risiko overload mendekati nol.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-7>
Distribusi dari rata-rata sampel akan mendekati Normal jika ukuran sampel besar (n \>= 30), terlepas dari distribusi populasinya.

== 2. Tipikal Problem
<tipikal-problem-7>
Sebuah lift memiliki kapasitas beban maksimum. Jika berat badan rata-rata penumpang adalah variabel acak, berapa peluang 20 orang penumpang melebihi kapasitas lift?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-7>
Menggunakan CLT untuk memodelkan total berat penumpang sebagai distribusi Normal. Insinyur menggunakan ini untuk menetapkan batas aman jumlah penumpang agar peluang kelebihan beban mendekati nol.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-9>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 10!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 10!");],));
]
]
Week 10: Distribusi Sampling dan Teorema Limit Pusat

== Agenda Perkuliahan Minggu 10
<agenda-perkuliahan-minggu-10>
#strong[Topik:] Distribusi Sampling & Teorema Limit Pusat (CLT) #strong[Tema Misi:] "Order from Chaos: The Ultimate Statistical Cheat Code"

=== Pertemuan 1: Senin (1 Jam) - The Magic Trick
<pertemuan-1-senin-1-jam---the-magic-trick>
#strong[Fokus:] Membangun intuisi visual bahwa rata-rata sampel selalu membentuk lonceng (Normal), tidak peduli seberapa aneh data aslinya.

- #strong[00:00 - 00:10 | The Hook: "Misteri Lift & Sumo"]
  - Masalah: Lift tertulis "Max 15 Orang / 1000kg". Rata-rata berat manusia 65kg. $15 times 65 = 975$kg. Aman?
  - Provokasi: "Bagaimana jika 15 orang itu adalah tim Sumo? Atau anak TK? Seberapa sering lift overload?"
  - Poin: Kita tidak bisa memprediksi berat 1 orang (acak), tapi kita bisa memprediksi total berat 15 orang dengan sangat presisi.
- #strong[00:10 - 00:30 | Live Simulation: "From Chaos to Order"]
  - Dosen (Python Demo):
    + Tampilkan distribusi populasi yang "jelek" (misal: Distribusi Uniform/Kotak, atau Eksponensial yang sangat miring).
    + Ambil 1 sampel $arrow.r$ Plot (Masih acak).
    + Ambil rata-rata dari 5 sampel $arrow.r$ Plot (Mulai berkumpul di tengah).
    + Ambil rata-rata dari 30 sampel $arrow.r$ Plot (BUM! Muncul Kurva Lonceng Sempurna).
  - Konsep: Inilah Teorema Limit Pusat (CLT). "Cheat Code" statistik yang mengizinkan kita menggunakan rumus Normal untuk hampir semua masalah jika $n gt.eq 30$.
- #strong[00:30 - 00:50 | Konsep: Standard Error (SE)]
  - Jelaskan bedanya $sigma$ (sebaran individu) vs $sigma \/ sqrt(n)$ (sebaran rata-rata).
  - Semakin banyak data ($n$ naik), kurva semakin kurus (error makin kecil).
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Safety Engineer". Mahasiswa harus menentukan batas aman kapasitas server/lift menggunakan simulasi CLT.

=== Pertemuan 2: Rabu (2 Jam) - Simulation Lab
<pertemuan-2-rabu-2-jam---simulation-lab-2>
#strong[Fokus:] Menggunakan Python untuk membuktikan CLT dan menghitung risiko sistem.

- #strong[00:00 - 00:20 | Micro-Lecture: Law of Large Numbers vs.~CLT]
  - LLN: Rata-rata mendekati target (Akurasi).
  - CLT: Rata-rata membentuk pola lonceng (Presisi/Distribusi).
- #strong[00:20 - 01:10 | Pod Challenge: "Capacity Planning Simulator"]
  - Skenario: Anda mendesain microservice. Waktu proses per request berdistribusi Eksponensial (sangat miring, banyak request cepat, sedikit yang lambat sekali).
  - Tugas (Python):
    + Generate populasi latency eksponensial (10.000 data).
    + Ambil sampel n=5, n=30, n=100. Plot histogram rata-ratanya.
    + Buktikan bahwa pada n=30, distribusinya sudah Normal.
    + Hitung peluang rata-rata latency $> 200$ms. Bandingkan hasil hitungan rumus CLT vs hasil Simulasi.
- #strong[01:10 - 01:40 | Deep Dive: Bootstrap (Modern Sampling)]
  - Masalah: "Bagaimana jika kita cuma punya 1 sampel kecil dan tidak tahu populasinya?"
  - Teknik: Resampling (Bootstrap). Teknik komputasi modern untuk membuat confidence interval tanpa rumus rumit.
- #strong[01:40 - 01:50 | Showcase & Debat]
  - "Apakah CLT berlaku jika datanya punya outlier ekstrim?" (Diskusi tentang keterbatasan CLT di dunia nyata).
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Jika kamu ingin memperkecil error estimasi menjadi setengahnya, berapa kali lipat kamu harus memperbanyak sampel?" (Jawab: 4 kali lipat, karena akar kuadrat).

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-9>
=== 1. Konsep Dasar
<konsep-dasar-8>
- #strong[Distribusi Sampling:] Distribusi probabilitas dari suatu statistik (misal: rata-rata $macron(X)$) yang diperoleh dari banyak sampel.
- #strong[Teorema Limit Pusat (CLT):] Menyatakan bahwa jika ukuran sampel ($n$) cukup besar ($n gt.eq 30$), distribusi rata-rata sampel akan mendekati Distribusi Normal, terlepas dari bentuk distribusi populasi aslinya.
  - Mean sampling = $mu$ (Mean Populasi).
  - Standar Deviasi sampling (Standard Error) = $sigma \/ sqrt(n)$.
- #strong[Standard Error (SE):] Mengukur seberapa akurat rata-rata sampel merepresentasikan rata-rata populasi.

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-8>
- #strong[Capacity Planning:] Menentukan batas aman. Misal, jika berat rata-rata paket data adalah 1KB (variansi tinggi), berapa peluang total 1000 paket melebihi bandwidth 1.2MB? CLT memungkinkan kita menghitung ini menggunakan Z-score.
- #strong[Quality Control (Batch Testing):] Menguji sekumpulan chip. Jika kita mengambil sampel 50 chip, kita bisa memprediksi kualitas rata-rata batch tersebut dengan presisi tinggi.
- #strong[A/B Testing:] Membandingkan rata-rata dua kelompok user. Asumsi Normalitas pada uji-t didasarkan pada CLT karena jumlah user biasanya banyak.

=== 3. Komputasi (Python)
<komputasi-python-8>
- #strong[Sampling:] #NormalTok("numpy.random.choice(population, size=n)"); untuk mengambil sampel.

- #strong[Looping Simulation:]

  #Skylighting(([#NormalTok("sample_means ");#OperatorTok("=");#NormalTok(" []");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok("):");],
  [#NormalTok("    sample ");#OperatorTok("=");#NormalTok(" np.random.exponential(scale");#OperatorTok("=");#DecValTok("10");#NormalTok(", size");#OperatorTok("=");#DecValTok("30");#NormalTok(")");],
  [#NormalTok("    sample_means.append(np.mean(sample))");],));

- #strong[Visualisasi:] Gunakan #NormalTok("plt.hist(sample_means, bins=30)"); untuk melihat bentuk lonceng.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-9>
#strong[Judul:] Week 10 Mission: The Chaos Tamer - Validating CLT

#strong[Deskripsi:] Mahasiswa diberikan dataset "durasi main game" yang distribusinya sangat miring (banyak pemain sebentar, sedikit pemain hardcore). Tugas mereka adalah membuktikan bahwa rata-rata durasi bermain harian tetap mengikuti pola Normal.

#strong[Set Soal (Notebook):] 1. #strong[Populasi Aneh (20 poin):] Buat distribusi populasi Gamma atau LogNormal. Tampilkan histogramnya (harus tidak simetris). 2. #strong[Efek Ukuran Sampel (30 poin):] - Lakukan sampling berulang (1000 kali) dengan n=5, n=30, dan n=100. - Plot distribusi rata-rata sampel untuk ketiga skenario tersebut secara overlay. - Jelaskan perubahannya di Markdown (Bentuk & Lebar kurva). 3. #strong[Standard Error Check (20 poin):] - Hitung standar deviasi dari array #NormalTok("sample_means"); (Empiris). - Hitung $sigma \/ sqrt(n)$ teoritis. Bandingkan apakah hasilnya dekat. 4. #strong[Real-world Prediction (30 poin):] - Jika batas kuota server adalah rata-rata 55 menit/user. Hitung peluang sampel 50 user melampaui batas ini menggunakan pendekatan Normal (CLT).

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-8>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-9>
+ #strong[Soal:] Apa perbedaan mendasar antara parameter populasi dan statistik sampel?
  - #strong[Solusi:] Parameter populasi adalah nilai numerik konstan yang mendeskripsikan karakteristik seluruh populasi (misal: $mu$ atau $sigma$), biasanya nilainya tidak diketahui. Statistik sampel adalah nilai variabel yang dihitung dari sekumpulan data sampel (misal: $macron(x)$ atau $s$) yang digunakan untuk mengestimasi parameter populasi.
+ #strong[Soal:] Mengapa distribusi sampling dari rata-rata sampel cenderung menjadi Normal meskipun populasi aslinya tidak Normal?
  - #strong[Solusi:] Ini adalah inti dari Teorema Limit Pusat (CLT). Penjumlahan (atau rata-rata) dari banyak variabel acak independen menyebabkan efek-efek ekstrim dari masing-masing data saling meniadakan, sehingga hasil agregatnya memusat di sekitar mean dan membentuk pola lonceng simetris (Normal).
+ #strong[Soal:] Jelaskan makna dari Galat Baku (Standard Error) dan bagaimana hubungannya dengan ukuran sampel.
  - #strong[Solusi:] Standard Error (SE) adalah standar deviasi dari distribusi sampling rata-rata ($sigma_(macron(x))$). Ia mengukur seberapa jauh rata-rata sampel mungkin menyimpang dari rata-rata populasi sebenarnya. Hubungannya terbalik dengan akar ukuran sampel (SE=$sigma \/ sqrt(n)$); semakin besar sampel, semakin kecil error-nya.
+ #strong[Soal:] Apa peran Teorema Limit Pusat dalam menjustifikasi penggunaan uji-z pada sampel besar?
  - #strong[Solusi:] Uji-z memerlukan asumsi bahwa data berdistribusi Normal. CLT menjamin bahwa untuk sampel besar ($n gt.eq 30$), distribusi rata-rata sampel akan mendekati Normal terlepas dari distribusi asli datanya. Ini membenarkan penggunaan tabel Z untuk menghitung probabilitas pada sampel besar.
+ #strong[Soal:] Bagaimana bias pemilihan sampel dapat merusak validitas distribusi sampling?
  - #strong[Solusi:] Distribusi sampling dan CLT berasumsi bahwa sampel diambil secara acak (random sampling). Jika ada bias (misal: hanya mengambil sampel mahasiswa yang pintar), maka rata-rata sampel ($macron(x)$) tidak akan memusat di sekitar rata-rata populasi ($mu$), melainkan di sekitar nilai yang bias, membuat seluruh estimasi tidak valid.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-9>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Rata-rata waktu loading halaman web adalah 3 detik dengan standar deviasi 1 detik. Jika diambil sampel 100 kunjungan, berapa probabilitas rata-rata waktu loading sampel lebih dari 3,2 detik?
  - #strong[Solusi:]
    - Diketahui: $mu = 3 \, sigma = 1 \, n = 100$.
    - SE=$sigma \/ sqrt(n) = 1 \/ 10 = 0.1$.
    - Z-score: $Z = \( 3.2 - 3 \) \/ 0.1 = 2$.
    - $P \( macron(X) > 3.2 \) = P \( Z > 2 \) approx 0.0228$ (atau 2.28%).
+ #strong[Soal:] Sebuah perusahaan pengiriman mengklaim berat paket rata-rata 5kg. Jika seorang inspektur mengambil sampel 36 paket, tentukan rentang rata-rata sampel yang masuk akal menurut CLT.
  - #strong[Solusi:] Menurut CLT, 95% rata-rata sampel akan berada dalam rentang $mu plus.minus 2 times S E$. Asumsikan $sigma$ diketahui (atau diestimasi), misal $sigma = 1$ kg.
    - SE=$1 \/ sqrt(36) = 1 \/ 6 approx 0.167$.
    - Rentang wajar: $5 plus.minus 2 \( 0.167 \) = \[ 4.67 \, 5.33 \]$ kg.
+ #strong[Soal:] Analisis probabilitas proporsi pemilih dalam survei opini teknologi jika ukuran sampel adalah 400 orang dan proporsi populasi sebenarnya adalah 0,5.
  - #strong[Solusi:] Distribusi proporsi sampel ($hat(p)$) juga mengikuti CLT (mendekati Normal) dengan $mu_(hat(p)) = p = 0.5$ dan SE=$sqrt(p \( 1 - p \) \/ n)$.
    - SE=$sqrt(0.5 times 0.5 \/ 400) = sqrt(0.000625) = 0.025$.
    - Probabilitas hasil survei akan sangat dekat dengan 0.5 (dalam rentang $0.5 plus.minus 0.05$ dengan keyakinan 95%).
+ #strong[Soal:] Gunakan distribusi sampling untuk mengevaluasi akurasi sensor suhu yang rata-rata memiliki error nol tetapi variansi tertentu.
  - #strong[Solusi:] Karena rata-rata error nol ($mu = 0$), sensor tidak bias. Akurasi ditingkatkan dengan mengambil rata-rata dari banyak pembacaan ($n$). Variansi rata-rata pembacaan akan berkurang sebesar faktor $1 \/ n$ ($V a r \( macron(X) \) = sigma^2 \/ n$). Semakin banyak sampel, hasil rata-rata semakin mendekati suhu asli (0 error).
+ #strong[Soal:] Estimasi total berat beban pada lift jika berat 20 orang yang masuk adalah variabel acak independen dengan mean dan variansi yang diketahui.
  - #strong[Solusi:] Misal berat orang $mu = 70 \, sigma = 15$.
    - Berat Total $T = X_1 + . . . + X_20$.
    - Mean Total: $E \[ T \] = 20 times 70 = 1400$.
    - Variansi Total: $V a r \( T \) = 20 times 15^2$. Std Dev Total = $sqrt(20) times 15 approx 67$.
    - Gunakan Distribusi Normal $N \( 1400 \, 67^2 \)$ untuk estimasi beban.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-9>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Buat simulasi Python yang mengambil sampel berulang kali dari distribusi non-Normal (misal: Eksponensial) dan plot distribusi rata-rata sampelnya untuk menunjukkan bentuk Normal.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np, matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#NormalTok("means ");#OperatorTok("=");#NormalTok(" [np.mean(np.random.exponential(");#DecValTok("10");#NormalTok(", ");#DecValTok("30");#NormalTok(")) ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok(")]  ");],
  [#NormalTok("plt.hist(means, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")  ");],
  [#NormalTok("plt.title(");#StringTok("\"Distribusi Rata-rata Sampel (n=30) -> Normal\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
+ #strong[Soal:] Tulis skrip untuk menghitung Standard Error dari data sampel yang diberikan.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("data ");#OperatorTok("=");#NormalTok(" [");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("7");#NormalTok("] ");#CommentTok("# Contoh data  ");],
  [#NormalTok("se ");#OperatorTok("=");#NormalTok(" np.std(data, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(") ");#OperatorTok("/");#NormalTok(" np.sqrt(");#BuiltInTok("len");#NormalTok("(data))  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Standard Error: ");#SpecialCharTok("{");#NormalTok("se");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Visualisasikan bagaimana lebar distribusi sampling mengecil seiring bertambahnya ukuran sampel n menggunakan matplotlib.
  - #strong[Solusi:]

  #Skylighting(([#ControlFlowTok("for");#NormalTok(" n ");#KeywordTok("in");#NormalTok(" [");#DecValTok("8");#NormalTok(", ");#DecValTok("30");#NormalTok(", ");#DecValTok("100");#NormalTok("]:  ");],
  [#NormalTok("means ");#OperatorTok("=");#NormalTok(" [np.mean(np.random.randn(n)) ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok(")]  ");],
  [#NormalTok("plt.hist(means, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(", label");#OperatorTok("=");#SpecialStringTok("f'n=");#SpecialCharTok("{");#NormalTok("n");#SpecialCharTok("}");#SpecialStringTok("'");#NormalTok(")  ");],
  [#NormalTok("plt.legend()");#OperatorTok(";");#NormalTok(" plt.show()  ");],));
+ #strong[Soal:] Implementasikan fungsi untuk menghitung probabilitas rata-rata sampel berada dalam rentang tertentu menggunakan scipy.stats.norm.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" norm  ");],
  [#KeywordTok("def");#NormalTok(" prob_sample_mean(mu, sigma, n, low, high):  ");],
  [#NormalTok("se ");#OperatorTok("=");#NormalTok(" sigma ");#OperatorTok("/");#NormalTok(" np.sqrt(n)  ");],
  [#ControlFlowTok("return");#NormalTok(" norm.cdf(high, mu, se) ");#OperatorTok("-");#NormalTok(" norm.cdf(low, mu, se)  ");],));
+ #strong[Soal:] Gunakan metode bootstrapping sederhana untuk mengestimasi distribusi sampling dari median sebuah dataset kecil.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("data ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("8");#NormalTok(", ");#DecValTok("11");#NormalTok(", ");#DecValTok("12");#NormalTok(", ");#DecValTok("9");#NormalTok(", ");#DecValTok("14");#NormalTok(", ");#DecValTok("15");#NormalTok("]) ");#CommentTok("# Dataset kecil  ");],
  [#NormalTok("medians ");#OperatorTok("=");#NormalTok(" []  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok("):  ");],
  [#CommentTok("# Resample with replacement  ");],
  [#NormalTok("resample ");#OperatorTok("=");#NormalTok(" np.random.choice(data, size");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(data), replace");#OperatorTok("=");#VariableTok("True");#NormalTok(")  ");],
  [#NormalTok("medians.append(np.median(resample))  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Bootstrap Median SE: ");#SpecialCharTok("{");#NormalTok("np");#SpecialCharTok(".");#NormalTok("std(medians)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
]

= Minggu 11: Estimasi
<minggu-11-estimasi>
Estimation, Confidence Interval

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image11.png"))
], caption: figure.caption(
position: bottom, 
[
“Kamu tes 100 chip. Rata-rata kecepatannya sekian. Tapi dunia nyata bertanya: ‘rata-rata produksi sebenarnya berapa?' Kalau kamu hanya kasih satu angka, kamu seperti menebak. Confidence Interval itu cara berkata jujur: ‘kami yakin di rentang ini'. Hari ini kamu belajar bedanya point estimate dan interval estimate, lalu membuat kalimat klaim spesifikasi yang bisa dipertanggungjawabkan. Statistik = etika + sains.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-8>
Estimasi titik (point estimate) dan Estimasi Interval (Confidence Interval) untuk memperkirakan parameter populasi (rata-rata atau proporsi).

== 2. Tipikal Problem
<tipikal-problem-8>
Berdasarkan survei sampel terhadap 100 chip komputer, ditemukan rata-rata kecepatan pemrosesan tertentu. Berapa rata-rata kecepatan sebenarnya dari seluruh produksi pabrik?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-8>
Membangun Confidence Interval (misal 95% CI). Pabrik dapat mengklaim spesifikasi produk dengan keyakinan statistik yang dapat dipertanggungjawabkan kepada konsumen.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-10>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 11!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 11!");],));
]
]
Week 11: Estimasi Statistik dan Interval Kepercayaan

== Agenda Perkuliahan Minggu 11
<agenda-perkuliahan-minggu-11>
#strong[Topik:] Estimasi Parameter & Interval Kepercayaan #strong[Tema Misi:] "The Confidence Game: Don't Just Guess, Estimate!"

=== Pertemuan 1: Senin (1 Jam) - The Intuition & The Sniper
<pertemuan-1-senin-1-jam---the-intuition-the-sniper>
#strong[Fokus:] Memahami bedanya 'tebakan tunggal' (Point Estimate) yang berisiko dengan 'rentang aman' (Interval) yang bisa dipertanggungjawabkan.

- #strong[00:00 - 00:10 | The Hook: "Margin of Error di E-Sports/Pemilu"]
  - Masalah: Tampilkan hasil survei atau win-rate tim E-Sports: "Tim A menang 55% $plus.minus$ 3%".
  - Pertanyaan: "Apa artinya $plus.minus$ 3%? Apakah kalau mereka main 100 kali, pasti menang 55 kali? Atau bisa 52? Atau 58?"
  - Poin: Angka tunggal (55%) itu pasti salah (peluang kena titik tepat itu 0). Kita butuh "Jaring" (Interval) untuk menangkap kebenaran.
- #strong[00:10 - 00:30 | Live Simulation: "Catching the True Mean"]
  - Dosen (Python Demo):
    + Set populasi tersembunyi (misal: Rata-rata tinggi mahasiswa Indonesia = 165cm).
    + Ambil 10 sampel acak, hitung rata-rata ($macron(x)$).
    + Buat rentang $macron(x) plus.minus upright("Margin")$. Cek: Apakah 165cm tertangkap di dalam rentang?
    + Ulangi 100 kali. Tunjukkan bahwa dengan rumus yang benar, 95 dari 100 jaring akan menangkap ikan. Inilah 95% Confidence Level.
- #strong[00:30 - 00:50 | Konsep: T-Distribution vs Normal]
  - Kapan pakai Z (Normal)? Hanya kalau kita tahu standar deviasi populasi ($sigma$)-yang mana hampir mustahil di dunia nyata.
  - Perkenalkan T-Student: Distribusi yang "lebih gemuk" ekornya untuk mengakomodasi ketidaktahuan kita saat sampel sedikit ($n < 30$).
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Quality Assurance Auditor". Mahasiswa harus memvalidasi klaim spesifikasi produk hardware dari data sampel terbatas.

=== Pertemuan 2: Rabu (2 Jam) - Audit Lab
<pertemuan-2-rabu-2-jam---audit-lab>
#strong[Fokus:] Menggunakan Python untuk membuat klaim bisnis yang didukung data (Bootstrap & T-Interval).

- #strong[00:00 - 00:20 | Micro-Lecture: Bootstrap (Cara Modern)]
  - Konsep: Rumus matematika itu rumit. Cara Gen-Z/Data Scientist: Resampling.
  - Demo: Ambil data sampel, acak ulang (kocok) 1000x, hitung rata-rata tiap kocokan, ambil persentil ke-2.5 dan ke-97.5. Voila! Jadi 95% CI tanpa rumus t-tabel.
- #strong[00:20 - 01:10 | Pod Challenge: "The Chip Spec Scandal"]
  - Skenario: Vendor baru mengklaim prosesor mereka punya kecepatan rata-rata 3.2 GHz. Anda membeli 30 sampel untuk tes. Hasil rata-rata sampel cuma 3.15 GHz. Apakah vendor bohong?
  - Tugas (Python):
    + Load data sampel (30 unit).
    + Hitung 95% Confidence Interval menggunakan #NormalTok("scipy.stats.t.interval");.
    + Analisis: Cek apakah angka "3.2" ada di dalam rentang tersebut?
      - Jika ada: Klaim vendor diterima (perbedaan cuma kebetulan sampel).
      - Jika tidak ada: Vendor berbohong (tolak barang).
    + Simulasi: Apa yang terjadi pada lebar interval jika kita menaikkan tingkat kepercayaan jadi 99%? (Spoiler: Makin lebar/makin tidak presisi).
- #strong[01:10 - 01:40 | Studi Kasus: Estimasi Proporsi User]
  - Masalah: "Berapa % user yang suka Dark Mode?"
  - Tugas: Hitung CI untuk data biner (Suka/Tidak) menggunakan rumus Standard Error proporsi $sqrt(p \( 1 - p \) \/ n)$.
- #strong[01:40 - 01:50 | Showcase & Keputusan]
  - Pods mempresentasikan rekomendasi audit mereka: "Approve Vendor" atau "Blacklist Vendor".
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Kenapa kita tidak selalu pakai Confidence Level 100% saja biar pasti benar?" (Jawab: Karena intervalnya jadi $- oo$ sampai $oo$, alias tidak berguna).

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-10>
=== 1. Konsep Dasar
<konsep-dasar-9>
- #strong[Estimasi Titik (Point Estimate):] Nilai tunggal dari sampel (misal $macron(x)$ atau $hat(p)$) untuk menduga parameter populasi ($mu$ atau p). Sifatnya: Unbiased (tak bias) dan Efficient (variansi kecil).
- #strong[Interval Kepercayaan (Confidence Interval - CI):] Rentang nilai yang dibuat sedemikian rupa sehingga kita yakin (misal 95%) bahwa parameter populasi yang asli ada di dalamnya. $ upright("Estimator") plus.minus \( upright("CriticalValue") times upright("StandardError") \) $
- #strong[Distribusi T-Student:] Digunakan menggantikan Normal saat $sigma$ populasi tidak diketahui dan sampel kecil ($n < 30$). Bentuknya mirip lonceng tapi lebih landai (ekor lebih tebal), mencerminkan ketidakpastian yang lebih tinggi.

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-9>
- #strong[SLA Verification:] Cloud provider menjanjikan latency rata-rata 50ms. Dari log 100 request, rata-rata 52ms. Dengan CI, kita bisa cek apakah 52ms ini penyimpangan wajar atau pelanggaran kontrak.
- #strong[Hardware Benchmarking:] Mengklaim spesifikasi produk (misal: daya tahan baterai HP "10-12 jam") berdasarkan pengujian sampel terbatas di lab.
- #strong[A/B Testing Metric:] Saat melaporkan kenaikan konversi, jangan bilang "Naik 2%", tapi "Naik antara 1.5% s.d. 2.5%". Ini mencegah ekspektasi berlebihan dari manajemen.

=== 3. Komputasi (Python)
<komputasi-python-9>
- #strong[T-Interval:]

  #Skylighting(([#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" st");],
  [#CommentTok("# data = array sampel");],
  [#NormalTok("ci ");#OperatorTok("=");#NormalTok(" st.t.interval(confidence");#OperatorTok("=");#FloatTok("0.95");#NormalTok(", df");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(data)");#OperatorTok("-");#DecValTok("1");#NormalTok(",");],
  [#NormalTok("                   loc");#OperatorTok("=");#NormalTok("np.mean(data), scale");#OperatorTok("=");#NormalTok("st.sem(data))");],));

- #strong[Bootstrap (Metode Modern):]

  #Skylighting(([#CommentTok("# Resample data 1000x, hitung mean tiap kali, ambil persentil 2.5 dan 97.5");],
  [#NormalTok("bootstrap_means ");#OperatorTok("=");#NormalTok(" [np.mean(np.random.choice(data, size");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(data), replace");#OperatorTok("=");#VariableTok("True");#NormalTok(")) ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok(")]");],
  [#NormalTok("ci_lower ");#OperatorTok("=");#NormalTok(" np.percentile(bootstrap_means, ");#FloatTok("2.5");#NormalTok(")");],
  [#NormalTok("ci_upper ");#OperatorTok("=");#NormalTok(" np.percentile(bootstrap_means, ");#FloatTok("97.5");#NormalTok(")");],));

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-10>
#strong[Judul:] Week 11 Mission: The Spec Auditor - Validating Claims with Data

#strong[Deskripsi:] Mahasiswa bertindak sebagai auditor independen untuk sebuah aplikasi video conference. Developer mengklaim penggunaan RAM rata-rata aplikasi adalah 500MB. Mahasiswa diberi data log penggunaan memori dari 40 sesi user.

#strong[Set Soal (Notebook):] 1. #strong[Exploration (20 poin):] Load data #NormalTok("ram_usage.csv");. Hitung rata-rata sampel ($macron(x)$) dan standar deviasi sampel (s). 2. #strong[T-Interval Analysis (30 poin):] - Hitung 95% Confidence Interval untuk rata-rata penggunaan RAM populasi. - Gunakan #NormalTok("scipy.stats.t.interval");. - Apakah angka 500MB ada di dalam interval? Simpulkan apakah klaim developer valid. 3. #strong[Bootstrap Comparison (30 poin):] - Lakukan teknik Bootstrap (10.000 iterasi) untuk mendapatkan CI. - Bandingkan hasil CI Bootstrap dengan CI T-Interval. Apakah hasilnya mirip? (Seharusnya mirip karena n=40 cukup besar). 4. #strong[Sample Size Planning (20 poin):] - Jika manajemen ingin memperkecil Margin of Error menjadi separuhnya (agar estimasi lebih presisi), berapa kali lipat jumlah sampel yang harus diambil? (Buktikan dengan simulasi atau rumus $S E = s \/ sqrt(n)$).

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-9>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-10>
+ #strong[Soal:] Apa kriteria pengestimasi titik yang baik? Jelaskan konsep unbiasedness dan efisiensi.
  - #strong[Solusi:] Pengestimasi yang baik harus Tak Bias (#emph[Unbiased]), artinya nilai harapan (rata-rata) dari estimator tersebut sama dengan parameter populasi yang sebenarnya ($E \[ hat(theta) \] = theta$). Ia juga harus Efisien, artinya memiliki variansi yang paling kecil dibandingkan estimator tak bias lainnya (hasilnya konsisten dekat dengan target).
+ #strong[Soal:] Jelaskan interpretasi yang benar dari kalimat "Interval kepercayaan 95% untuk rata-rata adalah \[3, 4\]".
  - #strong[Solusi:] Interpretasi yang benar berkaitan dengan prosesnya: "Jika kita mengambil 100 sampel berbeda dan membuat interval kepercayaan untuk masing-masing sampel, maka sekitar 95 dari 100 interval tersebut akan memuat rata-rata populasi yang sebenarnya." (Bukan "peluang rata-rata ada di situ adalah 95%", karena rata-rata populasi itu konstan, bukan variabel acak).
+ #strong[Soal:] Mengapa kita menggunakan distribusi t-Student daripada distribusi Normal ketika simpangan baku populasi tidak diketahui?
  - #strong[Solusi:] Ketika simpangan baku populasi ($sigma$) tidak diketahui, kita mengestimasinya dengan simpangan baku sampel (s). Estimasi ini menambah ketidakpastian, terutama pada sampel kecil. Distribusi t-Student memiliki "ekor" yang lebih tebal (lebar) untuk mengakomodasi ketidakpastian tambahan ini, sehingga interval kepercayaan menjadi lebih realistis (lebih lebar) dibanding jika memakai Normal.
+ #strong[Soal:] Bagaimana pengaruh tingkat kepercayaan (misal 90% vs 99%) terhadap lebar interval kepercayaan?
  - #strong[Solusi:] Semakin tinggi tingkat kepercayaan (misal 99%), semakin lebar interval kepercayaannya. Ini karena untuk menjadi "lebih yakin" bahwa target kita tertangkap, kita harus menebar jaring yang lebih luas. Sebaliknya, kepercayaan rendah (90%) menghasilkan interval yang lebih sempit (presisi tinggi tapi risiko salah tangkap besar).
+ #strong[Soal:] Apa yang dimaksud dengan margin error dalam konteks survei atau polling?
  - #strong[Solusi:] Margin error adalah setengah dari lebar interval kepercayaan. Ia mencerminkan sejauh mana hasil statistik sampel (misal: 55% pemilih) mungkin menyimpang dari nilai populasi sebenarnya. Rumusnya biasanya $z times sigma / sqrt(n)$.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-10>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah startup ingin mengestimasi rata-rata waktu yang dihabiskan user di aplikasi mereka. Dari sampel 50 user, rata-rata adalah 15 menit dengan s=5. Hitung interval kepercayaan 95%.
  - #strong[Solusi:]
    - $n = 50 \, macron(x) = 15 \, s = 5$. Tingkat kepercayaan 95% ($alpha = 0.05$).
    - Karena $n gt.eq 30$, bisa pakai aproksimasi Z atau t. Misal pakai $Z_0.025 approx 1.96$.
    - Standard Error (SE) = $5 \/ sqrt(50) approx 0.707$.
    - Margin Error = $1.96 times 0.707 approx 1.38$.
    - CI = $15 plus.minus 1.38 = \[ 13.62 \, 16.38 \]$ menit.
+ #strong[Soal:] Estimasi proporsi mahasiswa STI yang lebih menyukai Python daripada Java dengan margin error 5% pada tingkat kepercayaan 95%. Berapa ukuran sampel yang dibutuhkan?
  - #strong[Solusi:]
    - Rumus Margin Error: $E = Z sqrt(frac(p \( 1 - p \), n))$.
    - Karena p tidak diketahui, gunakan estimasi paling konservatif $p = 0.5$ (variansi maks).
    - $0.05 = 1.96 sqrt(frac(0.5 times 0.5, n)) arrow.r.double sqrt(n) = frac(1.96 times 0.5, 0.05) = 19.6$.
    - $n = \( 19.6 \)^2 = 384.16$. Jadi butuh sampel 385 mahasiswa.
+ #strong[Soal:] Hitung interval kepercayaan untuk perbedaan rata-rata waktu respons antara dua server (A dan B) berdasarkan data sampel performa keduanya.
  - #strong[Solusi:] Gunakan rumus Two-sample t-interval. $\( macron(x)_A - macron(x)_B \) plus.minus t_(c r i t) times sqrt(s_A^2 / n_A + s_B^2 / n_B)$. Jika interval ini mencakup angka 0 (nol), berarti tidak ada perbedaan signifikan antara kedua server.
+ #strong[Soal:] Tentukan batas bawah reliabilitas sebuah sistem cloud dengan tingkat kepercayaan 90% berdasarkan data uptime bulanan.
  - #strong[Solusi:] Ini adalah One-sided Confidence Interval. Lower Bound = $macron(x) - \( t_(0.10 \, d f) times S E \)$. Kita hanya peduli batas bawah (garansi minimum uptime), batas atasnya bisa dianggap 100% atau tak hingga.
+ #strong[Soal:] Analisis akurasi estimasi pendapatan harian sebuah e-commerce menggunakan interval kepercayaan t-Student.
  - #strong[Solusi:] Jika data sampel pendapatan harian (n kecil) dihitung, kita buat CI. Jika intervalnya terlalu lebar (misal: Rp 1 Juta $plus.minus$ Rp 800rb), maka estimasi tersebut tidak akurat untuk perencanaan bisnis. Solusinya: perbanyak hari sampel (n) untuk memperkecil Standard Error dan margin error.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-10>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Tulis fungsi Python untuk menghitung interval kepercayaan rata-rata menggunakan distribusi t-Student untuk sampel kecil.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" st  ");],
  [#KeywordTok("def");#NormalTok(" get_t_interval(data, confidence");#OperatorTok("=");#FloatTok("0.95");#NormalTok("):  ");],
  [#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data)  ");],
  [#NormalTok("m, se ");#OperatorTok("=");#NormalTok(" np.mean(data), st.sem(data)  ");],
  [#NormalTok("h ");#OperatorTok("=");#NormalTok(" st.t.ppf((");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" confidence) ");#OperatorTok("/");#NormalTok(" ");#FloatTok("2.");#NormalTok(", n");#OperatorTok("-");#DecValTok("1");#NormalTok(") ");#OperatorTok("*");#NormalTok(" se  ");],
  [#ControlFlowTok("return");#NormalTok(" m ");#OperatorTok("-");#NormalTok(" h, m ");#OperatorTok("+");#NormalTok(" h  ");],));
+ #strong[Soal:] Gunakan scipy.stats.t.interval untuk menghitung batas atas dan bawah estimasi secara otomatis.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("data ");#OperatorTok("=");#NormalTok(" [");#DecValTok("3");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("8");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("6");#NormalTok("] ");#CommentTok("# Contoh data  ");],
  [#NormalTok("ci ");#OperatorTok("=");#NormalTok(" st.t.interval(confidence");#OperatorTok("=");#FloatTok("0.95");#NormalTok(", df");#OperatorTok("=");#BuiltInTok("len");#NormalTok("(data)");#OperatorTok("-");#DecValTok("1");#NormalTok(",  ");],
  [#NormalTok("               loc");#OperatorTok("=");#NormalTok("np.mean(data), scale");#OperatorTok("=");#NormalTok("st.sem(data))  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"CI: ");#SpecialCharTok("{");#NormalTok("ci");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Buat simulasi yang menunjukkan bahwa 95% dari 100 interval kepercayaan yang dihasilkan benar-benar mencakup rata-rata populasi asli.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("pop_mean ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");#NormalTok("  ");],
  [#NormalTok("success ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok("  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("100");#NormalTok("):  ");],
  [#NormalTok("sample ");#OperatorTok("=");#NormalTok(" np.random.normal(pop_mean, ");#DecValTok("5");#NormalTok(", ");#DecValTok("30");#NormalTok(") ");#CommentTok("# Ambil sampel  ");],
  [#NormalTok("ci ");#OperatorTok("=");#NormalTok(" st.t.interval(");#FloatTok("0.95");#NormalTok(", ");#DecValTok("29");#NormalTok(", np.mean(sample), st.sem(sample))  ");],
  [#ControlFlowTok("if");#NormalTok(" ci[");#DecValTok("0");#NormalTok("] ");#OperatorTok("<=");#NormalTok(" pop_mean ");#OperatorTok("<=");#NormalTok(" ci[");#DecValTok("1");#NormalTok("]:  ");],
  [#NormalTok("    success ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Success Rate: ");#SpecialCharTok("{");#NormalTok("success");#SpecialCharTok("}");#SpecialStringTok("/100\"");#NormalTok(") ");#CommentTok("# Seharusnya dekat dengan 95  ");],));
+ #strong[Soal:] Implementasikan rumus untuk menghitung ukuran sampel minimum yang diperlukan untuk estimasi proporsi dengan margin error tertentu.
  - #strong[Solusi:]

  #Skylighting(([#KeywordTok("def");#NormalTok(" min_sample_size(margin_error, confidence");#OperatorTok("=");#FloatTok("0.95");#NormalTok(", p_guess");#OperatorTok("=");#FloatTok("0.5");#NormalTok("):  ");],
  [#NormalTok("z ");#OperatorTok("=");#NormalTok(" st.norm.ppf((");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" confidence) ");#OperatorTok("/");#NormalTok(" ");#DecValTok("2");#NormalTok(")  ");],
  [#NormalTok("n ");#OperatorTok("=");#NormalTok(" (z");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" p_guess ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p_guess)) ");#OperatorTok("/");#NormalTok(" (margin_error");#OperatorTok("**");#DecValTok("2");#NormalTok(")  ");],
  [#ControlFlowTok("return");#NormalTok(" np.ceil(n)  ");],
  [#BuiltInTok("print");#NormalTok("(min_sample_size(");#FloatTok("0.05");#NormalTok(")) ");#CommentTok("# Output ~385  ");],));
+ #strong[Soal:] Visualisasikan berbagai interval kepercayaan dari sampel yang berbeda menggunakan plot garis horizontal di matplotlib.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#NormalTok("pop_mean ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");#NormalTok("  ");],
  [#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("10");#NormalTok("): ");#CommentTok("# 10 sampel berbeda  ");],
  [#NormalTok("sample ");#OperatorTok("=");#NormalTok(" np.random.normal(pop_mean, ");#DecValTok("5");#NormalTok(", ");#DecValTok("30");#NormalTok(")  ");],
  [#NormalTok("mean, se ");#OperatorTok("=");#NormalTok(" np.mean(sample), st.sem(sample)  ");],
  [#NormalTok("ci_width ");#OperatorTok("=");#NormalTok(" ");#FloatTok("1.96");#NormalTok(" ");#OperatorTok("*");#NormalTok(" se ");#CommentTok("# Approx 95%  ");],
  [#NormalTok("color ");#OperatorTok("=");#NormalTok(" ");#StringTok("'blue'");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" (mean ");#OperatorTok("-");#NormalTok(" ci_width ");#OperatorTok("<=");#NormalTok(" pop_mean ");#OperatorTok("<=");#NormalTok(" mean ");#OperatorTok("+");#NormalTok(" ci_width) ");#ControlFlowTok("else");#NormalTok(" ");#StringTok("'red'");#NormalTok("  ");],
  [#NormalTok("plt.errorbar(mean, i, xerr");#OperatorTok("=");#NormalTok("ci_width, fmt");#OperatorTok("=");#StringTok("'o'");#NormalTok(", color");#OperatorTok("=");#NormalTok("color)  ");],
  [#NormalTok("plt.axvline(pop_mean, color");#OperatorTok("=");#StringTok("'green'");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(")  ");],
  [#NormalTok("plt.title(");#StringTok("\"Confidence Intervals vs True Mean\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
]

= Minggu 12: Pengujian Hipotesis
<minggu-12-pengujian-hipotesis>
Hypothesis Testing Procedure, Error Types

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image12.png"))
], caption: figure.caption(
position: bottom, 
[
“Ada obat baru. Klaimnya lebih efektif. Pertanyaannya: ini nyata atau kebetulan? Uji hipotesis itu ‘pengadilan statistik': ada H0, ada H1, ada aturan keputusan, dan ada risiko salah vonis (Type I/II). Hari ini kamu belajar prosedur uji, membaca p-value, dan yang paling penting: menghubungkan angka dengan konsekuensi. Karena salah keputusan di sini bukan cuma salah nilai---bisa salah arah kebijakan.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-9>
Menentukan H0 dan H1, menghitung statistik uji, P-value, serta memahami Galat Tipe I (False Positive) dan Tipe II (False Negative).

== 2. Tipikal Problem
<tipikal-problem-9>
Sebuah obat baru diklaim lebih efektif menyembuhkan penyakit dibandingkan obat lama. Apakah klaim ini valid atau hanya kebetulan?

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-9>
Melakukan uji hipotesis (misal t-test). Jika P-value \< alpha (0.05), tolak H0. Keputusannya adalah memproduksi obat baru tersebut karena terbukti secara signifikan lebih baik secara statistik.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-11>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 12!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 12!");],));
]
]
Week 12: Pengujian Hipotesis Statistik dan A/B Testing

== Agenda Perkuliahan Minggu 12
<agenda-perkuliahan-minggu-12>
#strong[Topik:] Prosedur Uji Hipotesis, P-value, & Jenis Galat (Error Types) #strong[Tema Misi:] "Launch or Rollback? The Data-Driven Judge"

=== Pertemuan 1: Senin (1 Jam) - The Courtroom Drama
<pertemuan-1-senin-1-jam---the-courtroom-drama>
#strong[Fokus:] Membangun intuisi tentang mekanisme pengambilan keputusan biner (Ya/Tidak) di bawah ketidakpastian menggunakan analogi hukum.

- #strong[00:00 - 00:10 | The Hook: "Kasus Obat Ajaib vs Fitur Baru"]
  - Skenario: "Manajer Produk bilang fitur 'Dark Mode' menaikkan user engagement 5%. Tapi data menunjukkan kenaikan cuma 0.2%. Apakah itu nyata atau cuma kebetulan?"
  - Analogi: Sidang Pengadilan.
    - Terdakwa: Fitur Baru.
    - Praduga Tak Bersalah ($H_0$): Fitur tidak berefek (Status Quo).
    - Jaksa Penuntut ($H_1$): Fitur berefek signifikan.
    - Bukti: Data Sampel.
  - Poin: Kita tidak pernah membuktikan $H_0$ benar. Kita hanya gagal menolaknya jika bukti lemah.
- #strong[00:10 - 00:30 | Konsep: P-value & Ambang Batas ($alpha$)]
  - Definisi Gen Z: P-value adalah "skor kebetulan".
  - Visualisasi: Tunjukkan kurva lonceng. Area ekor (tail) adalah zona "mustahil". Jika data jatuh di sana (P-value \< 0.05), kita kaget dan menolak $H_0$.
  - Signifikansi ($alpha$): Batas toleransi risiko (biasanya 5%).
- #strong[00:30 - 00:50 | Deep Dive: Matriks Kebingungan (Error Types)]
  - Galat Tipe I ($alpha$): Menghukum orang tidak bersalah (False Positive). Di IT: Merilis fitur yang sebenarnya jelek/biasa saja.
  - Galat Tipe II ($beta$): Membebaskan penjahat (False Negative). Di IT: Membuang ide fitur bagus karena datanya kurang.
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The A/B Test Analyst". Mahasiswa akan menganalisis hasil eksperimen UI/UX untuk memutuskan peluncuran fitur.

=== Pertemuan 2: Rabu (2 Jam) - A/B Testing Lab
<pertemuan-2-rabu-2-jam---ab-testing-lab>
#strong[Fokus:] Menggunakan Python untuk melakukan uji-t (t-test) dan simulasi kekuatan uji (power).

- #strong[00:00 - 00:20 | Micro-Lecture: Memilih Senjata (Uji Statistik)]
  - Z-test: Jika tahu populasi (jarang dipakai).
  - T-test: Senjata standar anak IT (sampel kecil/sedang, populasi tak diketahui).
  - Python Tool: #NormalTok("scipy.stats.ttest_ind"); (untuk membandingkan dua grup A/B).
- #strong[00:20 - 01:10 | Pod Challenge: "Conversion Rate War"]
  - Skenario: E-commerce membandingkan tombol "Beli" warna Merah (A) vs Hijau (B).
  - Data: Dua array berisi 0 (nggak beli) dan 1 (beli).
  - Tugas (Python):
    + Rumuskan hipotesis $H_0 \( A = B \)$ dan $H_1 \( A eq.not B \)$.
    + Jalankan t-test (atau Z-test proporsi).
    + Dapatkan P-value. Ambil keputusan: Tolak atau Terima $H_0$?
    + Critical Thinking: Jika P-value = 0.049 (nyaris tidak signifikan), apakah kita berani rilis? (Diskusi tentang signifikansi statistik vs bisnis).
- #strong[01:10 - 01:40 | Simulasi: "The Power of Data"]
  - Masalah: Kenapa kita sering gagal mendeteksi fitur bagus? (Galat Tipe II).
  - Simulasi: Ulangi eksperimen dengan sampel n=10 vs n=1000. Tunjukkan bagaimana sampel besar meningkatkan Power (1-$beta$) untuk menolak $H_0$ yang salah.
- #strong[01:40 - 01:50 | Showcase & Keputusan]
  - Presentasi singkat: "Launch" atau "Rollback" berdasarkan data.
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Apa bedanya signifikansi statistik dengan signifikansi praktis (bisnis)?"

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-11>
=== 1. Konsep Dasar
<konsep-dasar-10>
- #strong[Hipotesis Nol ($H_0$):] Pernyataan bahwa tidak ada perbedaan atau efek. Ini adalah asumsi awal yang ingin kita tantang (misal: $mu_A = mu_B$).
- #strong[Hipotesis Alternatif ($H_1$):] Pernyataan yang ingin dibuktikan kebenarannya (misal: $mu_A eq.not mu_B$).
- #strong[P-value:] Probabilitas mendapatkan data sampel seperti yang diamati (atau lebih ekstrim), dengan asumsi $H_0$ benar. P-value kecil $arrow.r$ Bukti kuat melawan $H_0$.
- #strong[Signifikansi ($alpha$):] Peluang maksimal melakukan Galat Tipe I (biasanya 0.05).
- #strong[Jenis Galat:]
  - Tipe I: Menolak $H_0$ padahal $H_0$ benar (False Positive).
  - Tipe II: Gagal menolak $H_0$ padahal $H_1$ benar (False Negative).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-10>
- #strong[A/B Testing:] Membandingkan metrik (konversi, latency, retention) antara versi kontrol dan eksperimen. Jika perbedaan signifikan (P \< 0.05), fitur baru dirilis.
- #strong[Performance Benchmarking:] Membuktikan apakah server baru lebih cepat secara signifikan dibanding server lama, bukan sekadar kebetulan fluktuasi trafik.
- #strong[Deteksi Anomali:] Menguji hipotesis apakah lonjakan trafik saat ini berasal dari distribusi normal trafik harian. Jika P-value sangat kecil, itu dianggap serangan (DDoS).

=== 3. Komputasi (Python)
<komputasi-python-10>
- #strong[Library:] #NormalTok("scipy.stats"); dan #NormalTok("statsmodels");.
- #strong[Fungsi Kunci:]
  - #NormalTok("ttest_1samp");: Uji satu sampel terhadap konstanta.
  - #NormalTok("ttest_ind");: Uji dua sampel independen (A/B testing).
  - #NormalTok("proportions_ztest");: Uji proporsi (misal CTR).
- #strong[Alur:] Load Data $arrow.r$ Hitung Statistik T $arrow.r$ Hitung P-value $arrow.r$ Bandingkan dengan alpha $arrow.r$ Keputusan.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-11>
#strong[Judul:] Week 12 Mission: The Hypothesis Detective

#strong[Deskripsi:] Mahasiswa diberikan data log performa dari dua algoritma pencarian (Search A dan Search B). Mereka harus menentukan secara statistik mana yang lebih cepat dan apakah perbedaannya signifikan.

#strong[Set Soal (Notebook):] 1. #strong[Formulasi (20 poin):] Tuliskan $H_0$ dan $H_1$ untuk kasus ini. Jelaskan apa konsekuensi Galat Tipe I (biaya ganti algoritma sia-sia) dalam konteks bisnis ini. 2. #strong[Uji Normalitas (20 poin):] Sebelum t-test, cek apakah data berdistribusi normal (visual histogram atau Shapiro-Wilk test). Jika tidak, apa yang harus dilakukan? (Jawab: CLT menyelamatkan jika sampel besar). 3. #strong[Eksekusi T-test (30 poin):] Gunakan #NormalTok("scipy.stats.ttest_ind"); untuk membandingkan rata-rata waktu pencarian. Tampilkan T-statistic dan P-value. 4. #strong[Analisis Power (30 poin):] Gunakan #NormalTok("statsmodels.stats.power"); untuk menghitung: dengan ukuran sampel saat ini, seberapa kecil perbedaan waktu (effect size) yang bisa kita deteksi dengan peluang 80%?

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-10>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-11>
+ #strong[Soal:] Jelaskan perbedaan filosofis antara hipotesis nol ($H_0$) dan hipotesis alternatif ($H_1$).
  - #strong[Solusi:] $H_0$ adalah pernyataan "status quo" atau tidak ada efek/perbedaan, yang diasumsikan benar sampai ada bukti kuat yang membantahnya (sikap skeptis). $H_1$ adalah klaim baru atau efek yang ingin dibuktikan oleh peneliti. Kita hanya bisa "menolak $H_0$" (mendukung $H_1$) atau "gagal menolak $H_0$" (tidak cukup bukti), tidak pernah membuktikan $H_0$ benar.
+ #strong[Soal:] Apa yang dimaksud dengan tingkat signifikansi ($alpha$) dan hubungannya dengan Galat Tipe I?
  - #strong[Solusi:] Tingkat signifikansi $alpha$ (misal 0.05) adalah probabilitas maksimum yang kita izinkan untuk melakukan Galat Tipe I. Galat Tipe I adalah kesalahan menolak $H_0$ padahal $H_0$ benar (False Positive). Jadi, $alpha$ adalah batas toleransi kita terhadap risiko "salah tuduh".
+ #strong[Soal:] Jelaskan konsep p-value dan bagaimana ia digunakan sebagai dasar penolakan $H_0$.
  - #strong[Solusi:] P-value adalah probabilitas mendapatkan data statistik seperti yang diamati (atau lebih ekstrim) jika hipotesis nol benar. Jika p-value \< $alpha$ (sangat kecil), artinya data tersebut sangat tidak mungkin terjadi karena kebetulan saja, sehingga kita menolak $H_0$.
+ #strong[Soal:] Apa itu Galat Tipe II ($beta$) dan bagaimana hubungannya dengan kekuatan uji (power of test)?
  - #strong[Solusi:] Galat Tipe II ($beta$) adalah kesalahan gagal menolak $H_0$ padahal $H_1$ benar (False Negative / gagal mendeteksi efek). Kekuatan uji (Power) adalah $1 - beta$, yaitu probabilitas tes berhasil mendeteksi efek/perbedaan jika hal itu benar-benar ada.
+ #strong[Soal:] Mengapa pengujian satu arah (one-tailed) terkadang lebih kuat daripada pengujian dua arah (two-tailed)?
  - #strong[Solusi:] Karena pada uji satu arah, seluruh wilayah kritis ($alpha$) dikonsentrasikan di satu sisi distribusi. Ini membuat nilai kritis lebih mudah dicapai (lebih sensitif mendeteksi perubahan ke arah tertentu), asalkan kita yakin perubahan ke arah sebaliknya tidak relevan atau mustahil.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-11>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah ISP mengklaim kecepatan rata-rata mereka adalah 100 Mbps. Dari sampel 50 user, didapat rata-rata 95 Mbps. Ujilah klaim ISP tersebut dengan $alpha = 0.05$.
  - #strong[Solusi:]
    - $H_0 : mu = 100 \, H_1 : mu eq.not 100$.
    - Hitung t-statistik. Jika P-value \< 0.05, tolak $H_0$ (klaim ISP bohong). Jika \> 0.05, klaim diterima (perbedaan 5 Mbps dianggap variasi sampel wajar).
+ #strong[Soal:] Perusahaan startup mengklaim fitur baru mereka meningkatkan durasi sesi user. Lakukan uji hipotesis untuk membandingkan rata-rata durasi sebelum dan sesudah fitur dirilis.
  - #strong[Solusi:] Gunakan Paired T-test (Uji t berpasangan) karena subjeknya sama (sebelum vs sesudah). $H_0 : mu_(d i f f) lt.eq 0 \, H_1 : mu_(d i f f) > 0$ (One-tailed). Jika P-value \< $alpha$, fitur terbukti efektif.
+ #strong[Soal:] Analisis apakah proporsi kegagalan transaksi di sistem pembayaran baru lebih kecil daripada sistem lama dengan tingkat signifikansi 1%.
  - #strong[Solusi:] Gunakan Z-test proporsi dua sampel.
    - $H_0 : p_(b a r u) gt.eq p_(l a m a)$. $H_1 : p_(b a r u) < p_(l a m a)$ (Sistem baru lebih baik/error lebih kecil).
    - Bandingkan P-value dengan $alpha = 0.01$.
+ #strong[Soal:] Uji apakah rata-rata penggunaan data mahasiswa STI berbeda secara signifikan dari rata-rata mahasiswa program studi lain.
  - #strong[Solusi:] Gunakan Independent Two-Sample T-test. $H_0 : mu_(S T I) = mu_(L a i n)$. $H_1 : mu_(S T I) eq.not mu_(L a i n)$ (Two-tailed).
+ #strong[Soal:] Gunakan uji hipotesis untuk memvalidasi apakah sebuah koin adil atau berat sebelah berdasarkan 100 lemparan.
  - #strong[Solusi:] Uji proporsi satu sampel.
    - $H_0 : p = 0.5$ (Adil).
    - $H_1 : p eq.not 0.5$ (Berat sebelah).
    - Jika hasil (misal 60 Heads) menghasilkan P-value \< 0.05, koin dianggap curang.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-11>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Tulis skrip Python untuk menghitung nilai t-statistik dan p-value secara manual untuk uji satu sampel.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" [");#DecValTok("50");#NormalTok(", ");#DecValTok("52");#NormalTok(", ");#DecValTok("51");#NormalTok(", ");#DecValTok("49");#NormalTok(", ");#DecValTok("48");#NormalTok("] ");#CommentTok("# data sampel  ");],
  [#NormalTok("mu_0 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");#NormalTok("    ");#CommentTok("# hipotesis nol  ");],
  [#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data)  ");],
  [#NormalTok("t_stat ");#OperatorTok("=");#NormalTok(" (np.mean(data) ");#OperatorTok("-");#NormalTok(" mu_0) ");#OperatorTok("/");#NormalTok(" (np.std(data, ddof");#OperatorTok("=");#DecValTok("1");#NormalTok(") ");#OperatorTok("/");#NormalTok(" np.sqrt(n))  ");],
  [#NormalTok("p_val ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" stats.t.cdf(");#BuiltInTok("abs");#NormalTok("(t_stat), df");#OperatorTok("=");#NormalTok("n");#OperatorTok("-");#DecValTok("1");#NormalTok(")) ");#CommentTok("# Two-tailed  ");],
  [#BuiltInTok("print");#NormalTok("(t_stat, p_val)  ");],));
+ #strong[Soal:] Gunakan scipy.stats.ttest\_ind untuk melakukan uji t dua sampel independen pada dataset performa server.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats  ");],
  [#NormalTok("server_A ");#OperatorTok("=");#NormalTok(" [");#DecValTok("8");#NormalTok(", ");#DecValTok("9");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("11");#NormalTok(", ");#DecValTok("12");#NormalTok("]  ");],
  [#NormalTok("server_B ");#OperatorTok("=");#NormalTok(" [");#DecValTok("9");#NormalTok(", ");#DecValTok("13");#NormalTok(", ");#DecValTok("14");#NormalTok(", ");#DecValTok("15");#NormalTok(", ");#DecValTok("16");#NormalTok("]  ");],
  [#NormalTok("stat, pval ");#OperatorTok("=");#NormalTok(" stats.ttest_ind(server_A, server_B)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P-value: ");#SpecialCharTok("{");#NormalTok("pval");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Visualisasikan daerah penolakan pada kurva distribusi Normal untuk uji dua arah.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" norm  ");],
  [#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("1000");#NormalTok(")  ");],
  [#NormalTok("y ");#OperatorTok("=");#NormalTok(" norm.pdf(x)  ");],
  [#NormalTok("plt.plot(x, y)  ");],
  [#NormalTok("plt.fill_between(x, ");#DecValTok("0");#NormalTok(", y, where");#OperatorTok("=");#NormalTok("(x ");#OperatorTok(">");#NormalTok(" ");#FloatTok("1.96");#NormalTok(") ");#OperatorTok("|");#NormalTok(" (x ");#OperatorTok("<");#NormalTok(" ");#OperatorTok("-");#FloatTok("1.96");#NormalTok("), color");#OperatorTok("=");#StringTok("'red'");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")  ");],
  [#NormalTok("plt.title(");#StringTok("\"Daerah Penolakan (Alpha 0.05)\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
+ #strong[Soal:] Buat simulasi untuk menghitung probabilitas Galat Tipe I dengan melakukan pengujian berulang pada data yang ditarik dari populasi yang sama.
  - #strong[Solusi:]

  #Skylighting(([#CommentTok("# Simulasi A/A Test (H0 benar)  ");],
  [#NormalTok("false_positives ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok("  ");],
  [#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok("):  ");],
  [#NormalTok("a ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("100");#NormalTok(")  ");],
  [#NormalTok("b ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("100");#NormalTok(") ");#CommentTok("# Populasi sama  ");],
  [#NormalTok("_, p ");#OperatorTok("=");#NormalTok(" stats.ttest_ind(a, b)  ");],
  [#ControlFlowTok("if");#NormalTok(" p ");#OperatorTok("<");#NormalTok(" ");#FloatTok("0.05");#NormalTok(": false_positives ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Type I Error Rate: ");#SpecialCharTok("{");#NormalTok("false_positives");#OperatorTok("/");#DecValTok("1000");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(") ");#CommentTok("# Harusnya ~0.05  ");],));
+ #strong[Soal:] Implementasikan uji proporsi dua sampel menggunakan pustaka statsmodels.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" statsmodels.stats.proportion ");#ImportTok("import");#NormalTok(" proportions_ztest  ");],
  [#CommentTok("# Misal: Grup A 30/100 sukses, Grup B 45/100 sukses  ");],
  [#NormalTok("count ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("30");#NormalTok(", ");#DecValTok("45");#NormalTok("])  ");],
  [#NormalTok("nobs ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("100");#NormalTok(", ");#DecValTok("100");#NormalTok("])  ");],
  [#NormalTok("stat, pval ");#OperatorTok("=");#NormalTok(" proportions_ztest(count, nobs)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P-value: ");#SpecialCharTok("{");#NormalTok("pval");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
]

= Minggu 13: Regresi
<minggu-13-regresi>
Regression Line, Coefficient of Correlation

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image13.png"))
], caption: figure.caption(
position: bottom, 
[
“Besok operator harus siapin bahan bakar. Kalau salah prediksi beban, bisa boros atau blackout. Kita punya data suhu dan konsumsi listrik. Pertanyaannya: ada hubungan linear nggak? Hari ini kamu belajar bikin garis regresi dengan least squares, mengukur kekuatan hubungan lewat korelasi, lalu memakai model untuk prediksi praktis. Targetnya bukan ‘gambar garis'---targetnya keputusan operasional yang lebih presisi.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-10>
Memodelkan hubungan linear antara variabel independen (x) dan dependen (y) dengan metode kuadrat terkecil (y = b0 + b1x).

== 2. Tipikal Problem
<tipikal-problem-10>
Memprediksi konsumsi daya listrik berdasarkan suhu lingkungan.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-10>
Mengumpulkan data historis, membuat model regresi linear. Model ini digunakan operator pembangkit listrik untuk merencanakan berapa banyak bahan bakar yang harus disiapkan besok berdasarkan ramalan cuaca (suhu).

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-12>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 13!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 13!");],));
]
]
Week 13: Regresi Linear Sederhana dan Korelasi

== Agenda Perkuliahan Minggu 13
<agenda-perkuliahan-minggu-13>
#strong[Topik:] Regresi Linear Sederhana & Korelasi #strong[Tema Misi:] "Predicting the Future: From Data Points to Crystal Balls"

=== Pertemuan 1: Senin (1 Jam) - The Intuition & The Pattern
<pertemuan-1-senin-1-jam---the-intuition-the-pattern>
#strong[Fokus:] Memahami perbedaan korelasi dan kausalitas, serta konsep dasar "garis terbaik" untuk prediksi.

- #strong[00:00 - 00:10 | The Hook: "Spurious Correlations"]
  - Aktivitas: Tampilkan grafik korelasi konyol (misal: "Jumlah film Nicolas Cage vs.~Orang tenggelam di kolam renang"). Korelasinya tinggi (r=0.66), tapi apakah berhubungan?
  - Poin: Correlation $eq.not$ Causation. Sebagai Data Scientist, tugas kita membedakan pola nyata dari kebetulan.
- #strong[00:10 - 00:30 | Konsep: Garis Terbaik (Least Squares)]
  - Masalah: Kita punya data server load dan latency. Bagaimana memprediksi latency jika load naik 2x lipat?
  - Visual: Tunjukkan Scatter Plot. Tantang mahasiswa menarik garis lurus di layar/papan. Garis mana yang "paling benar"?
  - Definisi: Metode Kuadrat Terkecil (Ordinary Least Squares - OLS) meminimalkan total kuadrat jarak vertikal (error/residual) antara data dan garis.
- #strong[00:30 - 00:50 | Deep Dive: $R^2$ (The Scoreboard)]
  - Analogi: $R^2$ (Koefisien Determinasi) adalah "skor ujian" model kita.
    - $R^2 = 1$: Peramal sempurna (God mode).
    - $R^2 = 0$: Tebakan acak (Useless).
  - Diskusi: Apakah $R^2$ tinggi selalu baik? (Intro ke Overfitting).
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Price Predictor". Mahasiswa akan membangun model ML pertama mereka untuk memprediksi harga laptop/gadget berdasarkan spesifikasi.

=== Pertemuan 2: Rabu (2 Jam) - Prediction Lab
<pertemuan-2-rabu-2-jam---prediction-lab>
#strong[Fokus:] Menggunakan Python (scikit-learn) untuk membangun model regresi linear dan interpretasi bisnis.

- #strong[00:00 - 00:20 | Micro-Lecture: Membaca Model ($y = beta_0 + beta_1 x$)]
  - Intersep ($beta_0$): Nilai dasar (misal: Harga laptop tanpa RAM? Mungkin biaya casing).
  - Slope ($beta_1$): Dampak marjinal (misal: Setiap tambah 1GB RAM, harga naik Rp 500rb). Ini yang paling penting untuk bisnis.
- #strong[00:20 - 01:10 | Pod Challenge: "Tech Pricing Algorithm"]
  - Skenario: Anda bekerja di e-commerce barang bekas. Buat fitur "Saran Harga" otomatis.
  - Data: #NormalTok("laptop_prices.csv"); (Kolom: RAM, Storage, Screen Size, Price).
  - Tugas (Python):
    + EDA: Buat Heatmap korelasi. Fitur mana yang paling ngaruh ke harga? (RAM? Storage?).
    + Modelling: Gunakan #NormalTok("LinearRegression"); dari sklearn untuk melatih model.
    + Evaluasi: Berapa MSE dan $R^2$-nya?
    + Prediction: Jika ada laptop RAM 16GB dan Storage 512GB, berapa harganya menurut modelmu?
- #strong[01:10 - 01:40 | Studi Kasus: Residual Analysis]
  - Masalah: Apakah model kita bias?
  - Visualisasi: Plot Residual ($y_(p r e d) - y_(a c t u a l)$). Jika bentuknya acak (noise), model bagus. Jika membentuk pola (kurva U), berarti kita butuh model non-linear.
- #strong[01:40 - 01:50 | Showcase & Debat]
  - "Apakah RAM 64GB harganya masuk akal di model linear?" (Diskusi tentang ekstrapolasi).
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Jika $R^2 = 0.8$, apa artinya bagi variansi data?" (Jawab: 80% variasi harga bisa dijelaskan oleh spesifikasi, 20% sisanya misteri/faktor lain).

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-12>
=== 1. Konsep Dasar
<konsep-dasar-11>
- #strong[Korelasi (r):] Mengukur kekuatan dan arah hubungan linear antara dua variabel (-1 s.d +1). Korelasi 0 berarti tidak ada hubungan linear (bisa jadi ada hubungan non-linear).
- #strong[Regresi Linear Sederhana:] Memodelkan hubungan kausal (sebab-akibat) atau prediktif: $Y = beta_0 + beta_1 X + epsilon.alt$.
  - $beta_1$ (Slope): Perubahan Y untuk setiap 1 unit perubahan X.
- #strong[Koefisien Determinasi ($R^2$):] Proporsi variansi Y yang dapat dijelaskan oleh X. $R^2 = 0.85$ berarti 85% perubahan output dijelaskan oleh input.
- #strong[Residual:] Selisih antara nilai asli dan prediksi ($e = y - hat(y)$). Analisis residual digunakan untuk memvalidasi asumsi model (homoskedastisitas, normalitas error).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-11>
- #strong[Capacity Planning:] Memprediksi beban CPU (Y) berdasarkan jumlah Request per Second (X). Jika slope curam, server cepat panas/penuh.
- #strong[Software Estimation:] Mengestimasi waktu pengerjaan proyek (Y) berdasarkan jumlah Function Point atau baris kode (X).
- #strong[Business Intelligence:] Prediksi Customer Lifetime Value (CLV) berdasarkan frekuensi pembelian bulan pertama. Regresi adalah algoritma Machine Learning paling dasar (Supervised Learning).

=== 3. Komputasi (Python)
<komputasi-python-11>
- #strong[Libraries:] #NormalTok("pandas"); (data), #NormalTok("seaborn"); (plot), #NormalTok("scikit-learn"); (model).
- #strong[Fungsi Kunci:]
  - #NormalTok("df.corr()");: Matriks korelasi.
  - #NormalTok("sns.regplot(x, y)");: Scatter plot dengan garis regresi otomatis.
  - #NormalTok("model.fit(X, y)"); & #NormalTok("model.predict(X)");: Training dan prediksi.
  - #NormalTok("mean_squared_error(y_true, y_pred)");: Metrik kesalahan.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-12>
#strong[Judul:] Week 13 Mission: The Algo-Trader - Predicting Trends

#strong[Deskripsi:] Mahasiswa menganalisis data historis kinerja server cloud (atau data saham fiktif). Mereka harus menemukan faktor apa yang paling mempengaruhi biaya operasional dan membuat model prediksi biaya bulan depan.

#strong[Set Soal (Notebook):] 1. #strong[Correlation Detective (20 poin):] Load data #NormalTok("server_metrics.csv"); (CPU, RAM, Disk I/O, Energy Cost). Hitung matriks korelasi. Variabel mana yang paling kuat hubungannya dengan Energy Cost? 2. #strong[Building the Regressor (30 poin):] - Bagi data menjadi Train (80%) dan Test (20%). - Latih #NormalTok("LinearRegression"); menggunakan variabel terkuat tadi. - Tampilkan persamaan regresi ($y = dots.h$). 3. #strong[Evaluation & Visualization (30 poin):] - Hitung Mean Squared Error (MSE) pada data Test. - Buat plot: Garis Regresi di atas Scatter Plot data asli. 4. #strong[Interpretation (20 poin):] - Jelaskan arti Slope dalam bahasa bisnis. (Contoh: "Setiap kenaikan 1% CPU menaikkan tagihan listrik sebesar \$5"). - Cek plot residual: Apakah error menyebar rata atau membesar di nilai tinggi (heteroskedastisitas)?

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-11>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-12>
+ #strong[Soal:] Apa perbedaan antara korelasi dan regresi dalam hal tujuan analisisnya?
  - #strong[Solusi:] Korelasi bertujuan untuk mengukur kekuatan dan arah hubungan linear antara dua variabel (seberapa erat mereka bergerak bersama), tanpa menyiratkan sebab-akibat. Regresi bertujuan untuk memprediksi nilai satu variabel (dependen) berdasarkan variabel lain (independen) dan memodelkan bentuk hubungan matematisnya.
+ #strong[Soal:] Jelaskan asumsi least squares (kuadrat terkecil) dalam menentukan garis regresi terbaik.
  - #strong[Solusi:] Metode least squares mencari garis yang meminimalkan jumlah kuadrat dari selisih vertikal (residual) antara setiap titik data aktual dan garis prediksi. Asumsinya adalah bahwa garis terbaik adalah garis yang total kesalahan kuadratnya paling kecil.
+ #strong[Soal:] Apa makna dari koefisien determinasi ($R^2$) dalam mengevaluasi kualitas model regresi?
  - #strong[Solusi:] $R^2$ menunjukkan proporsi variasi dalam variabel dependen (Y) yang dapat dijelaskan oleh variabel independen (X) dalam model. Nilai $R^2 = 0.8$ berarti 80% perubahan pada Y disebabkan oleh X (menurut model), sedangkan 20% sisanya oleh faktor lain.
+ #strong[Soal:] Mengapa "korelasi tidak berarti kausalitas"? Berikan contoh dalam konteks teknologi.
  - #strong[Solusi:] Korelasi hanya menunjukkan bahwa dua variabel bergerak bersamaan, tetapi tidak membuktikan satu menyebabkan yang lain; bisa jadi ada faktor ketiga (confounding variable). Contoh: Jumlah bug software berkorelasi positif dengan jumlah user. Bukan berarti user menyebabkan bug, tetapi keduanya meningkat karena popularitas aplikasi.
+ #strong[Soal:] Jelaskan peran residual dalam memeriksa validitas asumsi model regresi linear.
  - #strong[Solusi:] Residual adalah selisih nilai asli dan prediksi. Memeriksa plot residual membantu memvalidasi asumsi: jika residual tersebar acak di sekitar nol, model linear valid. Jika residual membentuk pola (misal kurva), berarti hubungan data sebenarnya non-linear dan model linear tidak cocok.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-12>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Buatlah model regresi untuk memprediksi harga laptop berdasarkan kapasitas RAM dan penyimpanan.
  - #strong[Solusi:] Modelnya berbentuk $H a r g a = beta_0 + beta_1 \( R A M \) + beta_2 \( S t o r a g e \) + epsilon.alt$. Kita menggunakan data historis untuk mengestimasi $beta_1$ dan $beta_2$, yang menunjukkan seberapa mahal harga memori per GB.
+ #strong[Soal:] Analisis hubungan antara biaya iklan digital dan jumlah klik yang didapatkan perusahaan.
  - #strong[Solusi:] Gunakan regresi linear sederhana ($K l i k = beta_0 + beta_1 dot.op B i a y a$). Jika $beta_1$ positif dan signifikan, iklan efektif. $R^2$ akan memberitahu seberapa besar variasi klik yang benar-benar dikontrol oleh anggaran iklan.
+ #strong[Soal:] Gunakan regresi untuk mengestimasi waktu penyelesaian proyek software berdasarkan jumlah modul yang dikerjakan.
  - #strong[Solusi:] $W a k t u = beta_0 + beta_1 \( M o d u l \)$. Intersep $beta_0$ bisa diartikan sebagai waktu setup awal, dan $beta_1$ adalah rata-rata waktu per modul. Ini membantu manajer proyek membuat timeline yang realistis.
+ #strong[Soal:] Hitung korelasi antara suhu ruangan data center dan jumlah kegagalan hardware tahunan.
  - #strong[Solusi:] Ambil data suhu rata-rata harian dan log kerusakan. Hitung korelasi Pearson (r). Jika r mendekati +1, ada bukti kuat bahwa suhu panas berhubungan dengan kerusakan, membenarkan investasi pendingin tambahan.
+ #strong[Soal:] Prediksikan nilai IPK mahasiswa berdasarkan jam belajar mingguan menggunakan data historis.
  - #strong[Solusi:] Lakukan regresi $I P K = beta_0 + beta_1 \( J a m B e l a j a r \)$. Prediksi nilai IPK untuk mahasiswa baru dengan memasukkan jam belajar mereka ke persamaan. Namun, hati-hati dengan faktor lain (bakat, kesehatan) yang masuk ke error $epsilon.alt$.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-12>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Gunakan pustaka scikit-learn untuk melatih model regresi linear sederhana dan tampilkan koefisien serta intersepnya.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression  ");],
  [#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("X ");#OperatorTok("=");#NormalTok(" np.array([[");#DecValTok("7");#NormalTok("], [");#DecValTok("8");#NormalTok("], [");#DecValTok("9");#NormalTok("]])");#OperatorTok(";");#NormalTok(" y ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("8");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("11");#NormalTok("])  ");],
  [#NormalTok("model ");#OperatorTok("=");#NormalTok(" LinearRegression().fit(X, y)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Coef: ");#SpecialCharTok("{");#NormalTok("model");#SpecialCharTok(".");#NormalTok("coef_");#SpecialCharTok("}");#SpecialStringTok(", Intercept: ");#SpecialCharTok("{");#NormalTok("model");#SpecialCharTok(".");#NormalTok("intercept_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Tulis fungsi Python untuk menghitung koefisien korelasi Pearson secara manual dari dua list data.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#KeywordTok("def");#NormalTok(" pearson_r(x, y):  ");],
  [#NormalTok("x_mean, y_mean ");#OperatorTok("=");#NormalTok(" np.mean(x), np.mean(y)  ");],
  [#NormalTok("num ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((x ");#OperatorTok("-");#NormalTok(" x_mean) ");#OperatorTok("*");#NormalTok(" (y ");#OperatorTok("-");#NormalTok(" y_mean))  ");],
  [#NormalTok("den ");#OperatorTok("=");#NormalTok(" np.sqrt(np.");#BuiltInTok("sum");#NormalTok("((x ");#OperatorTok("-");#NormalTok(" x_mean)");#OperatorTok("**");#DecValTok("2");#NormalTok(") ");#OperatorTok("*");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((y ");#OperatorTok("-");#NormalTok(" y_mean)");#OperatorTok("**");#DecValTok("2");#NormalTok("))  ");],
  [#ControlFlowTok("return");#NormalTok(" num ");#OperatorTok("/");#NormalTok(" den  ");],));
+ #strong[Soal:] Visualisasikan garis regresi di atas scatter plot menggunakan seaborn.regplot.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" seaborn ");#ImportTok("as");#NormalTok(" sns");#OperatorTok(";");#NormalTok(" ");#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#CommentTok("# asumsikan df adalah DataFrame pandas  ");],
  [#NormalTok("sns.regplot(x");#OperatorTok("=");#StringTok("\"jam_belajar\"");#NormalTok(", y");#OperatorTok("=");#StringTok("\"nilai_ujian\"");#NormalTok(", data");#OperatorTok("=");#NormalTok("df)  ");],
  [#NormalTok("plt.show()  ");],));
+ #strong[Soal:] Hitung nilai Mean Squared Error (MSE) dari prediksi model regresi pada data testing.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" mean_squared_error  ");],
  [#NormalTok("y_pred ");#OperatorTok("=");#NormalTok(" model.predict(X_test)  ");],
  [#NormalTok("mse ");#OperatorTok("=");#NormalTok(" mean_squared_error(y_test, y_pred)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"MSE: ");#SpecialCharTok("{");#NormalTok("mse");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Buat plot residual untuk mengecek apakah ada pola tertentu yang melanggar asumsi linearitas.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("residuals ");#OperatorTok("=");#NormalTok(" y_test ");#OperatorTok("-");#NormalTok(" y_pred  ");],
  [#NormalTok("plt.scatter(y_pred, residuals)  ");],
  [#NormalTok("plt.axhline(");#DecValTok("0");#NormalTok(", color");#OperatorTok("=");#StringTok("'red'");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(")  ");],
  [#NormalTok("plt.xlabel(");#StringTok("\"Predicted\"");#NormalTok(")");#OperatorTok(";");#NormalTok(" plt.ylabel(");#StringTok("\"Residuals\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],
  [#CommentTok("# Harusnya menyebar acak tanpa pola  ");],));
]

= Minggu 14-15: Studi Kasus Lanjutan
<minggu-14-15-studi-kasus-lanjutan>
Advanced Case Studies (Application in Computing/Electrical Engineering)

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image14.png"))
], caption: figure.caption(
position: bottom, 
[
“Di dunia nyata selalu ada noise: lingkungan berubah, sensor drift, proses manufaktur goyang. Produk bagus bukan yang sempurna di lab, tapi yang #emph[robust] di lapangan. Minggu ini kamu menggabungkan semua: estimasi, uji, regresi---dipakai untuk masalah kompleks seperti desain parameter robust atau deteksi sinyal di tengah noise. Kamu tidak cuma menghitung; kamu merancang eksperimen dan memilih parameter kontrol yang menekan variansi output. Ini level ‘engineer beneran'.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-11>
Penerapan integratif dari estimasi, uji hipotesis, dan regresi pada masalah dunia nyata yang kompleks, seperti Robust Parameter Design atau deteksi sinyal.

== 2. Tipikal Problem
<tipikal-problem-11>
Mengoptimalkan parameter proses manufaktur agar tahan terhadap variasi lingkungan (noise) atau mendeteksi sinyal radar di tengah noise.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-11>
Menggunakan desain eksperimen (DOE) dan analisis statistik untuk memilih parameter 'kontrol' yang meminimalkan variansi output (membuat produk robust/tangguh), sehingga menekan biaya cacat produksi.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-13>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 14-15!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 14-15!");],));
]
]
Week 14: Aplikasi Statistika Lanjutan (A/B Testing, Anomaly Detection)

== Agenda Perkuliahan Minggu 14
<agenda-perkuliahan-minggu-14>
#strong[Topik:] Aplikasi Lanjutan (A/B Testing, Deteksi Anomali, & Evaluasi Model) #strong[Tema Misi:] "The Data Detective: Finding Signals in the Noise"

=== Pertemuan 1: Senin (1 Jam) - The Strategy
<pertemuan-1-senin-1-jam---the-strategy>
#strong[Fokus:] Memahami bagaimana raksasa teknologi (Google, Netflix, Gojek) menggunakan statistik untuk mengambil keputusan otomatis.

- #strong[00:00 - 00:10 | The Hook: "The \$300 Million Button"]
  - Kisah: Ceritakan bagaimana perubahan warna tombol di Bing atau Amazon menghasilkan kenaikan revenue jutaan dolar.
  - Pertanyaan: "Bagaimana mereka tahu itu bukan kebetulan? Apakah mereka hanya menebak?"
  - Konsep: Pengantar A/B Testing sebagai standar emas pengambilan keputusan produk digital.
- #strong[00:10 - 00:30 | Bedah Kasus: Deteksi Anomali (Security)]
  - Visual: Tampilkan grafik traffic server yang normal, lalu tiba-tiba ada lonjakan (spike).
  - Diskusi: "Kapan sebuah lonjakan disebut serangan DDoS dan kapan disebut 'viral marketing'? Bagaimana membedakannya secara matematis?"
  - Konsep: Menggunakan Skor-Z dan distribusi probabilitas untuk menentukan threshold alarm.
- #strong[00:30 - 00:50 | Deep Dive: Metrik Evaluasi (Bukan Sekadar Akurasi)]
  - Masalah: "Model deteksi kanker akurasinya 99%, tapi dia menebak semua orang 'sehat'. Berguna?"
  - Konsep: Precision vs.~Recall dan F1-Score. Pentingnya memahami imbalanced data dalam sistem informasi.
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The DevOps Guardian". Mahasiswa akan menganalisis log server untuk mendeteksi serangan dan mengevaluasi eksperimen fitur baru.

=== Pertemuan 2: Rabu (2 Jam) - Integration Lab
<pertemuan-2-rabu-2-jam---integration-lab>
#strong[Fokus:] Menggunakan Python untuk simulasi end-to-end: dari data mentah -\> analisis statistik -\> keputusan bisnis.

- #strong[00:00 - 00:20 | Micro-Lecture: Multiple Testing Problem]
  - Masalah: "Jika kamu melakukan A/B test pada 100 tombol berbeda, kemungkinan besar 5 tombol akan terlihat 'signifikan' secara kebetulan (jika $alpha = 0.05$)."
  - Solusi: Hati-hati dengan P-hacking. Fokus pada hipotesis yang kuat sebelum coding.
- #strong[00:20 - 01:10 | Pod Challenge: "A/B Testing & Anomaly Hunt"]
  - Dataset: #NormalTok("server_logs.csv"); (berisi timestamp, cpu\_usage, response\_time, group\_variant).
  - Tugas (Python):
    + A/B Test: Bandingkan #NormalTok("response_time"); antara Grup A (Algoritma Lama) dan Grup B (Algoritma Baru). Apakah B lebih cepat secara signifikan? (Pakai T-test).
    + Anomaly Detection: Cari jam-jam di mana #NormalTok("cpu_usage"); menyimpang \> 3 standar deviasi dari rata-rata (Z-score \> 3).
    + Visualisasi: Plot time-series dengan garis merah di titik-titik anomali.
- #strong[01:10 - 01:40 | Studi Kasus: "To Block or Not to Block?"]
  - Skenario: Sistem mendeteksi anomali.
    - Jika diblokir (padahal user asli) $arrow.r$ Komplain (Cost: High).
    - Jika dibiarkan (padahal hacker) $arrow.r$ Data Breach (Cost: Ultra High).
  - Diskusi: Menentukan threshold keputusan berdasarkan Expected Loss (Materi Minggu 13).
- #strong[01:40 - 01:50 | Showcase & Debat]
  - Pods mempresentasikan temuan anomali mereka. "Apakah serangan terjadi pada jam 2 pagi atau jam 2 siang?"
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Mengapa akurasi tinggi bisa menipu dalam deteksi anomali?" (Jawab: Karena kelas anomali sangat jarang/minoritas).

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-13>
=== 1. Konsep Dasar
<konsep-dasar-12>
- #strong[A/B Testing:] Implementasi praktis dari Uji Hipotesis Dua Sampel (Independent T-test). Membagi traffic user ke versi Kontrol (A) dan Eksperimen (B) untuk mengukur dampak perubahan fitur.
- #strong[Deteksi Anomali (Outlier Detection)::] Mengidentifikasi data yang menyimpang jauh dari pola normal. Menggunakan konsep Skor-Z ($z = frac(x - mu, sigma)$) atau Interquartile Range (IQR).
- #strong[Evaluasi Klasifikasi:]
  - #strong[Presisi:] Dari semua yang ditebak positif, berapa yang benar? (TP/(TP+FP)).
  - #strong[Recall:] Dari semua kejadian positif asli, berapa yang ditemukan? (TP/(TP+FN)).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-12>
- #strong[Keamanan Siber:] Mendeteksi serangan DDoS atau intrusi jaringan dengan memantau lonjakan trafik yang memiliki probabilitas kejadian sangat kecil di bawah kondisi normal.
- #strong[Optimasi UI/UX:] Memutuskan apakah font baru meningkatkan waktu baca pengguna. Keputusan didasarkan pada P-value dan Confidence Interval dari data eksperimen.
- #strong[Monitoring Kesehatan Sistem:] Predictive Maintenance. Jika suhu server mulai menunjukkan tren naik (regresi) atau variansi tinggi, sistem mengirim peringatan sebelum server meledak.

=== 3. Komputasi (Python)
<komputasi-python-12>
- #strong[A/B Testing:] #NormalTok("scipy.stats.ttest_ind"); untuk uji beda rata-rata, #NormalTok("statsmodels.stats.proportion"); untuk uji beda konversi (proporsi).
- #strong[Z-Score:] #NormalTok("scipy.stats.zscore"); atau manual #NormalTok("(df - df.mean()) / df.std()");.
- #strong[Metrik:] #NormalTok("sklearn.metrics.classification_report"); untuk menghitung Presisi, Recall, dan F1 secara otomatis.

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-13>
#strong[Judul:] Week 14 Mission: The System Guardian - Data-Driven Defense

#strong[Deskripsi:] Anda adalah Site Reliability Engineer (SRE). Sistem baru saja mengalami insiden dan manajemen ingin tahu penyebabnya serta apakah fitur "Auto-Scaler" baru bekerja efektif.

#strong[Set Soal (Notebook):] 1. #strong[Incident Forensics (30 poin):] - Load data #NormalTok("system_metrics.csv");. - Hitung rata-rata dan standar deviasi CPU Usage pada jam kerja normal. - Identifikasi timestamp di mana CPU Usage \> $mu + 3 sigma$. Tandai sebagai "Potential Attack". 2. #strong[Feature Evaluation (30 poin):] - Data memuat kolom #NormalTok("scaler_version"); ('v1' vs 'v2'). - Lakukan A/B Testing: Apakah rata-rata latency pada 'v2' lebih rendah secara signifikan dibanding 'v1'? (Gunakan $alpha = 0.05$). - Visualisasikan distribusi latency kedua versi dengan #NormalTok("seaborn.kdeplot"); (lihat bagian ekor/tail). 3. #strong[Model Metrics (20 poin):] - Diberikan hasil prediksi deteksi serangan (array #NormalTok("y_true"); dan #NormalTok("y_pred");). - Hitung Confusion Matrix, Precision, dan Recall. - Jelaskan: Untuk kasus keamanan bank, mana yang lebih penting dimaksimalkan, Precision atau Recall? 4. #strong[Reporting (20 poin):] - Tulis Executive Summary (maks 5 kalimat): Apakah v2 harus di-deploy? Apakah serangan terdeteksi?

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-12>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-13>
+ #strong[Soal:] Bagaimana statistika membantu dalam optimasi algoritma pencarian di web?
  - #strong[Solusi:] Statistika (khususnya A/B testing dan regresi) digunakan untuk mengevaluasi apakah perubahan pada algoritma ranking meningkatkan relevansi hasil (misal: click-through rate). Probabilitas juga digunakan dalam model bahasa (seperti n-gram) untuk memprediksi kata kunci pencarian.
+ #strong[Soal:] Jelaskan peran probabilitas dalam menjaga keamanan protokol kriptografi.
  - #strong[Solusi:] Keamanan kriptografi bergantung pada probabilitas yang sangat kecil (negligible probability) bagi penyerang untuk menebak kunci privat atau menemukan collision pada fungsi hash secara acak. Konsep entropi (ketidakpastian) digunakan untuk mengukur kekuatan kunci.
+ #strong[Soal:] Apa yang dimaksud dengan pengujian A/B dalam pengembangan antarmuka pengguna (UI)?
  - #strong[Solusi:] Pengujian A/B adalah eksperimen terkontrol di mana dua varian UI (A dan B) ditunjukkan kepada dua kelompok pengguna secara acak. Analisis statistik (uji hipotesis) kemudian digunakan untuk menentukan varian mana yang memberikan performa lebih baik berdasarkan metrik tertentu (misal: konversi).
+ #strong[Soal:] Bagaimana konsep statistika deskriptif digunakan dalam memonitor kesehatan sistem (system health monitoring)?
  - #strong[Solusi:] Metrik deskriptif seperti rata-rata (mean), persentil (misal p99 latency), dan standar deviasi digunakan untuk menetapkan baseline performa normal. Penyimpangan dari nilai-nilai ini (anomali) menjadi sinyal peringatan dini adanya masalah sistem.
+ #strong[Soal:] Diskusi: Mengapa pemahaman statistik krusial bagi seorang data scientist di era AI?
  - #strong[Solusi:] AI dan Machine Learning pada dasarnya adalah inferensi statistik otomatis. Pemahaman statistik diperlukan untuk memahami cara kerja model, validasi hasil (menghindari overfitting), mengukur ketidakpastian prediksi, dan menghindari bias dalam data atau algoritma.

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-13>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Rancanglah sebuah eksperimen pengujian A/B untuk membandingkan dua desain tombol "Checkout" pada aplikasi e-commerce.
  - #strong[Solusi:]
    + Tentukan metrik keberhasilan: Conversion Rate (Klik/Total View).
    + Bagi trafik user 50:50 secara acak ke Desain A dan Desain B.
    + Kumpulkan data sampel hingga mencapai power statistik yang cukup.
    + Lakukan uji beda proporsi (Z-test) dengan $alpha = 0.05$.
    + Jika $P < 0.05$, implementasikan desain pemenang.
+ #strong[Soal:] Gunakan deteksi anomali berbasis skor-Z untuk mengidentifikasi trafik jaringan yang mencurigakan (potensi serangan DDoS).
  - #strong[Solusi:] Hitung rata-rata ($mu$) dan standar deviasi ($sigma$) trafik harian. Hitung skor-Z untuk trafik saat ini: $Z = \( X - mu \) \/ sigma$. Jika $\| Z \| > 3$ (di luar 3 sigma), tandai sebagai anomali/potensi DDoS.
+ #strong[Soal:] Analisis sentimen pengguna aplikasi menggunakan distribusi multinomial untuk kategori positif, netral, dan negatif.
  - #strong[Solusi:] Modelkan jumlah ulasan untuk setiap kategori (Positif, Netral, Negatif) sebagai vektor acak yang mengikuti distribusi Multinomial dengan parameter probabilitas ($p_1 \, p_2 \, p_3$). Lakukan estimasi parameter ini dari data sampel ulasan untuk memahami sentimen populasi.
+ #strong[Soal:] Evaluasi performa model klasifikasi gambar menggunakan metrik akurasi, presisi, dan recall berbasis tabel kontingensi.
  - #strong[Solusi:] Buat Confusion Matrix (TP, TN, FP, FN). Hitung:
    - Akurasi = (TP+TN)/Total.
    - Presisi = TP/(TP+FP) (Relevansi prediksi positif).
    - Recall = TP/(TP+FN) (Sensitivitas deteksi).
+ #strong[Soal:] Gunakan rantai Markov sederhana untuk memprediksi perilaku navigasi user di sebuah website.
  - #strong[Solusi:] Definisikan states (misal: Home, Produk, Cart, Checkout, Exit). Hitung matriks probabilitas transisi $P_(i j)$ (peluang pindah dari halaman i ke j) berdasarkan data historis log server. Gunakan matriks ini untuk memprediksi peluang user mencapai halaman "Checkout" dari "Home".
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-13>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Implementasikan skrip Python untuk melakukan pengujian A/B (uji t dua sampel) pada dataset log klik user.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("from");#NormalTok(" scipy ");#ImportTok("import");#NormalTok(" stats  ");],
  [#CommentTok("# Data durasi sesi (detik)  ");],
  [#NormalTok("group_a ");#OperatorTok("=");#NormalTok(" [");#DecValTok("6");#NormalTok(", ");#DecValTok("8");#NormalTok(", ");#DecValTok("9");#NormalTok(", ");#DecValTok("7");#NormalTok(", ");#DecValTok("10");#NormalTok("]  ");],
  [#NormalTok("group_b ");#OperatorTok("=");#NormalTok(" [");#DecValTok("9");#NormalTok(", ");#DecValTok("12");#NormalTok(", ");#DecValTok("11");#NormalTok(", ");#DecValTok("13");#NormalTok(", ");#DecValTok("14");#NormalTok("]  ");],
  [#NormalTok("t_stat, p_val ");#OperatorTok("=");#NormalTok(" stats.ttest_ind(group_a, group_b)  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P-value: ");#SpecialCharTok("{");#NormalTok("p_val");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(") ");#CommentTok("# Jika < 0.05, beda signifikan  ");],));
+ #strong[Soal:] Buatlah sistem peringatan dini sederhana yang mendeteksi lonjakan penggunaan CPU di atas 3 standar deviasi dari rata-rata.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("data_cpu ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("12");#NormalTok(", ");#DecValTok("15");#NormalTok(", ");#DecValTok("14");#NormalTok(", ");#DecValTok("13");#NormalTok(", ");#DecValTok("50");#NormalTok(", ");#DecValTok("15");#NormalTok(", ");#DecValTok("12");#NormalTok("]) ");#CommentTok("# 50 adalah anomali  ");],
  [#NormalTok("mean, std ");#OperatorTok("=");#NormalTok(" np.mean(data_cpu), np.std(data_cpu)  ");],
  [#NormalTok("threshold ");#OperatorTok("=");#NormalTok(" mean ");#OperatorTok("+");#NormalTok(" ");#DecValTok("3");#NormalTok(" ");#OperatorTok("*");#NormalTok(" std  ");],
  [#NormalTok("alarms ");#OperatorTok("=");#NormalTok(" data_cpu[data_cpu ");#OperatorTok(">");#NormalTok(" threshold]  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Alarm pada nilai: ");#SpecialCharTok("{");#NormalTok("alarms");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Gunakan pustaka pandas untuk melakukan analisis korelasi pada dataset besar berisi metrik performa sistem informasi.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd  ");],
  [#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.read_csv(");#StringTok("'system_metrics.csv'");#NormalTok(")  ");],
  [#NormalTok("correlation_matrix ");#OperatorTok("=");#NormalTok(" df.corr()  ");],
  [#BuiltInTok("print");#NormalTok("(correlation_matrix[");#StringTok("'latency'");#NormalTok("]) ");#CommentTok("# Cek faktor yang paling ngaruh ke latency  ");],));
+ #strong[Soal:] Tulis program untuk menghitung metrik evaluasi model (F1-score) berdasarkan input jumlah True Positive, False Positive, dan False Negative.
  - #strong[Solusi:]

  #Skylighting(([#KeywordTok("def");#NormalTok(" calculate_f1(tp, fp, fn):  ");],
  [#NormalTok("precision ");#OperatorTok("=");#NormalTok(" tp ");#OperatorTok("/");#NormalTok(" (tp ");#OperatorTok("+");#NormalTok(" fp)  ");],
  [#NormalTok("recall ");#OperatorTok("=");#NormalTok(" tp ");#OperatorTok("/");#NormalTok(" (tp ");#OperatorTok("+");#NormalTok(" fn)  ");],
  [#NormalTok("f1 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (precision ");#OperatorTok("*");#NormalTok(" recall) ");#OperatorTok("/");#NormalTok(" (precision ");#OperatorTok("+");#NormalTok(" recall)  ");],
  [#ControlFlowTok("return");#NormalTok(" f1  ");],
  [#BuiltInTok("print");#NormalTok("(calculate_f1(");#DecValTok("80");#NormalTok(", ");#DecValTok("20");#NormalTok(", ");#DecValTok("10");#NormalTok("))  ");],));
+ #strong[Soal:] Visualisasikan distribusi "tail" dari latensi aplikasi untuk memahami performa pada persentil ke-99 (P99).
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("latency ");#OperatorTok("=");#NormalTok(" np.random.exponential(scale");#OperatorTok("=");#DecValTok("100");#NormalTok(", size");#OperatorTok("=");#DecValTok("1000");#NormalTok(") ");#CommentTok("# Data simulasi  ");],
  [#NormalTok("plt.hist(latency, bins");#OperatorTok("=");#DecValTok("50");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")  ");],
  [#NormalTok("plt.axvline(np.percentile(latency, ");#DecValTok("99");#NormalTok("), color");#OperatorTok("=");#StringTok("'r'");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(", label");#OperatorTok("=");#StringTok("'P99'");#NormalTok(")  ");],
  [#NormalTok("plt.legend()");#OperatorTok(";");#NormalTok(" plt.show()  ");],));
]

= Minggu 14-15: Studi Kasus Lanjutan
<minggu-14-15-studi-kasus-lanjutan-1>
Advanced Case Studies (Application in Computing/Electrical Engineering)

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image14.png"))
], caption: figure.caption(
position: bottom, 
[
“Di dunia nyata selalu ada noise: lingkungan berubah, sensor drift, proses manufaktur goyang. Produk bagus bukan yang sempurna di lab, tapi yang #emph[robust] di lapangan. Minggu ini kamu menggabungkan semua: estimasi, uji, regresi---dipakai untuk masalah kompleks seperti desain parameter robust atau deteksi sinyal di tengah noise. Kamu tidak cuma menghitung; kamu merancang eksperimen dan memilih parameter kontrol yang menekan variansi output. Ini level ‘engineer beneran'.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-12>
Penerapan integratif dari estimasi, uji hipotesis, dan regresi pada masalah dunia nyata yang kompleks, seperti Robust Parameter Design atau deteksi sinyal.

== 2. Tipikal Problem
<tipikal-problem-12>
Mengoptimalkan parameter proses manufaktur agar tahan terhadap variasi lingkungan (noise) atau mendeteksi sinyal radar di tengah noise.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-12>
Menggunakan desain eksperimen (DOE) dan analisis statistik untuk memilih parameter 'kontrol' yang meminimalkan variansi output (membuat produk robust/tangguh), sehingga menekan biaya cacat produksi.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-14>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 14-15!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 14-15!");],));
]
]
Week 15: Simulasi Monte Carlo dan Teori Keputusan Strategis

== Agenda Perkuliahan Minggu 15
<agenda-perkuliahan-minggu-15>
#strong[Topik:] Studi Kasus Integratif (Monte Carlo, Decision Theory, & Risk Management) #strong[Tema Misi:] "Dr.~Strange Strategy: Winning in 14,000,605 Futures"

=== Pertemuan 1: Senin (1 Jam) - The Strategy of Simulation
<pertemuan-1-senin-1-jam---the-strategy-of-simulation>
#strong[Fokus:] Memahami bahwa ketika rumus matematika terlalu rumit untuk diselesaikan (analitis), kita bisa "memalsukan" ribuan eksperimen dengan komputer (numerik).

- #strong[00:00 - 00:10 | The Hook: "Menghitung Risiko Kebangkrutan"]
  - Masalah: Sebuah startup punya modal \$100k. Burn rate bulanan tidak pasti (Distribusi Normal), Revenue bulanan tidak pasti (Distribusi Gamma). Berapa peluang startup ini bangkrut dalam 12 bulan?
  - Diskusi: Menghitung ini dengan rumus kalkulus sangat sulit. Tapi dengan Python, kita bisa mensimulasikan "hidup" startup ini 10.000 kali dalam 1 detik.
  - Konsep: Pengantar Simulasi Monte Carlo.
- #strong[00:10 - 00:30 | Konsep: Teori Keputusan (Expected Loss)]
  - Konteks: Mengacu pada Aplikasi 19 dan Aplikasi 11.
  - Masalah: Model ML memprediksi transaksi fraud dengan skor 0.7. Apakah kita blokir?
  - Matriks Biaya:
    - Blokir User Asli (False Positive): Rugi reputasi (Misal \$10).
    - Loloskan Fraud (False Negative): Rugi uang (Misal \$1000).
  - Rumus: $E \[ L o s s \] = P \( F r a u d \) dot.op C o s t \( M i s s \) + P \( not F r a u d \) dot.op C o s t \( B l o c k \)$. Kita pilih aksi dengan kerugian terkecil, bukan sekadar akurasi tertinggi.
- #strong[00:30 - 00:50 | Deep Dive: Extreme Value Theory (EVT)]
  - Isu: Mengapa server crash padahal rata-rata beban rendah?
  - Poin: Desain sistem jangan berdasarkan rata-rata, tapi berdasarkan "Ekor" (Tail Risk / P99). Bencana terjadi di ekor distribusi.
- #strong[00:50 - 01:00 | Pod Formation & Mission Brief]
  - Misi GitHub: "The Risk Analyst Capstone". Mahasiswa akan membangun simulator risiko untuk proyek peluncuran produk IT.

=== Pertemuan 2: Rabu (2 Jam) - Simulation Lab
<pertemuan-2-rabu-2-jam---simulation-lab-3>
#strong[Fokus:] Menggunakan Python untuk menjalankan Simulasi Monte Carlo end-to-end dan mengambil keputusan bisnis.

- #strong[00:00 - 00:20 | Micro-Lecture: Membangun Dunia Simulasi]
  - Teknik: Menggabungkan #NormalTok("numpy.random"); (input acak) dengan logika bisnis (fungsi deterministik) untuk menghasilkan output distribusi (histogram hasil).
- #strong[00:20 - 01:10 | Pod Challenge: "Project Deadline Simulator"]
  - Skenario: Manajer proyek bertanya: "Kapan fitur ini selesai?". Programmer menjawab: "Optimis 5 hari, Pesimis 15 hari, Paling mungkin 8 hari" (Distribusi PERT/Triangular). Ada 5 tugas yang saling bergantung (seri dan paralel).
  - Tugas (Python):
    + Definisikan distribusi durasi untuk setiap tugas.
    + Jalankan 10.000 simulasi penyelesaian proyek.
    + Analisis: Jangan beri satu angka tanggal. Berikan: "Kami 90% yakin proyek selesai dalam X hari" (Persentil ke-90).
    + Visualisasi: Plot histogram total durasi.
- #strong[01:10 - 01:40 | Studi Kasus Integratif: Hazard Function]
  - Masalah: Kapan waktu terbaik mengganti server? Apakah server semakin tua semakin sering rusak (aging) atau kerusakannya acak (memoryless)?
  - Analisis: Plot Hazard Function dari data log kegagalan. Jika grafiknya naik, berarti ada penuaan (perlu preventive maintenance).
- #strong[01:40 - 01:50 | Showcase & Rekomendasi]
  - Pods mempresentasikan: "Berdasarkan simulasi, siapkan budget cadangan sebesar \$X agar peluang overbudget \< 5%."
- #strong[01:50 - 02:00 | Exit Ticket]
  - Pertanyaan: "Apa bedanya memprediksi 'Rata-rata Biaya' dengan memprediksi 'Value at Risk (VaR)'?"

#horizontalrule

== Materi Kuliah: Konsep, Aplikasi, & Komputasi
<materi-kuliah-konsep-aplikasi-komputasi-14>
=== 1. Konsep Dasar
<konsep-dasar-13>
- #strong[Simulasi Monte Carlo:] Metode komputasi untuk memahami dampak ketidakpastian risiko dalam prediksi dan peramalan. Caranya dengan melakukan pengambilan sampel acak berulang kali dari distribusi input untuk mendapatkan distribusi kemungkinan hasil (output).
- #strong[Teori Keputusan (Decision Theory):] Kerangka kerja untuk memilih tindakan di antara beberapa alternatif berdasarkan nilai harapan utilitas (Expected Utility) atau meminimalkan harapan kerugian (Expected Loss).
- #strong[Extreme Value Theory (EVT):] Cabang statistik yang menangani penyimpangan ekstrim dari median distribusi probabilitas (kejadian langka tapi berdampak besar, seperti beban puncak server).

=== 2. Aplikasi Sistem Informasi
<aplikasi-sistem-informasi-13>
- #strong[Manajemen Risiko Proyek:] Menggantikan estimasi titik tunggal (misal: "selesai 3 bulan") dengan distribusi probabilitas penyelesaian, memperhitungkan ketidakpastian di setiap subtugas.
- #strong[Analisis Churn (Hazard Function):] Memodelkan laju kehilangan pelanggan. Jika hazard rate tinggi di awal (pengguna baru bingung), perbaiki UI/UX. Jika tinggi di akhir (pengguna lama bosan), rilis fitur baru.
- #strong[Cost-Sensitive Learning:] Dalam deteksi fraud atau spam, ambang batas (threshold) keputusan digeser tidak hanya berdasarkan akurasi, tapi berdasarkan biaya finansial dari False Positive vs False Negative.

=== 3. Komputasi (Python)
<komputasi-python-13>
- #strong[Simulasi Loop:] Menggunakan for loop atau vektorisasi numpy untuk menjalankan ribuan skenario.
- #strong[Visualisasi Hasil:] #NormalTok("matplotlib.pyplot.hist"); untuk melihat sebaran hasil simulasi dan #NormalTok("numpy.percentile"); untuk menghitung interval kepercayaan atau risiko (misal: P95).
- #strong[Fungsi Kunci:] #NormalTok("np.random.triangular"); (untuk estimasi proyek), #NormalTok("np.random.choice"); (untuk skenario diskrit).

#horizontalrule

== Tugas Kelompok (GitHub Classroom)
<tugas-kelompok-github-classroom-14>
#strong[Judul:] Week 15 Mission: The Future Forecaster

#strong[Deskripsi:] Anda adalah CTO dari sebuah e-commerce yang bersiap menghadapi "Harbolnas" (Hari Belanja Nasional). Anda harus mensimulasikan kapasitas infrastruktur dan potensi keuntungan.

#strong[Set Soal (Notebook):] 1. #strong[Traffic Simulation (30 poin):] - Asumsikan trafik user mengikuti pola Mixture Model (Normal saat jam biasa + LogNormal saat flash sale). - Simulasikan beban server per detik selama 24 jam. 2. #strong[Infrastructure Risk (30 poin):] - Kapasitas server maksimum adalah C. Jika beban \> C, sistem crash (Revenue = 0 untuk jam itu). - Tentukan nilai C yang optimal: Biaya sewa server mahal vs Risiko kehilangan revenue saat crash. Gunakan pendekatan Expected Loss Minimization. 3. #strong[Revenue Projection (20 poin):] - Diketahui Conversion Rate adalah variabel acak Beta($alpha \, beta$). - Hitung estimasi total revenue hari itu dengan Confidence Interval 95% menggunakan Monte Carlo. 4. #strong[Executive Report (20 poin):] - Buat rekomendasi: "Kita harus menyewa kapasitas server sebanyak X unit. Ini menjamin 99% uptime dengan profit maksimal."

#horizontalrule

== 15 Soal & Solusi
<soal-solusi-13>
=== A. Pertanyaan Konseptual
<a.-pertanyaan-konseptual-14>
+ #strong[Soal:] Jelaskan konsep Expected Loss dalam pengambilan keputusan klasifikasi pada machine learning.
  - #strong[Solusi:] Expected Loss adalah jumlahan dari probabilitas setiap jenis kesalahan dikalikan dengan biaya kesalahan tersebut. Rumusnya: $E \[ L \] = P \( F N \) dot.op C o s t \( F N \) + P \( F P \) dot.op C o s t \( F P \)$. Tujuannya adalah memilih threshold yang meminimalkan total kerugian finansial, bukan sekadar meminimalkan jumlah error.
+ #strong[Soal:] Apa kegunaan Hazard Function h(t) dalam analisis retensi pengguna aplikasi?
  - #strong[Solusi:] Hazard function menggambarkan laju kejadian (misal: churn atau berhenti berlangganan) sesaat pada waktu t, dengan syarat pengguna tersebut masih aktif hingga waktu t. Jika h(t) menurun seiring waktu, artinya pengguna semakin setia semakin lama mereka menggunakan aplikasi.
+ #strong[Soal:] Mengapa kita menggunakan simulasi Monte Carlo untuk kuantifikasi ketidakpastian (Uncertainty Quantification)?
  - #strong[Solusi:] Karena banyak sistem nyata terlalu kompleks untuk diturunkan rumus variansinya secara analitis (terutama yang melibatkan fungsi non-linear atau dependensi rumit). Monte Carlo memungkinkan kita mengestimasi distribusi output dengan cara mensimulasikan ribuan input acak dan mengamati hasilnya secara empiris.
+ #strong[Soal:] Jelaskan perbedaan antara distribusi Gumbel (Tipe I) dan Frechet (Tipe II) dalam Teori Nilai Ekstrim.
  - #strong[Solusi:] Distribusi Gumbel digunakan untuk memodelkan nilai maksimum dari populasi yang memiliki ekor distribusi "ringan" (seperti Normal atau Eksponensial). Distribusi Frechet digunakan untuk populasi dengan ekor distribusi "berat" (seperti Pareto), yang sering ditemukan dalam fenomena alam atau finansial yang ekstrim.
+ #strong[Soal:] Dalam konteks Mixture Model, bagaimana kita memodelkan distribusi latensi yang memiliki dua karakteristik berbeda (misal: cache hit vs cache miss)?
  - #strong[Solusi:] Kita memodelkan distribusi total sebagai penjumlahan terbobot dari dua distribusi komponen: $f \( x \) = pi_1 f_1 \( x \) + pi_2 f_2 \( x \)$, di mana $pi$ adalah proporsi kejadian (misal: 80% cache hit, 20% miss). Ini menjelaskan distribusi yang memiliki dua puncak (bimodal).

=== B. Pertanyaan Aplikatif
<b.-pertanyaan-aplikatif-14>
#block[
#set enum(numbering: "1.", start: 6)
+ #strong[Soal:] Sebuah sistem mitigasi bencana memiliki tiga opsi aksi: Aksi A (Biaya 10, Risiko sisa 5), Aksi B (Biaya 50, Risiko sisa 1), Aksi C (Biaya 0, Risiko sisa 20). Jika risiko dikuantifikasi dalam uang, aksi mana yang optimal?
  - #strong[Solusi:] Hitung Total Expected Cost = Biaya Aksi + Risiko Sisa.
    - A: 10+5=15
    - B: 50+1=51
    - C: 0+20=20
    - Keputusan: Pilih Aksi A karena meminimalkan total biaya.
+ #strong[Soal:] Jika traffic puncak harian server mengikuti distribusi Nilai Ekstrim, bagaimana kita menentukan kapasitas server agar hanya overload sekali dalam 100 hari (Return Period = 100)?
  - #strong[Solusi:] Kita mencari nilai x (kapasitas) di mana $1 - F \( x \) = 1 \/ 100$ atau $F \( x \) = 0.99$. Kita menggunakan invers dari CDF distribusi Nilai Ekstrim (seperti Gumbel) untuk menemukan kapasitas tersebut.
+ #strong[Soal:] Sensor IoT memberikan data posisi yang berisik (noisy). Bagaimana kita menggabungkan prediksi model pergerakan (Prior) dengan data sensor baru (Likelihood) untuk mendapatkan estimasi posisi terbaik?
  - #strong[Solusi:] Gunakan prinsip filter Kalman (atau Bayesian Update untuk kasus Gaussian). Estimasi baru adalah rata-rata tertimbang antara prediksi model dan pengukuran sensor, di mana bobotnya ditentukan oleh kebalikan dari variansi masing-masing (semakin kecil variansi/noise, semakin besar bobotnya).
+ #strong[Soal:] Beban pada struktur data center (Q) dihitung dengan rumus $Q = a H^2$ di mana H adalah kecepatan angin (variabel acak). Bagaimana cara menentukan distribusi probabilitas dari Q?
  - #strong[Solusi:] Gunakan metode transformasi variabel. Jika H memiliki PDF $f_H \( h \)$, maka PDF dari Q adalah $f_Q \( q \) = f_H \( sqrt(q \/ a) \) dot.op frac(1, 2 sqrt(a q))$. Ini penting untuk menghitung peluang beban melebihi kekuatan struktur.
+ #strong[Soal:] Analisis pola login pengguna menunjukkan bahwa jika pengguna aktif hari ini, peluang dia aktif besok adalah 0.8. Jika dia tidak aktif hari ini, peluang dia aktif besok hanya 0.1. Modelkan ini.
  - #strong[Solusi:] Ini adalah Rantai Markov dengan matriks transisi: $P = mat(delim: "[", 0.2, 0.8; 0.9, 0.1)$ (Baris 1: Aktif, Baris 2: Tidak Aktif). Kita bisa menghitung peluang pengguna aktif dalam jangka panjang dengan mencari distribusi stasioner.
]

=== C. Pertanyaan Komputasional
<c.-pertanyaan-komputasional-14>
#block[
#set enum(numbering: "1.", start: 11)
+ #strong[Soal:] Implementasikan simulasi Monte Carlo sederhana di Python untuk menghitung estimasi nilai $pi$ dengan melempar titik acak ke dalam persegi.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np  ");],
  [#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10000");#NormalTok("  ");],
  [#NormalTok("x, y ");#OperatorTok("=");#NormalTok(" np.random.rand(n), np.random.rand(n)  ");],
  [#NormalTok("inside ");#OperatorTok("=");#NormalTok(" (x");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("+");#NormalTok(" y");#OperatorTok("**");#DecValTok("2");#NormalTok(") ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
  [#NormalTok("pi_est ");#OperatorTok("=");#NormalTok(" ");#DecValTok("4");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(inside) ");#OperatorTok("/");#NormalTok(" n  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Estimasi Pi: ");#SpecialCharTok("{");#NormalTok("pi_est");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Tulis fungsi Python untuk mencari threshold optimal pada klasifikasi biner yang meminimalkan Expected Loss diberikan cost matrix.
  - #strong[Solusi:]

  #Skylighting(([#KeywordTok("def");#NormalTok(" optimize_threshold(y_true, y_prob, cost_fp, cost_fn):  ");],
  [#NormalTok("thresholds ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("100");#NormalTok(")  ");],
  [#NormalTok("costs ");#OperatorTok("=");#NormalTok(" []  ");],
  [#ControlFlowTok("for");#NormalTok(" t ");#KeywordTok("in");#NormalTok(" thresholds:  ");],
  [#NormalTok("    y_pred ");#OperatorTok("=");#NormalTok(" (y_prob ");#OperatorTok(">=");#NormalTok(" t).astype(");#BuiltInTok("int");#NormalTok(")  ");],
  [#NormalTok("    fp ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((y_pred ");#OperatorTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (y_true ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok("))  ");],
  [#NormalTok("    fn ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((y_pred ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (y_true ");#OperatorTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok("))  ");],
  [#NormalTok("    costs.append(fp ");#OperatorTok("*");#NormalTok(" cost_fp ");#OperatorTok("+");#NormalTok(" fn ");#OperatorTok("*");#NormalTok(" cost_fn)  ");],
  [#ControlFlowTok("return");#NormalTok(" thresholds[np.argmin(costs)]  ");],));
+ #strong[Soal:] Gunakan metode bootstrap untuk menghitung selang kepercayaan 95% dari median data latensi server.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("data ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("50");#NormalTok(", ");#DecValTok("100");#NormalTok(") ");#CommentTok("# Data sampel  ");],
  [#NormalTok("medians ");#OperatorTok("=");#NormalTok(" [np.median(np.random.choice(data, ");#BuiltInTok("len");#NormalTok("(data), replace");#OperatorTok("=");#VariableTok("True");#NormalTok(")) ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1000");#NormalTok(")]  ");],
  [#NormalTok("ci ");#OperatorTok("=");#NormalTok(" np.percentile(medians, [");#FloatTok("2.5");#NormalTok(", ");#FloatTok("97.5");#NormalTok("])  ");],
  [#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"95% CI Median: ");#SpecialCharTok("{");#NormalTok("ci");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")  ");],));
+ #strong[Soal:] Visualisasikan Hazard Function dari data waktu kegagalan (lifetimes) yang disimulasikan.
  - #strong[Solusi:]

  #Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt  ");],
  [#ImportTok("from");#NormalTok(" lifelines ");#ImportTok("import");#NormalTok(" NelsonAalenFitter ");#CommentTok("# Library khusus survival analysis  ");],
  [#NormalTok("T ");#OperatorTok("=");#NormalTok(" np.random.exponential(");#DecValTok("10");#NormalTok(", ");#DecValTok("100");#NormalTok(") ");#CommentTok("# Data waktu  ");],
  [#NormalTok("naf ");#OperatorTok("=");#NormalTok(" NelsonAalenFitter()  ");],
  [#NormalTok("naf.fit(T)  ");],
  [#NormalTok("naf.plot_hazard(bandwidth");#OperatorTok("=");#DecValTok("5");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
+ #strong[Soal:] Buatlah data simulasi dari Mixture Model (gabungan dua distribusi Normal) dan plot histogramnya.
  - #strong[Solusi:]

  #Skylighting(([#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1000");#NormalTok("  ");],
  [#CommentTok("# 70% dari N(0,1), 30% dari N(5,2)  ");],
  [#NormalTok("data ");#OperatorTok("=");#NormalTok(" np.concatenate([  ");],
  [#NormalTok("np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#BuiltInTok("int");#NormalTok("(");#FloatTok("0.7");#OperatorTok("*");#NormalTok("n)),  ");],
  [#NormalTok("np.random.normal(");#DecValTok("5");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#BuiltInTok("int");#NormalTok("(");#FloatTok("0.3");#OperatorTok("*");#NormalTok("n))  ");],
  [#NormalTok("])  ");],
  [#NormalTok("plt.hist(data, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")  ");],
  [#NormalTok("plt.title(");#StringTok("\"Mixture Model Simulation\"");#NormalTok(")  ");],
  [#NormalTok("plt.show()  ");],));
]

= Minggu 16: Ujian Akhir Semester
<minggu-16-ujian-akhir-semester>
Final Exam

\
#figure([
#box(image("ch/../The_Decision_Engineer.png/image15.png"))
], caption: figure.caption(
position: bottom, 
[
“Final ini menilai satu hal: apakah kamu bisa memodelkan dunia yang tidak pasti lalu mengambil keputusan yang bisa dipertanggungjawabkan. Kamu akan dapat kasus besar. Tugasmu: pilih model, jalankan analisis, tulis keputusan, dan jelaskan konsekuensinya. Ini bukan akhir materi---ini awal cara berpikir.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== 1. Konsep Pengetahuan
<konsep-pengetahuan-13>
Evaluasi menyeluruh materi satu semester.

== 2. Tipikal Problem
<tipikal-problem-13>
Ujian komprehensif studi kasus.

== 3. Solusi & Pengambilan Keputusan
<solusi-pengambilan-keputusan-13>
Menerapkan seluruh konsep probabilitas dan statistik untuk menyelesaikan masalah rekayasa.

== 4. Eksplorasi Komputasi (Python)
<eksplorasi-komputasi-python-15>
#emph[Gunakan sel di bawah ini untuk mengimplementasikan simulasi atau penyelesaian masalah di atas menggunakan Python.]

#block[
#Skylighting(([#CommentTok("# Tulis kode Python Anda di sini");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Siap untuk komputasi Minggu 16!\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Siap untuk komputasi Minggu 16!");],));
]
]
#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#bibliography(("references.bib"))

