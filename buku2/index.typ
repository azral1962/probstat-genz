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

= Random Variable Kontinu
<random-variable-kontinu>
== Kita Beri Garansi Berapa Lama?
<kita-beri-garansi-berapa-lama>
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


== Live Coding: "Normal is Everywhere"\*\*
<live-coding-normal-is-everywhere>
Suatu variable random bisa memiliki #emph[probability density function] (pdf) berbentuk lonceng, dengan dua parameter $mu$ dan $sigma$.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#CommentTok("# Instantiate a default random number generator");],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng()");],));
]
Untuk distribuasi normal dan standar, lokasi titik tengah = 0 dan deviasi standar = 1.

#block[
#Skylighting(([#CommentTok("# Generate a single random number from the standard normal distribution (mean=0, std=1)");],
[#NormalTok("sample_scalar ");#OperatorTok("=");#NormalTok(" rng.normal()");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"1. Single sample: ");#SpecialCharTok("{");#NormalTok("sample_scalar");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("1. Single sample: 0.24416642202191122");],));
]
]
Dalam kasus kita lokasi titik tengah = 900 dan deviasi standar = 50. maka berapa jam lima lampu ini mati?

#block[
#Skylighting(([#NormalTok("mu ");#OperatorTok("=");#NormalTok(" ");#DecValTok("900");],
[#NormalTok("sigma ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");],
[],
[#CommentTok("# Generate a 1D array of 5 numbers with mean=900, standard deviation=50");],
[#NormalTok("samples_1d ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma, size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"2. 1D array: ");#SpecialCharTok("{");#NormalTok("samples_1d");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("2. 1D array: [ 921.64135141  981.44396981  858.85745202 1035.86023778  972.51206834]");],));
]
]
Berbeda beda yaitu: np.float64(921.6413514058673)

#Skylighting(([#NormalTok("    1. Generate data acak `numpy.random.normal`.");],
[#NormalTok("    2. Tunjukkan aturan empiris: 68% data ada di $\\mu \\pm \\sigma$, 95% di $\\mu \\pm 2\\sigma$.");],
[#NormalTok("    3. Visualisasi: Plot kurva lonceng dengan seaborn dan arsir area probabilitas.");],));
#Skylighting(([#NormalTok("data ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("mu, scale");#OperatorTok("=");#NormalTok("sigma, size");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("np.histogram(data, bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#CommentTok("# 3. Menambahkan label dan judul");],
[#NormalTok("plt.hist(data,bins");#OperatorTok("=");#DecValTok("30");#NormalTok(", density");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("'Histogram Normal Distribution (NumPy)'");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("'Value'");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("'Density'");#NormalTok(")");],
[#NormalTok("plt.grid(axis");#OperatorTok("=");#StringTok("'y'");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[],
[#CommentTok("# 4. Menampilkan plot");],
[#NormalTok("plt.show()");],));
#box(image("chapter07_files/figure-typst/cell-5-output-1.svg"))

#block[
#Skylighting(([#CommentTok("# Generate a 2x3 matrix with default parameters");],
[#NormalTok("samples_2d ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"3. 2D array:");#CharTok("\\n");#SpecialCharTok("{");#NormalTok("samples_2d");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("3. 2D array:");],
[#NormalTok("[[ 0.65561043  0.12842887  0.17154068]");],
[#NormalTok(" [ 1.22288256 -0.37581476  2.31328241]]");],));
]
]
= Summary
<summary>
In summary, this book has no content whatsoever.

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#bibliography(("references.bib"))

