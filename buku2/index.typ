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

#heading(level: 1, numbering: none)[Preface]
<preface>
This is a Quarto book.

To learn more about Quarto books visit #link("https://quarto.org/docs/books").

= Introduction
<introduction>
This is a book created from markdown and executable code.

See #cite(<knuth84>, form: "prose") for additional discussion of literate programming.

= Kita Beri Garansi Berapa Lama?
<kita-beri-garansi-berapa-lama>
\[\# Random Variable Kontinu

#figure([
#box(image("./The_Decision_Engineer.png/image7.png"))
], caption: figure.caption(
position: bottom, 
[
“Lampu rata-rata hidup 900 jam, simpangan 50 jam. Kamu mau kasih garansi 700 jam, 800 jam, atau 900 jam? Ini bukan sekadar ‘baik hati'---ini strategi biaya klaim. Normal sering muncul di data pengukuran; eksponensial sering muncul di waktu tunggu. Hari ini kamu belajar menghitung peluang rusak sebelum waktu T, lalu menentukan T yang masuk akal untuk target klaim. Kamu akan melihat: statistik bisa jadi alat desain produk.”
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== Live Coding: "Normal is Everywhere"
<live-coding-normal-is-everywhere>
Misalnya suatu pabrik bisa menghasilkan 10000 lampu pertahun yang bisa bekerja rata-rata 900 jam, meskipun dalam kenyataanya individual lampu bisa mati bervariasi setelah suatu angka jam positif yang random. Seberapa besar varians ini diukur oleh besaran deviasi, misalnya 50 jam yang berarti variance 2500 jam^2

Suatu variable random bisa memiliki #emph[probability density function] (pdf) berbentuk lonceng, dengan dua parameter $mu$ dan $sigma$.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#CommentTok("# Instantiate a default random number generator");],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng()");],));
]
Untuk distribusi normal standar, lokasi titik tengah = 0 dan deviasi standar = 1.

#block[
#Skylighting(([#CommentTok("# Generate a single random number from the standard normal distribution (mean=0, std=1)");],
[#NormalTok("sample_scalar ");#OperatorTok("=");#NormalTok(" rng.normal()");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"1. Single sample: ");#SpecialCharTok("{");#NormalTok("sample_scalar");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("1. Single sample: -0.04657625240198787");],));
]
]
Dalam kasus kita lokasi titik tengah = 900 dan deviasi standar = 50. Kita ukur waktu hidup 5 buah lampu, maka berapa jam hidup sampai lampu ini mati?

#block[
#Skylighting(([#NormalTok("mu ");#OperatorTok("=");#NormalTok(" ");#DecValTok("900");],
[#NormalTok("sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");],
[],
[#CommentTok("# Generate a 1D array of 5 numbers with mean=900, standard deviation=50");],
[#NormalTok("samples_1d ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma, size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"2. 1D array: ");#SpecialCharTok("{");#NormalTok("samples_1d");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("2. 1D array: [ 966.61596593  938.90906854  939.52041278  864.42804026 1043.27082055]");],));
]
]
Berbeda beda yaitu: np.float64(966.6159659252387)

+ Generate data acak #NormalTok("numpy.random.normal");.
+ Tunjukkan aturan empiris: 68% data ada di $mu plus.minus sigma$, 95% di $mu plus.minus 2 sigma$.
+ Visualisasi: Plot kurva lonceng dengan seaborn dan arsir area probabilitas. kita coba untuk 10000

#Skylighting(([#NormalTok("N");#OperatorTok("=");#NormalTok(" ");#DecValTok("10000");],
[],
[#NormalTok("data ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma, size");#OperatorTok("=");#NormalTok("N)");],
[#NormalTok("np.histogram(data, bins");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],));
#Skylighting(([#NormalTok("(array([  31,  150,  678, 1616, 2647, 2557, 1581,  580,  141,   19]),");],
[#NormalTok(" array([ 725.96325526,  760.93493061,  795.90660597,  830.87828132,");],
[#NormalTok("         865.84995668,  900.82163203,  935.79330739,  970.76498274,");],
[#NormalTok("        1005.7366581 , 1040.70833345, 1075.68000881]))");],));
Kita hitung berapa data antara 1. $850 < X < 950$ 2. $800 < X < 1000$ 3. $750 < X < 1050$

#block[
#Skylighting(([#NormalTok("counter1");#OperatorTok("=");#DecValTok("0");],
[#NormalTok("counter2");#OperatorTok("=");#DecValTok("0");],
[#NormalTok("counter3");#OperatorTok("=");#DecValTok("0");],
[#ControlFlowTok("for");#NormalTok(" n ");#KeywordTok("in");#NormalTok(" data:");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" n ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("850");#NormalTok(" ");#KeywordTok("and");#NormalTok(" n ");#OperatorTok("<");#NormalTok(" ");#DecValTok("950");#NormalTok(":");],
[#NormalTok("        counter1 ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");#NormalTok("  ");],
[#NormalTok("    ");#ControlFlowTok("elif");#NormalTok(" n ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("800");#NormalTok(" ");#KeywordTok("and");#NormalTok(" n ");#OperatorTok("<");#NormalTok(" ");#DecValTok("1000");#NormalTok(":");],
[#NormalTok("        counter2 ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("    ");#ControlFlowTok("elif");#NormalTok(" n ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("750");#NormalTok(" ");#KeywordTok("and");#NormalTok(" n ");#OperatorTok("<");#NormalTok(" ");#DecValTok("1050");#NormalTok(":");],
[#NormalTok("        counter3 ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[],
[#BuiltInTok("print");#NormalTok("(counter1");#OperatorTok("/");#NormalTok("N, (counter1");#OperatorTok("+");#NormalTok("counter2)");#OperatorTok("/");#NormalTok("N, (counter1");#OperatorTok("+");#NormalTok("counter2");#OperatorTok("+");#NormalTok("counter3)");#OperatorTok("/");#NormalTok("N)");],));
#block[
#Skylighting(([#NormalTok("0.6826 0.9558 0.9974");],));
]
]
#Skylighting(([#CommentTok("# 3. Menambahkan label dan judul");],
[#NormalTok("plt.hist(data,bins");#OperatorTok("=");#DecValTok("10");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("'Histogram Normal Distribution (NumPy)'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("'Value'");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("'Density'");#NormalTok(")");],
[#NormalTok("plt.grid(axis");#OperatorTok("=");#StringTok("'y'");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[],
[#CommentTok("# 4. Menampilkan plot");],
[#NormalTok("plt.show()");],));
#box(image("chapter07_files/figure-typst/cell-7-output-1.svg"))

Jadi kita hendak beri garansi berapa jam kalau kita tahu berapa ongkos produksi (misalnya \$5), berapa harga jual (misalnya \$10), dan berapa biaya penggantian garansi (misalnya \$7). Bila garansi terlalu rendah, produk ini kalah bersaing. Misalnya kita hendak memilih antara garansi 750 jam, 800 jam, dan Karena rata-rata 900 jam, dari 10000 yang diproduksi kita hitung berapa yang rusak, lalu kita hitung biaya serta pengaruh pada profit. Asumsi deviasi 50 atau 100.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#CommentTok("# Parameter");],
[#NormalTok("n_units ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10000");],
[#NormalTok("mu ");#OperatorTok("=");#NormalTok(" ");#DecValTok("900");#NormalTok("      ");#CommentTok("# mean umur lampu");],
[#NormalTok("sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");#NormalTok("    ");#CommentTok("# std dev");],
[],
[#NormalTok("price ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[#NormalTok("cost ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("warranty_cost ");#OperatorTok("=");#NormalTok(" ");#DecValTok("7");],
[#NormalTok("nrg ");#OperatorTok("=");#NormalTok(" np.random.default_rng()");],
[#CommentTok("# Generate umur lampu (random normal)");],
[#CommentTok("# nrg.seed(42)  # agar reproducible");],
[#NormalTok("lifetimes ");#OperatorTok("=");#NormalTok(" nrg.normal(mu, sigma, n_units)");],
[],
[#CommentTok("# Fungsi hitung profit");],
[#KeywordTok("def");#NormalTok(" simulate_profit(lifetimes, warranty_limit):");],
[#NormalTok("    profit_per_unit ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("    ");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" life ");#KeywordTok("in");#NormalTok(" lifetimes:");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" life ");#OperatorTok("<");#NormalTok(" warranty_limit:");],
[#NormalTok("            ");#CommentTok("# kena klaim garansi");],
[#NormalTok("            profit ");#OperatorTok("=");#NormalTok(" price ");#OperatorTok("-");#NormalTok(" cost ");#OperatorTok("-");#NormalTok(" warranty_cost");],
[#NormalTok("        ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("            ");#CommentTok("# tidak klaim");],
[#NormalTok("            profit ");#OperatorTok("=");#NormalTok(" price ");#OperatorTok("-");#NormalTok(" cost");],
[#NormalTok("        profit_per_unit.append(profit)");],
[#NormalTok("    ");],
[#NormalTok("    total_profit ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(profit_per_unit)");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" total_profit");],
[],
[#CommentTok("# Simulasi");],
[#NormalTok("profit_A ");#OperatorTok("=");#NormalTok(" simulate_profit(lifetimes, ");#DecValTok("850");#NormalTok(")");],
[#NormalTok("profit_B ");#OperatorTok("=");#NormalTok(" simulate_profit(lifetimes, ");#DecValTok("800");#NormalTok(")");],
[#NormalTok("profit_C ");#OperatorTok("=");#NormalTok(" simulate_profit(lifetimes, ");#DecValTok("750");#NormalTok(")");],
[],
[#CommentTok("# Output hasil");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"=== HASIL SIMULASI ===\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Profit Garansi A (850 jam): $");#SpecialCharTok("{");#NormalTok("profit_A");#SpecialCharTok(":,.2f}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Profit Garansi B (800 jam): $");#SpecialCharTok("{");#NormalTok("profit_B");#SpecialCharTok(":,.2f}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Profit Garansi C (700 jam): $");#SpecialCharTok("{");#NormalTok("profit_C");#SpecialCharTok(":,.2f}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#CommentTok("# Bandingkan");],
[#ControlFlowTok("if");#NormalTok(" profit_A ");#OperatorTok(">");#NormalTok(" profit_B ");#KeywordTok("and");#NormalTok(" profit_A ");#OperatorTok(">");#NormalTok(" profit_C:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rekomendasi: Garansi A lebih menguntungkan\"");#NormalTok(")");],
[#ControlFlowTok("elif");#NormalTok(" profit_B ");#OperatorTok(">");#NormalTok(" profit_C:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rekomendasi: Garansi B lebih menguntungkan\"");#NormalTok(")");],
[#ControlFlowTok("else");#NormalTok(": ");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"Rekomendasi: Garansi C lebih menguntungkan\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("=== HASIL SIMULASI ===");],
[#NormalTok("Profit Garansi A (850 jam): $38,562.00");],
[#NormalTok("Profit Garansi B (800 jam): $48,418.00");],
[#NormalTok("Profit Garansi C (700 jam): $49,916.00");],
[#NormalTok("Rekomendasi: Garansi C lebih menguntungkan");],));
]
]
#block[
#Skylighting(([#CommentTok("# Generate a 2x3 matrix with default parameters");],
[#NormalTok("samples_2d ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"3. 2D array:");#CharTok("\\n");#SpecialCharTok("{");#NormalTok("samples_2d");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("3. 2D array:");],
[#NormalTok("[[-0.16298189  0.9681246  -0.58785859]");],
[#NormalTok(" [ 1.84399774  1.24289279  0.16475956]]");],));
]
]
Masalah penentuan waktu garansi ini pada dasarnya adalah masalah optimasi risiko yang menggabungkan Nilai Harapan (#emph[Expected Value]) dan Fungsi Distribusi Kumulatif (CDF) dari probabilitas kegagalan lampu.

#strong[\1. Pemodelan Bisnis & Keuntungan (Profit)] Untuk menganalisis pengaruh garansi terhadap profit, kita memodelkannya dengan persamaan ekspektasi bisnis berikut:

- #strong[Total Pendapatan:] $10.000 upright(" lampu") times \$ 10 = \$ 100.000$

- #strong[Total Ongkos Produksi:] $10.000 upright(" lampu") times \$ 5 = \$ 50.000$

- #strong[Profit Dasar (Tanpa Klaim):] $\$ 100.000 - \$ 50.000 = \$ 50.000$

- #strong[Biaya Klaim Garansi:] $upright("Jumlah lampu rusak") times \$ 7$ \* #strong[Jumlah Lampu Rusak:] $10.000 times P \( X < T_w \)$, di mana $P \( X < T_w \)$ adalah probabilitas (#emph[Cumulative Distribution Function]/CDF) sebuah lampu mati sebelum waktu garansi $T_w$ habis.

== Beda Pabrik, Beda Karakter Lampu
<beda-pabrik-beda-karakter-lampu>
Asumsi beda teknologi menyebabkan beda distribusi probabilitas lifetime lampu, meskipun rata-rata dan deviasi nya sama.

#strong[\2. Karakteristik Fungsi Distribusi Kumulatif (CDF)] Untuk membandingkan probabilitas kegagalan $P \( X < T_w \)$, kita mengevaluasi 4 jenis distribusi:

- #strong[Distribusi Normal:] Menggunakan parameter mean $mu = 900$ dan standar deviasi $sigma in { 50 \, 100 }$. CDF dihitung menggunakan standarisasi $Z = \( X - mu \) \/ sigma$.

- #strong[Distribusi Seragam (Uniform):] Karena variansi berdistribusi seragam adalah $frac(\( b - a \)^2, 12)$, kita dapat menentukan rentang umur lampu minimum $a$ dan maksimum $b$ berdasarkan $mu = 900$ dan $sigma in { 50 \, 100 }$.

- #strong[Distribusi Weibull:] Sangat ideal dan umum digunakan untuk memodelkan laju kegagalan umur komponen (fungsi #emph[hazard]/#emph[survival]). Parameter #emph[shape] ($k$) dan #emph[scale] ($lambda$) dapat dicari melalui persamaan non-linear yang dicocokkan dengan $mu$ dan $sigma$.

- #strong[Distribusi Eksponensial:] Distribusi ini tidak memiliki memori (#emph[memoryless]) dan variasinya selalu sama dengan rata-ratanya. Oleh karena itu, parameter $sigma = 50$ atau $100$ diabaikan, dan perhitungan hanya murni bergantung pada laju kerusakan $lambda = 1 \/ 900$.

#strong[\3. Solusi Skrip Python] Berikut adalah desain #emph[class] Python yang mensimulasikan dan mengembalikan #emph[dictionary] untuk membandingkan jumlah kerusakan, biaya, dan profit dari penentuan garansi (misal 750 jam dan 800 jam) di keempat distribusi di atas.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[#ImportTok("from");#NormalTok(" scipy.optimize ");#ImportTok("import");#NormalTok(" fsolve");],
[#ImportTok("from");#NormalTok(" scipy.special ");#ImportTok("import");#NormalTok(" gamma");],
[#ImportTok("import");#NormalTok(" json");],
[],
[#KeywordTok("class");#NormalTok(" WarrantyAnalyzer:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", mu");#OperatorTok("=");#DecValTok("900");#NormalTok(", N");#OperatorTok("=");#DecValTok("10000");#NormalTok(", cost");#OperatorTok("=");#DecValTok("5");#NormalTok(", price");#OperatorTok("=");#DecValTok("10");#NormalTok(", replacement_cost");#OperatorTok("=");#DecValTok("7");#NormalTok("):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".mu ");#OperatorTok("=");#NormalTok(" mu");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".N ");#OperatorTok("=");#NormalTok(" N");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".base_profit ");#OperatorTok("=");#NormalTok(" N ");#OperatorTok("*");#NormalTok(" (price ");#OperatorTok("-");#NormalTok(" cost)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".rep_cost ");#OperatorTok("=");#NormalTok(" replacement_cost");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _get_weibull_params(");#VariableTok("self");#NormalTok(", sigma):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Mencari parameter Weibull (k=shape, lam=scale) ");],
[#CommentTok("        berdasarkan mu (mean) dan sigma (standar deviasi).");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#KeywordTok("def");#NormalTok(" equation(k):");],
[#NormalTok("            ");#CommentTok("# Variansi Weibull = lam^2 * [Gamma(1+2/k) - Gamma(1+1/k)^2]");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" (gamma(");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#DecValTok("2");#OperatorTok("/");#NormalTok("k) ");#OperatorTok("/");#NormalTok(" (gamma(");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#OperatorTok("/");#NormalTok("k)");#OperatorTok("**");#DecValTok("2");#NormalTok(")) ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" (sigma");#OperatorTok("**");#DecValTok("2");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu");#OperatorTok("**");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        ");],
[#NormalTok("        ");#CommentTok("# Mencari nilai shape (k) secara numerik");],
[#NormalTok("        k_opt ");#OperatorTok("=");#NormalTok(" fsolve(equation, ");#FloatTok("5.0");#NormalTok(")");],
[#NormalTok("        ");#CommentTok("# Menghitung nilai scale (lam)");],
[#NormalTok("        lam_opt ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu ");#OperatorTok("/");#NormalTok(" gamma(");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#OperatorTok("/");#NormalTok("k_opt)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" k_opt, lam_opt");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" analyze(");#VariableTok("self");#NormalTok(", warranty_hours, sigmas):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Menghasilkan dictionary perbandingan profit berdasarkan ");],
[#CommentTok("        distribusi, waktu garansi, dan standar deviasi.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        results ");#OperatorTok("=");#NormalTok(" {}");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" w ");#KeywordTok("in");#NormalTok(" warranty_hours:");],
[#NormalTok("            results[");#SpecialStringTok("f\"Garansi_");#SpecialCharTok("{");#NormalTok("w");#SpecialCharTok("}");#SpecialStringTok("_Jam\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" {}");],
[#NormalTok("            ");#CommentTok("# print(f\"===Garansi_{w}_Jam===\")");],
[#NormalTok("            ");#ControlFlowTok("for");#NormalTok(" sig ");#KeywordTok("in");#NormalTok(" sigmas:");],
[#NormalTok("                ");#CommentTok("# print(f\"**Sigma_{sig}**\")");],
[#NormalTok("                ");#CommentTok("# 1. Distribusi Normal CDF");],
[#NormalTok("                p_norm ");#OperatorTok("=");#NormalTok(" stats.norm.cdf(w, loc");#OperatorTok("=");#VariableTok("self");#NormalTok(".mu, scale");#OperatorTok("=");#NormalTok("sig)");],
[],
[#NormalTok("                ");#CommentTok("# 2. Distribusi Seragam (Uniform) CDF");],
[#NormalTok("                ");#CommentTok("# Var = (b-a)^2 / 12 = sig^2  -->  b-a = sig * sqrt(12)");],
[#NormalTok("                a ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu ");#OperatorTok("-");#NormalTok(" np.sqrt(");#DecValTok("3");#NormalTok(") ");#OperatorTok("*");#NormalTok(" sig");],
[#NormalTok("                b ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu ");#OperatorTok("+");#NormalTok(" np.sqrt(");#DecValTok("3");#NormalTok(") ");#OperatorTok("*");#NormalTok(" sig");],
[#NormalTok("                p_uni ");#OperatorTok("=");#NormalTok(" stats.uniform.cdf(w, loc");#OperatorTok("=");#NormalTok("a, scale");#OperatorTok("=");#NormalTok("b");#OperatorTok("-");#NormalTok("a)");],
[],
[#NormalTok("                ");#CommentTok("# 3. Distribusi Weibull CDF");],
[#NormalTok("                k, lam ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok("._get_weibull_params(sig)");],
[#NormalTok("                p_weib ");#OperatorTok("=");#NormalTok(" stats.weibull_min.cdf(w, c");#OperatorTok("=");#NormalTok("k, scale");#OperatorTok("=");#NormalTok("lam)");],
[],
[#NormalTok("                ");#CommentTok("# 4. Distribusi Eksponensial CDF (Hanya bergantung pada mu)");],
[#NormalTok("                p_exp ");#OperatorTok("=");#NormalTok(" stats.expon.cdf(w, scale");#OperatorTok("=");#VariableTok("self");#NormalTok(".mu)");],
[],
[#NormalTok("                dist_probs ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("                    ");#StringTok("'Normal'");#NormalTok(": p_norm,");],
[#NormalTok("                    ");#StringTok("'Uniform'");#NormalTok(": p_uni,");],
[#NormalTok("                    ");#StringTok("'Weibull'");#NormalTok(": p_weib,");],
[#NormalTok("                    ");#StringTok("'Eksponensial'");#NormalTok(": p_exp");],
[#NormalTok("                }");],
[],
[#NormalTok("                profit_comparison ");#OperatorTok("=");#NormalTok(" {}");],
[#NormalTok("                ");#ControlFlowTok("for");#NormalTok(" dist_name, p_fail ");#KeywordTok("in");#NormalTok(" dist_probs.items():");],
[#NormalTok("                    ");#CommentTok("# Kalkulasi Bisnis");],
[#NormalTok("                    n_fail ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".N ");#OperatorTok("*");#NormalTok(" p_fail");],
[#NormalTok("                    total_warranty_cost ");#OperatorTok("=");#NormalTok(" n_fail ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".rep_cost");],
[#NormalTok("                    profit ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".base_profit ");#OperatorTok("-");#NormalTok(" total_warranty_cost");],
[],
[#NormalTok("                    profit_comparison[dist_name] ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("                        ");#StringTok("'Probabilitas_Mati'");#NormalTok(": np.");#BuiltInTok("round");#NormalTok("(p_fail, ");#DecValTok("4");#NormalTok("),");],
[#NormalTok("                        ");#StringTok("'Jumlah_Rusak'");#NormalTok(": np.");#BuiltInTok("round");#NormalTok("(n_fail,");#DecValTok("0");#NormalTok("),");],
[#NormalTok("                        ");#StringTok("'Biaya_Garansi ($)'");#NormalTok(": np.");#BuiltInTok("round");#NormalTok("(total_warranty_cost, ");#DecValTok("2");#NormalTok("),");],
[#NormalTok("                        ");#StringTok("'Profit_Akhir ($)'");#NormalTok(": np.");#BuiltInTok("round");#NormalTok("(profit, ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("                    }");],
[#NormalTok("                    ");#CommentTok("# print(f\"Distribusi {dist_name}\",f\"{profit_comparison}\")");],
[#NormalTok("                results[");#SpecialStringTok("f\"Garansi_");#SpecialCharTok("{");#NormalTok("w");#SpecialCharTok("}");#SpecialStringTok("_Jam\"");#NormalTok("][");#SpecialStringTok("f\"Sigma_");#SpecialCharTok("{");#NormalTok("sig");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" profit_comparison");],
[],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" results");],
[],
[#CommentTok("# --- Eksekusi Simulasi ---");],
[#NormalTok("analyzer ");#OperatorTok("=");#NormalTok(" WarrantyAnalyzer(mu");#OperatorTok("=");#DecValTok("900");#NormalTok(", N");#OperatorTok("=");#DecValTok("10000");#NormalTok(", cost");#OperatorTok("=");#DecValTok("5");#NormalTok(", price");#OperatorTok("=");#DecValTok("10");#NormalTok(", replacement_cost");#OperatorTok("=");#DecValTok("7");#NormalTok(")");],
[#CommentTok("# Menguji garansi 750 jam dan 800 jam dengan asumsi deviasi 50 dan 100");],
[#NormalTok("hasil_analisis ");#OperatorTok("=");#NormalTok(" analyzer.analyze(warranty_hours");#OperatorTok("=");#NormalTok("[");#DecValTok("850");#NormalTok(", ");#DecValTok("800");#NormalTok(", ");#DecValTok("750");#NormalTok("], sigmas");#OperatorTok("=");#NormalTok("[");#DecValTok("50");#NormalTok(",");#DecValTok("100");#NormalTok("])");],
[],
[#CommentTok("# Cetak hasil (Format JSON agar mudah dibaca sebagai Dictionary)");],
[#CommentTok("# print(json.dumps(hasil_analisis, indent=4))");],
[#CommentTok("# print(hasil_analisis)");],));
]
#strong[Analisis Output Bisnis:] Berdasarkan pendekatan probabilitas tersebut, ketika skrip dieksekusi, Anda akan menemukan bahwa pemilihan deviasi ($sigma$) dan waktu garansi sangat krusial: 1. #strong[Meningkatkan Garansi:] Jika Anda menetapkan garansi 800 jam pada model #strong[Normal] dengan $sigma = 100$, jumlah lampu yang rusak secara signifikan lebih besar dibandingkan garansi 750 jam karena nilai 800 jam sudah sangat dekat dengan batas kiri kurva #emph[bell-curve] nilai rata-rata ($mu = 900$). 2. #strong[Pemilihan Model:] Model #strong[Eksponensial] akan memprediksi tingkat kerusakan prematur (#emph[infant mortality]) yang paling ekstrem (paling merugikan), karena laju kerusakannya dimulai sejak hari pertama. Sedangkan #strong[Weibull] akan memberikan prediksi yang paling akurat dengan realita keausan pabrik (#emph[wear-out]). Keputusan mengalokasikan garansi harus melihat estimasi profit pada metrik #emph[Profit\_Akhir] di model Weibull atau Normal.

bila pasar produk diperebutkan oleh produsen di mana pangsa psar di tentuka oleh harga dan garansi secara proporsional: semakin murah harga semakin besar segmen, semakin tinggi garansi semakin besar segmen, usulkan model sederhana untuk memutuskan harga dan garansi

Bisa. Model sederhananya adalah: #strong[pilih harga dan garansi yang memaksimalkan expected profit total], tetapi #strong[jumlah unit terjual] dibuat bergantung pada #strong[daya tarik pasar], yang dipengaruhi oleh #strong[harga] dan #strong[garansi].

#horizontalrule

== 1) Ide dasar
<ide-dasar>
Sebelumnya profit total hanya:

$ upright("Profit Total") = \( upright("profit per unit") \) times \( upright("jumlah unit terjual") \) $

Sekarang:

- #strong[profit per unit] dipengaruhi oleh harga, biaya produksi, dan biaya garansi
- #strong[jumlah unit terjual / pangsa pasar] dipengaruhi oleh harga dan garansi

Jadi keputusan bisnisnya adalah memilih:

$ \( p \, w \) $

dengan:

- $\( p \)$ = harga jual
- $\( w \)$ = panjang garansi (jam)

untuk memaksimalkan:

$ Pi \( p \, w \) = Q \( p \, w \) dot.op pi \( p \, w \) $

di mana:

- $\( Q \( p \, w \) \)$ = jumlah unit terjual
- $\( pi \( p \, w \) \)$ = expected profit per unit

#horizontalrule

== 2) Expected profit per unit
<expected-profit-per-unit>
Misalkan:

- biaya produksi = (c)
- biaya garansi per klaim = (g)
- umur produk acak (T)

Kalau garansi adalah (w), maka peluang klaim:

$ P \( T < w \) = F \( w \) $

sehingga expected profit per unit:

$ pi \( p \, w \) = p - c - g \, F \( w \) $

=== Untuk kasus eksponensial
<untuk-kasus-eksponensial>
Jika ($T tilde.op upright("Exp") \( lambda \)$), maka:

$ F \( w \) = 1 - e^(- lambda w) $

jadi:

$ pi \( p \, w \) = p - c - g \( 1 - e^(- lambda w) \) $

Untuk data Anda:

- \($c = 5$)\$
- \($g = 10$)
- \($lambda = 0.00005$\$)

maka:

$ pi \( p \, w \) = p - 5 - 10 \( 1 - e^(- 0.00005 w) \) $

atau bisa ditulis:

$ pi \( p \, w \) = p - 15 + 10 e^(- 0.00005 w) $

Maknanya:

- harga naik () profit per unit naik
- garansi makin panjang () profit per unit turun, karena klaim naik

#horizontalrule

== 3) Model sederhana pangsa pasar
<model-sederhana-pangsa-pasar>
Sekarang kita butuh model bahwa:

- makin #strong[murah] () pangsa pasar makin besar
- makin #strong[lama garansi] () pangsa pasar makin besar

=== Versi paling sederhana: skor daya tarik linear
<versi-paling-sederhana-skor-daya-tarik-linear>
Misalkan pasar total berukuran (M), dan daya tarik produk kita:

$ A \( p \, w \) = alpha (1 / p) + beta w $

dengan:

- \($alpha > 0$): sensitivitas terhadap harga
- \($beta > 0$): sensitivitas terhadap garansi

Lalu pangsa pasar kita:

$ s \( p \, w \) = frac(A \( p \, w \), A \( p \, w \) + A_(upright("kompetitor"))) $

sehingga jumlah unit terjual:

$ Q \( p \, w \) = M dot.op s \( p \, w \) $

Maka objective function:

$ Pi \( p \, w \) = M dot.op frac(A \( p \, w \), A \( p \, w \) + A_(upright("kompetitor"))) dot.op #scale(x: 120%, y: 120%)[\(] p - c - g F \( w \) #scale(x: 120%, y: 120%)[\)] $

Ini sudah cukup untuk keputusan awal.

#horizontalrule

== 4) Model yang lebih rapi: utilitas relatif
<model-yang-lebih-rapi-utilitas-relatif>
Biasanya lebih enak pakai model #strong[daya tarik relatif]:

$ A \( p \, w \) = exp \( a - b p + d w \) $

dengan:

- \($b > 0$): harga makin tinggi, daya tarik turun
- \($d > 0$): garansi makin tinggi, daya tarik naik

Kalau ada (n) kompetitor, dan produk kita bersaing dengan mereka, pangsa pasar:

$ s \( p \, w \) = frac(exp \( a - b p + d w \), sum_(j = 1)^n exp \( a_j - b_j p_j + d_j w_j \)) $

Jika karakteristik kompetitor dianggap tetap, penyebut bisa dipandang sebagai konstanta plus daya tarik kita.

Lalu:

$ Q \( p \, w \) = M dot.op s \( p \, w \) $

dan total expected profit:

$ Pi \( p \, w \) = M dot.op s \( p \, w \) dot.op \( p - c - g F \( w \) \) $

Ini model yang lebih stabil daripada linear, karena:

- pangsa pasar otomatis antara 0 dan 1
- tidak jadi negatif
- cocok untuk kompetisi

#table(
  columns: (100%),
  align: (left,),
  [\#\# 5) Bentuk model keputusan final],
  [Untuk kasus Wi-Fi eksponensial, model sederhana yang saya sarankan:],
  [\$\$ boxed{ \(p,w) =],
  [M {\(a-bp+dw)+K} } \$\$],
  [dengan:],
  [\#\# 6) Intuisi manajerial],
  [Ada trade-off:],
  [- #strong[Harga tinggi]],
  [- profit per unit naik - pangsa pasar turun],
  [- #strong[Harga rendah]],
  [- pangsa pasar naik - margin turun],
  [- #strong[Garansi panjang]],
  [- pangsa pasar naik - biaya garansi naik],
  [- #strong[Garansi pendek]],
  [- biaya rendah - daya tarik pasar turun],
  [Jadi keputusan optimal biasanya berada di #strong[titik tengah], bukan harga termurah atau garansi terpanjang.],
)
== 7) Versi sangat sederhana untuk tugas / ujian
<versi-sangat-sederhana-untuk-tugas-ujian>
Kalau ingin model yang sangat mudah dijelaskan, bisa pakai:

$ Q \( p \, w \) = M (alpha - beta p + gamma w) $

dengan ($beta \, gamma med 0$), lalu dibatasi agar ($Q \( p \, w \) gt.eq 0$).

Maka:

$ Pi \( p \, w \) = M \( alpha - beta p + gamma w \) dot.op \( p - c - g F \( w \) \) $

Untuk eksponensial:

$ Pi \( p \, w \) = M \( alpha - beta p + gamma w \) dot.op [p - c - g \( 1 - e^(- lambda w) \)] $

Ini sangat sederhana dan mudah dihitung, walaupun kurang realistis dibanding model logit/eksponensial.

#horizontalrule

== 8) Rekomendasi model praktis
<rekomendasi-model-praktis>
Untuk praktik, saya sarankan:

- pakai #strong[profit per unit ekspektasian]: $p - c - g F \( w \)$

- pakai #strong[market share logit sederhana]: $s \( p \, w \) = frac(e^(- b p + d w), e^(- b p + d w) + K)$

- maksimalkan: $Pi \( p \, w \) = M \, s \( p \, w \) \, \[ p - c - g F \( w \) \]$

Karena model ini:

- sederhana
- masuk akal
- mudah dikalibrasi dari data pasar
- mudah disimulasikan

#horizontalrule

== 9) Contoh Python kecil
<contoh-python-kecil>
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#CommentTok("# parameter bisnis");],
[#NormalTok("M ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100000");#NormalTok("          ");#CommentTok("# total market size");],
[#NormalTok("c ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");#NormalTok("               ");#CommentTok("# production cost");],
[#NormalTok("g ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");#NormalTok("              ");#CommentTok("# warranty claim cost");],
[#NormalTok("lam ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.00005");#NormalTok("       ");#CommentTok("# failure rate");],
[],
[#CommentTok("# parameter pasar");],
[#NormalTok("b ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.25");#NormalTok("            ");#CommentTok("# price sensitivity");],
[#NormalTok("d ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.00015");#NormalTok("         ");#CommentTok("# warranty sensitivity");],
[#NormalTok("K ");#OperatorTok("=");#NormalTok(" ");#FloatTok("1.5");#NormalTok("             ");#CommentTok("# competitor attractiveness");],
[],
[#KeywordTok("def");#NormalTok(" claim_prob(w):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" np.exp(");#OperatorTok("-");#NormalTok("lam ");#OperatorTok("*");#NormalTok(" w)");],
[],
[#KeywordTok("def");#NormalTok(" profit_per_unit(p, w):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" p ");#OperatorTok("-");#NormalTok(" c ");#OperatorTok("-");#NormalTok(" g ");#OperatorTok("*");#NormalTok(" claim_prob(w)");],
[],
[#KeywordTok("def");#NormalTok(" market_share(p, w):");],
[#NormalTok("    A ");#OperatorTok("=");#NormalTok(" np.exp(");#OperatorTok("-");#NormalTok("b ");#OperatorTok("*");#NormalTok(" p ");#OperatorTok("+");#NormalTok(" d ");#OperatorTok("*");#NormalTok(" w)");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" A ");#OperatorTok("/");#NormalTok(" (A ");#OperatorTok("+");#NormalTok(" K)");],
[],
[#KeywordTok("def");#NormalTok(" total_profit(p, w):");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" M ");#OperatorTok("*");#NormalTok(" market_share(p, w) ");#OperatorTok("*");#NormalTok(" profit_per_unit(p, w)");],
[],
[#CommentTok("# grid search sederhana");],
[#NormalTok("prices ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("8");#NormalTok(", ");#DecValTok("21");#NormalTok(", ");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("warranties ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("2000");#NormalTok(", ");#DecValTok("12001");#NormalTok(", ");#DecValTok("500");#NormalTok(")");],
[],
[#NormalTok("best ");#OperatorTok("=");#NormalTok(" ");#VariableTok("None");],
[#NormalTok("best_profit ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("-");#NormalTok("np.inf");],
[],
[#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" prices:");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" w ");#KeywordTok("in");#NormalTok(" warranties:");],
[#NormalTok("        prof ");#OperatorTok("=");#NormalTok(" total_profit(p, w)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" prof ");#OperatorTok(">");#NormalTok(" best_profit:");],
[#NormalTok("            best_profit ");#OperatorTok("=");#NormalTok(" prof");],
[#NormalTok("            best ");#OperatorTok("=");#NormalTok(" (p, w, prof, market_share(p, w), profit_per_unit(p, w))");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best price =\"");#NormalTok(", best[");#DecValTok("0");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best warranty =\"");#NormalTok(", best[");#DecValTok("1");#NormalTok("], ");#StringTok("\"hours\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best total profit =\"");#NormalTok(", ");#BuiltInTok("round");#NormalTok("(best[");#DecValTok("2");#NormalTok("], ");#DecValTok("2");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Market share =\"");#NormalTok(", ");#BuiltInTok("round");#NormalTok("(best[");#DecValTok("3");#NormalTok("], ");#DecValTok("4");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Profit per unit =\"");#NormalTok(", ");#BuiltInTok("round");#NormalTok("(best[");#DecValTok("4");#NormalTok("], ");#DecValTok("4");#NormalTok("))");],));

#horizontalrule

== 10) Kesimpulan
<kesimpulan>
Model sederhana yang baik adalah:

$ #box(stroke: black, inset: 3pt, [$ upright("Total Profit") = upright("Market Size") times upright("Market Share") \( p \, w \) times upright("Expected Profit per Unit") \( p \, w \) $]) $

dengan:

$ upright("Expected Profit per Unit") \( p \, w \) = p - c - g F \( w \) $

dan market share dibuat #strong[turun terhadap harga] dan #strong[naik terhadap garansi], misalnya:

$ upright("Market Share") \( p \, w \) = frac(e^(- b p + d w), e^(- b p + d w) + K) $

Lalu pilih ($\( p \, w \)$) yang memaksimalkan fungsi itu.

= Summary
<summary>
In summary, this book has no content whatsoever.

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#bibliography(("references.bib"))

