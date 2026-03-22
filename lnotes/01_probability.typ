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
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

Berikut adalah #strong[Quiz 10 Soal] yang mencakup materi #strong[Minggu 1: Pendahuluan dan Kerangka Kerja Probabilitas], yang didasarkan pada konsep-konsep seperti Ruang Sampel, Kejadian (#emph[Event]), Operasi Himpunan (Union, Intersection, Komplemen), dan perhitungan probabilitas dasar menggunakan data tabel,,.

Setiap soal disertakan dengan solusi menggunakan bahasa pemrograman #strong[Python].

#horizontalrule

== #strong[Quiz Minggu 1: Konsep Dasar Probabilitas]
<quiz-minggu-1-konsep-dasar-probabilitas>
=== #strong[Soal 1: Ruang Sampel Eksperimen Biner]
<soal-1-ruang-sampel-eksperimen-biner>
Sebuah sistem komunikasi mengirimkan sinyal biner (0 atau 1) sebanyak 3 kali berturut-turut. Tuliskan kode Python untuk men-generate seluruh ruang sampel (semua kemungkinan hasil) dari eksperimen ini.

#strong[Solusi Python:]

#Skylighting(([#ImportTok("import");#NormalTok(" itertools");],
[],
[#CommentTok("# Mendefinisikan kemungkinan hasil untuk satu sinyal");],
[#NormalTok("sinyal ");#OperatorTok("=");],
[],
[#CommentTok("# Menghasilkan Cartesian product untuk 3 pengiriman");],
[#NormalTok("ruang_sampel ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("list");#NormalTok("(itertools.product(sinyal, repeat");#OperatorTok("=");#DecValTok("3");#NormalTok("))");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Ruang Sampel (Total ");#SpecialCharTok("{");#BuiltInTok("len");#NormalTok("(ruang_sampel)");#SpecialCharTok("}");#SpecialStringTok(" elemen):\"");#NormalTok(")");],
[#ControlFlowTok("for");#NormalTok(" hasil ");#KeywordTok("in");#NormalTok(" ruang_sampel:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(hasil)");],));

#horizontalrule

=== #strong[Soal 2: Probabilitas Gabungan (Union)]
<soal-2-probabilitas-gabungan-union>
Diketahui probabilitas kejadian A adalah $P \( A \) = 0.6$, probabilitas kejadian B adalah $P \( B \) = 0.5$, dan probabilitas irisan keduanya $P \( A sect B \) = 0.3$. Hitunglah $P \( A union B \)$.

#strong[Solusi Python:]

#Skylighting(([#NormalTok("P_A ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.6");],
[#NormalTok("P_B ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.5");],
[#NormalTok("P_A_irisan_B ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[],
[#CommentTok("# Menggunakan rumus P(A U B) = P(A) + P(B) - P(A n B)");],
[#NormalTok("P_A_union_B ");#OperatorTok("=");#NormalTok(" P_A ");#OperatorTok("+");#NormalTok(" P_B ");#OperatorTok("-");#NormalTok(" P_A_irisan_B");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Probabilitas P(A U B) adalah: ");#SpecialCharTok("{");#NormalTok("P_A_union_B");#SpecialCharTok(":.2f}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 3: Probabilitas Komplemen]
<soal-3-probabilitas-komplemen>
Dalam sebuah pengujian sirkuit, probabilitas sirkuit lolos uji adalah 0.85. Tentukan probabilitas sirkuit tersebut #strong[gagal] (tidak lolos uji).

#strong[Solusi Python:]

#Skylighting(([#NormalTok("P_Lolos ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.85");],
[],
[#CommentTok("# P(Ac) = 1 - P(A)");],
[#NormalTok("P_Gagal ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" P_Lolos");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Probabilitas Gagal (Komplemen): ");#SpecialCharTok("{");#NormalTok("P_Gagal");#SpecialCharTok(":.2f}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 4: Kejadian Saling Eksklusif (Mutually Exclusive)]
<soal-4-kejadian-saling-eksklusif-mutually-exclusive>
Terdapat tiga kejadian A, B, dan C. Diketahui $P \( A \) = 0.4$, $P \( B \) = 0.35$, dan $P \( C \) = 0.3$. Tentukan apakah ketiga kejadian tersebut bisa bersifat #emph[mutually exclusive] (saling asing) satu sama lain dalam satu ruang sampel yang sama? Buat program untuk mengeceknya.

#strong[Solusi Python:]

#Skylighting(([#NormalTok("P_A ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.4");],
[#NormalTok("P_B ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.35");],
[#NormalTok("P_C ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[],
[#KeywordTok("def");#NormalTok(" cek_mutually_exclusive(probs):");],
[#NormalTok("    total_prob ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(probs)");],
[#NormalTok("    ");#CommentTok("# Jika total probabilitas > 1, maka tidak mungkin mutually exclusive dalam satu ruang sampel");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" total_prob ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("True");#NormalTok(", total_prob");],
[#NormalTok("    ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("False");#NormalTok(", total_prob");],
[],
[#NormalTok("is_possible, total ");#OperatorTok("=");#NormalTok(" cek_mutually_exclusive([P_A, P_B, P_C])");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total Probabilitas: ");#SpecialCharTok("{");#NormalTok("total");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Apakah mungkin Mutually Exclusive? ");#SpecialCharTok("{");#StringTok("'Ya'");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" is_possible ");#ControlFlowTok("else");#NormalTok(" ");#StringTok("'Tidak'");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 5: Analisis Data Tabel (Joint Probability)]
<soal-5-analisis-data-tabel-joint-probability>
Berdasarkan data sampel 100 piringan plastik: - Tahan Gores Tinggi & Tahan Guncang Tinggi = 70 - Tahan Gores Tinggi & Tahan Guncang Rendah = 9 - Tahan Gores Rendah & Tahan Guncang Tinggi = 16 - Tahan Gores Rendah & Tahan Guncang Rendah = 5

Hitung probabilitas sebuah piringan yang dipilih secara acak memiliki #strong[Ketahanan Gores Tinggi DAN Ketahanan Guncang Tinggi].

#strong[Solusi Python:]

#Skylighting(([#CommentTok("# Data");],
[#NormalTok("jumlah_sampel ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("gores_tinggi_guncang_tinggi ");#OperatorTok("=");#NormalTok(" ");#DecValTok("70");],
[],
[#CommentTok("# Probabilitas Joint");],
[#NormalTok("probabilitas ");#OperatorTok("=");#NormalTok(" gores_tinggi_guncang_tinggi ");#OperatorTok("/");#NormalTok(" jumlah_sampel");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(Gores Tinggi n Guncang Tinggi) = ");#SpecialCharTok("{");#NormalTok("probabilitas");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 6: Marginal Probability dari Tabel]
<soal-6-marginal-probability-dari-tabel>
Menggunakan data yang sama dengan Soal 5, hitunglah probabilitas piringan memiliki #strong[Ketahanan Guncang Rendah] (tanpa mempedulikan ketahanan goresnya).

#strong[Solusi Python:]

#Skylighting(([#CommentTok("# Data kejadian yang relevan");],
[#NormalTok("gores_tinggi_guncang_rendah ");#OperatorTok("=");#NormalTok(" ");#DecValTok("9");],
[#NormalTok("gores_rendah_guncang_rendah ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("total_sampel ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[],
[#CommentTok("# Menjumlahkan semua kejadian guncang rendah (Marginal Probability)");],
[#NormalTok("total_guncang_rendah ");#OperatorTok("=");#NormalTok(" gores_tinggi_guncang_rendah ");#OperatorTok("+");#NormalTok(" gores_rendah_guncang_rendah");],
[#NormalTok("prob_guncang_rendah ");#OperatorTok("=");#NormalTok(" total_guncang_rendah ");#OperatorTok("/");#NormalTok(" total_sampel");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(Guncang Rendah) = ");#SpecialCharTok("{");#NormalTok("prob_guncang_rendah");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 7: Hukum De Morgan (Probabilitas)]
<soal-7-hukum-de-morgan-probabilitas>
Diketahui $P \( A union B \) = 0.8$. Hitunglah probabilitas kejadian di mana #strong[tidak A DAN tidak B] terjadi ($P \( A^c sect B^c \)$).

#strong[Solusi Python:]

#Skylighting(([#NormalTok("P_A_union_B ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.8");],
[],
[#CommentTok("# Berdasarkan hukum De Morgan: P(Ac n Bc) = P((A U B)c) = 1 - P(A U B)");],
[#NormalTok("P_Ac_irisan_Bc ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" P_A_union_B");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(Tidak A dan Tidak B) = ");#SpecialCharTok("{");#NormalTok("P_Ac_irisan_Bc");#SpecialCharTok(":.2f}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 8: Conditional Probability Sederhana]
<soal-8-conditional-probability-sederhana>
Dalam sebuah survei terhadap 200 orang, 150 orang menyukai Kopi (A), 100 orang menyukai Teh (B), dan 80 orang menyukai keduanya. Hitung probabilitas seseorang menyukai Teh #strong[jika diketahui] dia menyukai Kopi ($P \( B \| A \)$).

#strong[Solusi Python:]

#Skylighting(([#NormalTok("n_A ");#OperatorTok("=");#NormalTok(" ");#DecValTok("150");#NormalTok("  ");#CommentTok("# Suka Kopi");],
[#NormalTok("n_B ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");#NormalTok("  ");#CommentTok("# Suka Teh");],
[#NormalTok("n_A_irisan_B ");#OperatorTok("=");#NormalTok(" ");#DecValTok("80");#NormalTok(" ");#CommentTok("# Suka Keduanya");],
[],
[#CommentTok("# P(B|A) = n(A n B) / n(A)");],
[#NormalTok("prob_B_given_A ");#OperatorTok("=");#NormalTok(" n_A_irisan_B ");#OperatorTok("/");#NormalTok(" n_A");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"P(Suka Teh | Suka Kopi) = ");#SpecialCharTok("{");#NormalTok("prob_B_given_A");#SpecialCharTok(":.2f}");#SpecialStringTok("\"");#NormalTok(")");],));

#horizontalrule

=== #strong[Soal 9: Ukuran Ruang Sampel (Papan Sirkuit)]
<soal-9-ukuran-ruang-sampel-papan-sirkuit>
Sebuah papan sirkuit diuji. Hasilnya bisa #strong[Lolos] atau #strong[Gagal]. Jika Gagal, sirkuit diperiksa untuk menentukan salah satu dari #strong[5 jenis cacat] yang mungkin. Hitung berapa total titik sampel (#emph[outcome]) yang mungkin terjadi dari eksperimen ini.

#strong[Solusi Python:]

#Skylighting(([#CommentTok("# Kejadian 1: Lolos");],
[#NormalTok("kejadian_lolos ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");],
[],
[#CommentTok("# Kejadian 2: Gagal (dengan 5 sub-kejadian jenis cacat)");],
[#NormalTok("kejadian_gagal ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[],
[#NormalTok("total_titik_sampel ");#OperatorTok("=");#NormalTok(" kejadian_lolos ");#OperatorTok("+");#NormalTok(" kejadian_gagal");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Total titik sampel yang mungkin: ");#SpecialCharTok("{");#NormalTok("total_titik_sampel");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#CommentTok("# Hasilnya adalah {Lolos, Gagal_1, Gagal_2, Gagal_3, Gagal_4, Gagal_5}");],));

#horizontalrule

=== #strong[Soal 10: Frekuensi Relatif]
<soal-10-frekuensi-relatif>
Diberikan data waktu respon server (dalam ms): \`\`. Hitung probabilitas empiris (frekuensi relatif) bahwa waktu respon server #strong[lebih dari 28 ms].

#strong[Solusi Python:]

#Skylighting(([#NormalTok("data_respon ");#OperatorTok("=");],
[],
[#CommentTok("# Menghitung jumlah kejadian > 28");],
[#NormalTok("kejadian_lebih_28 ");#OperatorTok("=");#NormalTok(" [x ");#ControlFlowTok("for");#NormalTok(" x ");#KeywordTok("in");#NormalTok(" data_respon ");#ControlFlowTok("if");#NormalTok(" x ");#OperatorTok(">");#NormalTok(" ");#DecValTok("28");#NormalTok("]");],
[#NormalTok("jumlah_kejadian ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(kejadian_lebih_28)");],
[#NormalTok("total_data ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(data_respon)");],
[],
[#NormalTok("probabilitas ");#OperatorTok("=");#NormalTok(" jumlah_kejadian ");#OperatorTok("/");#NormalTok(" total_data");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Probabilitas waktu respon > 28 ms: ");#SpecialCharTok("{");#NormalTok("probabilitas");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
Tentu, ini adalah versi simulasi Monte Carlo untuk ke-10 soal tersebut. Pendekatan Monte Carlo di sini menggunakan pembangkitan bilangan acak (#emph[random sampling]) dalam jumlah besar untuk mendekati probabilitas teoritis.

Untuk setiap soal, kita akan melakukan eksperimen berulang kali (misalnya 100.000 atau 1.000.000 kali) dan menghitung proporsi kejadian yang memenuhi syarat.

== #strong[Simulasi Monte Carlo: Quiz Minggu 1]
<simulasi-monte-carlo-quiz-minggu-1>
=== #strong[Soal 1: Simulasi Ruang Sampel Eksperimen Biner]
<soal-1-simulasi-ruang-sampel-eksperimen-biner>
Meskipun Monte Carlo biasanya untuk menghitung nilai, kita bisa menggunakannya untuk #emph[mencari] ruang sampel dengan men-generate banyak sampel acak dan menyimpan hasil yang unik.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_sample_space(num_trials");#OperatorTok("=");#DecValTok("1000");#NormalTok("):");],
[#NormalTok("    unique_outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("()");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(num_trials):");],
[#NormalTok("        ");#CommentTok("# Simulasi 3 sinyal (0 atau 1)");],
[#NormalTok("        outcome ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("tuple");#NormalTok("(random.choices(, k");#OperatorTok("=");#DecValTok("3");#NormalTok("))");],
[#NormalTok("        unique_outcomes.add(outcome)");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Mengurutkan hasil agar rapi");],
[#NormalTok("    sorted_outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sorted");#NormalTok("(");#BuiltInTok("list");#NormalTok("(unique_outcomes))");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Ruang Sampel Ditemukan (Total ");#SpecialCharTok("{");#BuiltInTok("len");#NormalTok("(sorted_outcomes)");#SpecialCharTok("}");#SpecialStringTok("):\"");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" out ");#KeywordTok("in");#NormalTok(" sorted_outcomes:");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(out)");],
[],
[#NormalTok("monte_carlo_sample_space()");],));

#horizontalrule

=== #strong[Soal 2: Simulasi Probabilitas Gabungan (Union)]
<soal-2-simulasi-probabilitas-gabungan-union>
Kita akan mensimulasikan kejadian A dan B berdasarkan probabilitas yang diketahui. Karena $P \( A sect B \)$ ditentukan, kita harus membangkitkan data yang berkorelasi sesuai struktur tersebut. #emph[Strategi:] Kita bagi rentang \$\$ menjadi bagian-bagian eksklusif: hanya A, hanya B, keduanya, dan tidak keduanya. \* $P \( upright("hanya ") A \) = P \( A \) - P \( A sect B \) = 0.6 - 0.3 = 0.3$ \* $P \( upright("hanya ") B \) = P \( B \) - P \( A sect B \) = 0.5 - 0.3 = 0.2$ \* $P \( A sect B \) = 0.3$ \* $P \( upright("Lainnya") \) = 1 - \( 0.3 + 0.2 + 0.3 \) = 0.2$

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_union(trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    count_union ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        r ");#OperatorTok("=");#NormalTok(" random.random() ");#CommentTok("# Bilangan acak 0 s.d 1");],
[#NormalTok("        ");],
[#NormalTok("        ");#CommentTok("# Logika pembagian area probabilitas");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" r ");#OperatorTok("<");#NormalTok(" ");#FloatTok("0.3");#NormalTok(":       ");#CommentTok("# Hanya A");],
[#NormalTok("            event_A ");#OperatorTok("=");#NormalTok(" ");#VariableTok("True");],
[#NormalTok("            event_B ");#OperatorTok("=");#NormalTok(" ");#VariableTok("False");],
[#NormalTok("        ");#ControlFlowTok("elif");#NormalTok(" r ");#OperatorTok("<");#NormalTok(" ");#FloatTok("0.5");#NormalTok(":     ");#CommentTok("# Hanya B (0.3 + 0.2)");],
[#NormalTok("            event_A ");#OperatorTok("=");#NormalTok(" ");#VariableTok("False");],
[#NormalTok("            event_B ");#OperatorTok("=");#NormalTok(" ");#VariableTok("True");],
[#NormalTok("        ");#ControlFlowTok("elif");#NormalTok(" r ");#OperatorTok("<");#NormalTok(" ");#FloatTok("0.8");#NormalTok(":     ");#CommentTok("# A dan B (0.5 + 0.3)");],
[#NormalTok("            event_A ");#OperatorTok("=");#NormalTok(" ");#VariableTok("True");],
[#NormalTok("            event_B ");#OperatorTok("=");#NormalTok(" ");#VariableTok("True");],
[#NormalTok("        ");#ControlFlowTok("else");#NormalTok(":             ");#CommentTok("# Tidak keduanya");],
[#NormalTok("            event_A ");#OperatorTok("=");#NormalTok(" ");#VariableTok("False");],
[#NormalTok("            event_B ");#OperatorTok("=");#NormalTok(" ");#VariableTok("False");],
[#NormalTok("            ");],
[#NormalTok("        ");#CommentTok("# Cek Union (A atau B terjadi)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" event_A ");#KeywordTok("or");#NormalTok(" event_B:");],
[#NormalTok("            count_union ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi P(A U B): ");#SpecialCharTok("{");#NormalTok("count_union ");#OperatorTok("/");#NormalTok(" trials");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Teoritis P(A U B): 0.80\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_union()");],));

#horizontalrule

=== #strong[Soal 3: Simulasi Probabilitas Komplemen]
<soal-3-simulasi-probabilitas-komplemen>
Simulasi sederhana dengan #emph[Bernoulli Trial].

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_complement(trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    p_lolos ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.85");],
[#NormalTok("    count_gagal ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        ");#CommentTok("# Generate hasil tes (Lolos jika random < 0.85)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" random.random() ");#OperatorTok(">=");#NormalTok(" p_lolos:");],
[#NormalTok("            count_gagal ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi P(Gagal): ");#SpecialCharTok("{");#NormalTok("count_gagal ");#OperatorTok("/");#NormalTok(" trials");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Teoritis P(Gagal): ");#SpecialCharTok("{");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" p_lolos");#SpecialCharTok(":.2f}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_complement()");],));

#horizontalrule

=== #strong[Soal 4: Simulasi Mutually Exclusive]
<soal-4-simulasi-mutually-exclusive>
Kita akan mencoba menempatkan kejadian A, B, dan C pada satu garis bilangan \$\$ tanpa tumpang tindih. Jika total panjang \> 1, simulasi akan menunjukkan "tabrakan" atau ketidakmungkinan.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_mutually_exclusive(probs, trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    total_req ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("(probs)");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" total_req ");#OperatorTok(">");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Simulasi: Tidak mungkin Mutually Exclusive (Total Probabilitas > 1)\"");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("return");],
[],
[#NormalTok("    ");#CommentTok("# Jika mungkin, kita simulasi kejadiannya");],
[#NormalTok("    counts ");#OperatorTok("=");#NormalTok(" {i: ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(probs))}");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Membuat batas kumulatif");],
[#NormalTok("    boundaries ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    current ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" probs:");],
[#NormalTok("        current ");#OperatorTok("+=");#NormalTok(" p");],
[#NormalTok("        boundaries.append(current)");],
[#NormalTok("        ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        r ");#OperatorTok("=");#NormalTok(" random.random()");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" i, bound ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("enumerate");#NormalTok("(boundaries):");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" r ");#OperatorTok("<");#NormalTok(" bound:");],
[#NormalTok("                counts[i] ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("                ");#ControlFlowTok("break");#NormalTok(" ");#CommentTok("# Karena mutually exclusive, hanya satu yang bisa terjadi");],
[#NormalTok("                ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Simulasi Frekuensi Relatif:\"");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" i, count ");#KeywordTok("in");#NormalTok(" counts.items():");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Event ");#SpecialCharTok("{");#NormalTok("i");#SpecialCharTok("}");#SpecialStringTok(": ");#SpecialCharTok("{");#NormalTok("count");#OperatorTok("/");#NormalTok("trials");#SpecialCharTok(":.4f}");#SpecialStringTok(" (Target: ");#SpecialCharTok("{");#NormalTok("probs[i]");#SpecialCharTok("}");#SpecialStringTok(")\"");#NormalTok(")");],
[],
[#CommentTok("# Test Case");],
[#NormalTok("monte_carlo_mutually_exclusive([");#FloatTok("0.4");#NormalTok(", ");#FloatTok("0.35");#NormalTok(", ");#FloatTok("0.3");#NormalTok("]) ");],));

#horizontalrule

=== #strong[Soal 5: Simulasi Data Tabel (Joint Probability)]
<soal-5-simulasi-data-tabel-joint-probability>
Kita akan membuat "populasi buatan" berdasarkan data tabel, lalu mengambil sampel secara acak (#emph[sampling]).

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_joint_prob(trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    ");#CommentTok("# Membuat populasi berdasarkan data tabel");],
[#NormalTok("    ");#CommentTok("# Format: (Gores, Guncang) -> (Tinggi=1/Rendah=0, Tinggi=1/Rendah=0)");],
[#NormalTok("    populasi ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    populasi.extend([(");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("70");#NormalTok(") ");#CommentTok("# Gores T, Guncang T");],
[#NormalTok("    populasi.extend([(");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("9");#NormalTok(")  ");#CommentTok("# Gores T, Guncang R");],
[#NormalTok("    populasi.extend([(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("16");#NormalTok(") ");#CommentTok("# Gores R, Guncang T");],
[#NormalTok("    populasi.extend([(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("5");#NormalTok(")  ");#CommentTok("# Gores R, Guncang R");],
[#NormalTok("    ");],
[#NormalTok("    count_event ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        ");#CommentTok("# Ambil satu sampel secara acak");],
[#NormalTok("        sampel ");#OperatorTok("=");#NormalTok(" random.choice(populasi)");],
[#NormalTok("        ");],
[#NormalTok("        ");#CommentTok("# Cek kondisi: Gores Tinggi (1) DAN Guncang Tinggi (1)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" sampel ");#OperatorTok("==");#NormalTok(" (");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("            count_event ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi Joint Probability: ");#SpecialCharTok("{");#NormalTok("count_event ");#OperatorTok("/");#NormalTok(" trials");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Teoritis: 0.70\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_joint_prob()");],));

#horizontalrule

=== #strong[Soal 6: Simulasi Marginal Probability]
<soal-6-simulasi-marginal-probability>
Menggunakan populasi yang sama dengan Soal 5, tapi kondisi pengecekannya berbeda.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_marginal(trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    ");#CommentTok("# Populasi sama seperti di atas");],
[#NormalTok("    populasi ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    populasi.extend([(");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("70");#NormalTok(") ");],
[#NormalTok("    populasi.extend([(");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("9");#NormalTok(") ");],
[#NormalTok("    populasi.extend([(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("16");#NormalTok(") ");],
[#NormalTok("    populasi.extend([(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("5");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    count_guncang_rendah ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        sampel ");#OperatorTok("=");#NormalTok(" random.choice(populasi)");],
[#NormalTok("        ");#CommentTok("# Indeks 1 adalah ketahanan guncang (0 = Rendah)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" sampel ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            count_guncang_rendah ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi P(Guncang Rendah): ");#SpecialCharTok("{");#NormalTok("count_guncang_rendah ");#OperatorTok("/");#NormalTok(" trials");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Teoritis: 0.14\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_marginal()");],));

#horizontalrule

=== #strong[Soal 7: Simulasi Hukum De Morgan]
<soal-7-simulasi-hukum-de-morgan>
Simulasi ini mirip dengan Soal 2, kita mendefinisikan area probabilitas. Diketahui $P \( A union B \) = 0.8$. Artinya probabilitas "di luar" A atau B adalah $1 - 0.8 = 0.2$.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_demorgan(trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    ");#CommentTok("# Kita asumsikan P(A U B) menempati rentang 0.0 s.d 0.8");],
[#NormalTok("    ");#CommentTok("# Maka P(A' n B') adalah area > 0.8");],
[#NormalTok("    limit_union ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.8");],
[#NormalTok("    count_notA_and_notB ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        r ");#OperatorTok("=");#NormalTok(" random.random()");],
[#NormalTok("        ");],
[#NormalTok("        ");#CommentTok("# Logika: Jika r <= 0.8, maka dia masuk area Union (Entah A, Entah B, atau Keduanya)");],
[#NormalTok("        is_in_union ");#OperatorTok("=");#NormalTok(" r ");#OperatorTok("<=");#NormalTok(" limit_union");],
[#NormalTok("        ");],
[#NormalTok("        ");#CommentTok("# De Morgan: Tidak A DAN Tidak B adalah komplemen dari Union");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" ");#KeywordTok("not");#NormalTok(" is_in_union:");],
[#NormalTok("            count_notA_and_notB ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi P(A' n B'): ");#SpecialCharTok("{");#NormalTok("count_notA_and_notB ");#OperatorTok("/");#NormalTok(" trials");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Teoritis: 0.20\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_demorgan()");],));

#horizontalrule

=== #strong[Soal 8: Simulasi Conditional Probability]
<soal-8-simulasi-conditional-probability>
Untuk menghitung $P \( B \| A \)$, kita menggunakan teknik #emph[rejection sampling]. Kita hanya menghitung percobaan di mana kejadian syarat (A) terjadi.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_conditional(trials");#OperatorTok("=");#DecValTok("100000");#NormalTok("):");],
[#NormalTok("    ");#CommentTok("# Representasi Populasi 200 orang");],
[#NormalTok("    ");#CommentTok("# A = Kopi, B = Teh");],
[#NormalTok("    populasi ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 80 Suka Keduanya (A=1, B=1)");],
[#NormalTok("    populasi.extend([(");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("80");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 70 Suka Kopi Saja (A=1, B=0) -> Total Kopi 150 (150-80=70)");],
[#NormalTok("    populasi.extend([(");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("70");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 20 Suka Teh Saja (A=0, B=1) -> Total Teh 100 (100-80=20)");],
[#NormalTok("    populasi.extend([(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("20");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# 30 Tidak Suka Keduanya (Sisa populasi: 200 - 80 - 70 - 20)");],
[#NormalTok("    populasi.extend([(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(")] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("30");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    count_A_occurred ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    count_B_given_A ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        sampel ");#OperatorTok("=");#NormalTok(" random.choice(populasi)");],
[#NormalTok("        ");],
[#NormalTok("        ");#CommentTok("# Syarat: Diketahui Suka Kopi (A=1)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" sampel ");#OperatorTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("            count_A_occurred ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");#CommentTok("# Cek apakah juga suka Teh (B=1)");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" sampel ");#OperatorTok("==");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("                count_B_given_A ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("    ");],
[#NormalTok("    prob ");#OperatorTok("=");#NormalTok(" count_B_given_A ");#OperatorTok("/");#NormalTok(" count_A_occurred");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi P(Teh | Kopi): ");#SpecialCharTok("{");#NormalTok("prob");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Teoritis: ");#SpecialCharTok("{");#DecValTok("80");#OperatorTok("/");#DecValTok("150");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_conditional()");],));

#horizontalrule

=== #strong[Soal 9: Simulasi Pembangkitan Titik Sampel]
<soal-9-simulasi-pembangkitan-titik-sampel>
Mirip dengan soal 1, kita men-generate kejadian secara acak untuk melihat variasi hasil yang mungkin terjadi.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_sample_points(trials");#OperatorTok("=");#DecValTok("1000");#NormalTok("):");],
[#NormalTok("    outcomes ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("()");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        ");#CommentTok("# Tahap 1: Uji Lolos/Gagal");],
[#NormalTok("        ");#CommentTok("# Asumsi probabilitas 50:50 untuk tujuan eksplorasi ruang sampel");],
[#NormalTok("        status ");#OperatorTok("=");#NormalTok(" random.choice([");#StringTok("'Lolos'");#NormalTok(", ");#StringTok("'Gagal'");#NormalTok("])");],
[#NormalTok("        ");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" status ");#OperatorTok("==");#NormalTok(" ");#StringTok("'Lolos'");#NormalTok(":");],
[#NormalTok("            outcomes.add(");#StringTok("'Lolos'");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("            ");#CommentTok("# Tahap 2: Jika Gagal, cek jenis cacat (1-5)");],
[#NormalTok("            cacat ");#OperatorTok("=");#NormalTok(" random.randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok(")");],
[#NormalTok("            outcomes.add(");#SpecialStringTok("f'Gagal_Tipe_");#SpecialCharTok("{");#NormalTok("cacat");#SpecialCharTok("}");#SpecialStringTok("'");#NormalTok(")");],
[#NormalTok("            ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Titik Sampel ditemukan (");#SpecialCharTok("{");#BuiltInTok("len");#NormalTok("(outcomes)");#SpecialCharTok("}");#SpecialStringTok("):\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#BuiltInTok("sorted");#NormalTok("(");#BuiltInTok("list");#NormalTok("(outcomes)))");],
[],
[#NormalTok("monte_carlo_sample_points()");],));

#horizontalrule

=== #strong[Soal 10: Simulasi Bootstrap (Resampling)]
<soal-10-simulasi-bootstrap-resampling>
Untuk data empiris yang kecil, teknik Monte Carlo yang relevan adalah #emph[Bootstrap Resampling]. Kita mengambil sampel berulang kali dari data yang ada untuk mengestimasi distribusi probabilitasnya.

#Skylighting(([#ImportTok("import");#NormalTok(" random");],
[],
[#KeywordTok("def");#NormalTok(" monte_carlo_bootstrap(trials");#OperatorTok("=");#DecValTok("50000");#NormalTok("):");],
[#NormalTok("    data_asli ");#OperatorTok("=");],
[#NormalTok("    count_lebih_28 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    total_samples ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(trials):");],
[#NormalTok("        ");#CommentTok("# Mengambil satu data secara acak dari data asli (resampling with replacement)");],
[#NormalTok("        ");#CommentTok("# Dalam konteks probabilitas empiris sederhana, ini konvergen ke frekuensi relatif");],
[#NormalTok("        sampel ");#OperatorTok("=");#NormalTok(" random.choice(data_asli)");],
[#NormalTok("        total_samples ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("        ");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" sampel ");#OperatorTok(">");#NormalTok(" ");#DecValTok("28");#NormalTok(":");],
[#NormalTok("            count_lebih_28 ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            ");],
[#NormalTok("    prob ");#OperatorTok("=");#NormalTok(" count_lebih_28 ");#OperatorTok("/");#NormalTok(" total_samples");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Simulasi (Resampling) P(X > 28): ");#SpecialCharTok("{");#NormalTok("prob");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Hitungan Eksak Python sebelumnya");],
[#NormalTok("    real_count ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("([x ");#ControlFlowTok("for");#NormalTok(" x ");#KeywordTok("in");#NormalTok(" data_asli ");#ControlFlowTok("if");#NormalTok(" x ");#OperatorTok(">");#NormalTok(" ");#DecValTok("28");#NormalTok("])");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Hitungan Manual: ");#SpecialCharTok("{");#NormalTok("real_count");#OperatorTok("/");#BuiltInTok("len");#NormalTok("(data_asli)");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("monte_carlo_bootstrap()");],));



