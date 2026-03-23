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
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

Suatu kantor catatan sipil bisa melayani rata-rata 400 orang per hari, dengan jam kerja 8-16. Dalam kenyataannya bisa 100, 300, 500, 700, atau angka lain, karena beda orang beda keperluan. Ini dimodelkan dengan distribusi poisson.

misalnya rata-rata kedatangan masyarakat juga 400 orang perhari. juga berditribusi poisson\`\` antrian muncul bila semua loket penuh ada yang dtang

hitung dalam satu jam pk 08-09 berapa peluang terjadi antian? Bila ruang tunggu brerkpsitas 10 kursi, brerpa peluang luber pada jam tersebut

Simulasi dulu baru teori. \#\# simulasis Aantrian Sederhana

Berikut demo Python yang reusable dengan #strong[class], untuk:

- memodelkan #strong[kedatangan] dan #strong[pelayanan] per jam dengan Poisson

- menghitung:

  - peluang #strong[terjadi antrian] dalam 1 jam
  - peluang #strong[ruang tunggu luber] bila kapasitas kursi tertentu

- membuat #strong[visualisasi]

- menjalankan #strong[simulasi Monte Carlo] untuk verifikasi

Kode ini cocok untuk demo kelas dan mudah diubah parameternya.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" poisson");],
[],
[],
[#KeywordTok("class");#NormalTok(" PoissonQueueHourModel:");],
[#NormalTok("    ");#CommentTok("\"\"\"");],
[#CommentTok("    Model sederhana untuk 1 interval waktu (mis. 1 jam),");],
[#CommentTok("    dengan:");],
[#CommentTok("      - jumlah kedatangan ~ Poisson(arrival_rate)");],
[#CommentTok("      - jumlah pelayanan selesai ~ Poisson(service_rate)");],
[],
[#CommentTok("    Queue muncul bila arrivals > services.");],
[#CommentTok("    Overflow terjadi bila arrivals - services > waiting_capacity.");],
[#CommentTok("    \"\"\"");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", arrival_rate_per_hour, service_rate_per_hour, waiting_capacity");#OperatorTok("=");#DecValTok("10");#NormalTok("):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".lambda_arrival ");#OperatorTok("=");#NormalTok(" arrival_rate_per_hour");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".lambda_service ");#OperatorTok("=");#NormalTok(" service_rate_per_hour");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("=");#NormalTok(" waiting_capacity");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" pmf_arrivals(");#VariableTok("self");#NormalTok(", k):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" poisson.pmf(k, ");#VariableTok("self");#NormalTok(".lambda_arrival)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" pmf_services(");#VariableTok("self");#NormalTok(", k):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" poisson.pmf(k, ");#VariableTok("self");#NormalTok(".lambda_service)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" exact_prob_queue(");#VariableTok("self");#NormalTok(", max_k");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Hitung P(A > S) secara eksak diskret.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" max_k ");#KeywordTok("is");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            max_k ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(");#BuiltInTok("max");#NormalTok("(");#VariableTok("self");#NormalTok(".lambda_arrival, ");#VariableTok("self");#NormalTok(".lambda_service) ");#OperatorTok("+");#NormalTok(" ");#DecValTok("6");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.sqrt(");#BuiltInTok("max");#NormalTok("(");#VariableTok("self");#NormalTok(".lambda_arrival, ");#VariableTok("self");#NormalTok(".lambda_service)))");],
[],
[#NormalTok("        a_vals ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_k ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        s_vals ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_k ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("        p_a ");#OperatorTok("=");#NormalTok(" poisson.pmf(a_vals, ");#VariableTok("self");#NormalTok(".lambda_arrival)");],
[#NormalTok("        p_s ");#OperatorTok("=");#NormalTok(" poisson.pmf(s_vals, ");#VariableTok("self");#NormalTok(".lambda_service)");],
[],
[#NormalTok("        prob ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" i, a ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("enumerate");#NormalTok("(a_vals):");],
[#NormalTok("            ");#CommentTok("# jumlahkan probabilitas semua s < a");],
[#NormalTok("            prob ");#OperatorTok("+=");#NormalTok(" p_a[i] ");#OperatorTok("*");#NormalTok(" p_s[s_vals ");#OperatorTok("<");#NormalTok(" a].");#BuiltInTok("sum");#NormalTok("()");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" prob");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" exact_prob_overflow(");#VariableTok("self");#NormalTok(", max_k");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Hitung P(A - S > waiting_capacity) secara eksak diskret.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" max_k ");#KeywordTok("is");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            max_k ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(");#BuiltInTok("max");#NormalTok("(");#VariableTok("self");#NormalTok(".lambda_arrival, ");#VariableTok("self");#NormalTok(".lambda_service) ");#OperatorTok("+");#NormalTok(" ");#DecValTok("6");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.sqrt(");#BuiltInTok("max");#NormalTok("(");#VariableTok("self");#NormalTok(".lambda_arrival, ");#VariableTok("self");#NormalTok(".lambda_service)))");],
[],
[#NormalTok("        a_vals ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_k ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        s_vals ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_k ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("        p_a ");#OperatorTok("=");#NormalTok(" poisson.pmf(a_vals, ");#VariableTok("self");#NormalTok(".lambda_arrival)");],
[#NormalTok("        p_s ");#OperatorTok("=");#NormalTok(" poisson.pmf(s_vals, ");#VariableTok("self");#NormalTok(".lambda_service)");],
[],
[#NormalTok("        cap ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".waiting_capacity");],
[#NormalTok("        prob ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" i, a ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("enumerate");#NormalTok("(a_vals):");],
[#NormalTok("            prob ");#OperatorTok("+=");#NormalTok(" p_a[i] ");#OperatorTok("*");#NormalTok(" p_s[s_vals ");#OperatorTok("<");#NormalTok(" (a ");#OperatorTok("-");#NormalTok(" cap)].");#BuiltInTok("sum");#NormalTok("()");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" prob");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" simulate(");#VariableTok("self");#NormalTok(", n_sim");#OperatorTok("=");#DecValTok("100_000");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("123");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Simulasi Monte Carlo.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(random_seed)");],
[#NormalTok("        arrivals ");#OperatorTok("=");#NormalTok(" rng.poisson(");#VariableTok("self");#NormalTok(".lambda_arrival, size");#OperatorTok("=");#NormalTok("n_sim)");],
[#NormalTok("        services ");#OperatorTok("=");#NormalTok(" rng.poisson(");#VariableTok("self");#NormalTok(".lambda_service, size");#OperatorTok("=");#NormalTok("n_sim)");],
[#NormalTok("        backlog ");#OperatorTok("=");#NormalTok(" arrivals ");#OperatorTok("-");#NormalTok(" services");],
[],
[#NormalTok("        result ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("            ");#StringTok("\"arrivals\"");#NormalTok(": arrivals,");],
[#NormalTok("            ");#StringTok("\"services\"");#NormalTok(": services,");],
[#NormalTok("            ");#StringTok("\"backlog\"");#NormalTok(": backlog,");],
[#NormalTok("            ");#StringTok("\"prob_queue_sim\"");#NormalTok(": np.mean(backlog ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok("),");],
[#NormalTok("            ");#StringTok("\"prob_overflow_sim\"");#NormalTok(": np.mean(backlog ");#OperatorTok(">");#NormalTok(" ");#VariableTok("self");#NormalTok(".waiting_capacity),");],
[#NormalTok("        }");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" result");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" summary(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        pq ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".exact_prob_queue()");],
[#NormalTok("        po ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".exact_prob_overflow()");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" {");],
[#NormalTok("            ");#StringTok("\"arrival_rate_per_hour\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".lambda_arrival,");],
[#NormalTok("            ");#StringTok("\"service_rate_per_hour\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".lambda_service,");],
[#NormalTok("            ");#StringTok("\"waiting_capacity\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".waiting_capacity,");],
[#NormalTok("            ");#StringTok("\"prob_queue_exact\"");#NormalTok(": pq,");],
[#NormalTok("            ");#StringTok("\"prob_overflow_exact\"");#NormalTok(": po,");],
[#NormalTok("        }");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_poisson_distributions(");#VariableTok("self");#NormalTok(", max_k");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Plot distribusi jumlah kedatangan dan pelayanan.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" max_k ");#KeywordTok("is");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            max_k ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(");#BuiltInTok("max");#NormalTok("(");#VariableTok("self");#NormalTok(".lambda_arrival, ");#VariableTok("self");#NormalTok(".lambda_service) ");#OperatorTok("+");#NormalTok(" ");#DecValTok("4");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.sqrt(");#BuiltInTok("max");#NormalTok("(");#VariableTok("self");#NormalTok(".lambda_arrival, ");#VariableTok("self");#NormalTok(".lambda_service)))");],
[],
[#NormalTok("        k ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_k ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        p_a ");#OperatorTok("=");#NormalTok(" poisson.pmf(k, ");#VariableTok("self");#NormalTok(".lambda_arrival)");],
[#NormalTok("        p_s ");#OperatorTok("=");#NormalTok(" poisson.pmf(k, ");#VariableTok("self");#NormalTok(".lambda_service)");],
[],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("        plt.plot(k, p_a, marker");#OperatorTok("=");#StringTok("'o'");#NormalTok(", label");#OperatorTok("=");#SpecialStringTok("f'Arrivals ~ Poisson(");#SpecialCharTok("{");#VariableTok("self");#SpecialCharTok(".");#NormalTok("lambda_arrival");#SpecialCharTok(":.1f}");#SpecialStringTok(")'");#NormalTok(")");],
[#NormalTok("        plt.plot(k, p_s, marker");#OperatorTok("=");#StringTok("'s'");#NormalTok(", label");#OperatorTok("=");#SpecialStringTok("f'Services ~ Poisson(");#SpecialCharTok("{");#VariableTok("self");#SpecialCharTok(".");#NormalTok("lambda_service");#SpecialCharTok(":.1f}");#SpecialStringTok(")'");#NormalTok(")");],
[#NormalTok("        plt.title(");#StringTok("'Distribusi Kedatangan dan Pelayanan per Jam'");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("'Jumlah orang'");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("'Probabilitas'");#NormalTok(")");],
[#NormalTok("        plt.grid(");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.legend()");],
[#NormalTok("        plt.show()");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_backlog_histogram(");#VariableTok("self");#NormalTok(", n_sim");#OperatorTok("=");#DecValTok("100_000");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("123");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Plot histogram backlog = arrivals - services.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        sim ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".simulate(n_sim");#OperatorTok("=");#NormalTok("n_sim, random_seed");#OperatorTok("=");#NormalTok("random_seed)");],
[#NormalTok("        backlog ");#OperatorTok("=");#NormalTok(" sim[");#StringTok("\"backlog\"");#NormalTok("]");],
[],
[#NormalTok("        min_x ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("min");#NormalTok("(backlog.");#BuiltInTok("min");#NormalTok("(), ");#OperatorTok("-");#DecValTok("20");#NormalTok(")");],
[#NormalTok("        max_x ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(backlog.");#BuiltInTok("max");#NormalTok("(), ");#DecValTok("20");#NormalTok(")");],
[#NormalTok("        bins ");#OperatorTok("=");#NormalTok(" np.arange(min_x ");#OperatorTok("-");#NormalTok(" ");#FloatTok("0.5");#NormalTok(", max_x ");#OperatorTok("+");#NormalTok(" ");#FloatTok("1.5");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("        plt.hist(backlog, bins");#OperatorTok("=");#NormalTok("bins, density");#OperatorTok("=");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.75");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("'black'");#NormalTok(")");],
[#NormalTok("        plt.axvline(");#FloatTok("0.5");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(", label");#OperatorTok("=");#StringTok("'Batas mulai antrian (>0)'");#NormalTok(")");],
[#NormalTok("        plt.axvline(");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.5");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("'--'");#NormalTok(",");],
[#NormalTok("                    label");#OperatorTok("=");#SpecialStringTok("f'Batas luber (>");#SpecialCharTok("{");#VariableTok("self");#SpecialCharTok(".");#NormalTok("waiting_capacity");#SpecialCharTok("}");#SpecialStringTok(")'");#NormalTok(")");],
[#NormalTok("        plt.title(");#StringTok("'Histogram Selisih (Arrivals - Services)'");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("'Backlog'");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("'Frekuensi relatif'");#NormalTok(")");],
[#NormalTok("        plt.grid(");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.legend()");],
[#NormalTok("        plt.show()");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_queue_risk_curve(");#VariableTok("self");#NormalTok(", max_capacity");#OperatorTok("=");#DecValTok("30");#NormalTok(", max_k");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Plot peluang overflow untuk berbagai kapasitas ruang tunggu.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        capacities ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_capacity ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        probs ");#OperatorTok("=");#NormalTok(" []");],
[],
[#NormalTok("        old_cap ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".waiting_capacity");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" cap ");#KeywordTok("in");#NormalTok(" capacities:");],
[#NormalTok("            ");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("=");#NormalTok(" cap");],
[#NormalTok("            probs.append(");#VariableTok("self");#NormalTok(".exact_prob_overflow(max_k");#OperatorTok("=");#NormalTok("max_k))");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("=");#NormalTok(" old_cap");],
[],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("        plt.plot(capacities, probs, marker");#OperatorTok("=");#StringTok("'o'");#NormalTok(")");],
[#NormalTok("        plt.title(");#StringTok("'Peluang Luber vs Kapasitas Ruang Tunggu'");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("'Kapasitas kursi tunggu'");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("'P(luber)'");#NormalTok(")");],
[#NormalTok("        plt.grid(");#VariableTok("True");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.show()");],
[],
[],
[#CommentTok("# =========================");],
[#CommentTok("# DEMO PAKAI DATA SOAL");],
[#CommentTok("# =========================");],
[],
[#ControlFlowTok("if");#NormalTok(" ");#VariableTok("__name__");#NormalTok(" ");#OperatorTok("==");#NormalTok(" ");#StringTok("\"__main__\"");#NormalTok(":");],
[#NormalTok("    ");#CommentTok("# Data:");],
[#NormalTok("    ");#CommentTok("# rata-rata 400 orang/hari");],
[#NormalTok("    ");#CommentTok("# jam kerja 8 jam => 50 orang/jam");],
[#NormalTok("    model ");#OperatorTok("=");#NormalTok(" PoissonQueueHourModel(");],
[#NormalTok("        arrival_rate_per_hour");#OperatorTok("=");#DecValTok("400");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#DecValTok("8");#NormalTok(",");],
[#NormalTok("        service_rate_per_hour");#OperatorTok("=");#DecValTok("400");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#DecValTok("8");#NormalTok(",");],
[#NormalTok("        waiting_capacity");#OperatorTok("=");#DecValTok("10");],
[#NormalTok("    )");],
[],
[#NormalTok("    ");#CommentTok("# Ringkasan eksak");],
[#NormalTok("    summary ");#OperatorTok("=");#NormalTok(" model.summary()");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"=== RINGKASAN MODEL ===\"");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" k, v ");#KeywordTok("in");#NormalTok(" summary.items():");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"");#SpecialCharTok("{");#NormalTok("k");#SpecialCharTok("}");#SpecialStringTok(": ");#SpecialCharTok("{");#NormalTok("v");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("    ");#CommentTok("# Simulasi untuk verifikasi");],
[#NormalTok("    sim ");#OperatorTok("=");#NormalTok(" model.simulate(n_sim");#OperatorTok("=");#DecValTok("200_000");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("42");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("=== HASIL SIMULASI ===\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Prob. queue (simulasi)    : ");#SpecialCharTok("{");#NormalTok("sim[");#StringTok("'prob_queue_sim'");#NormalTok("]");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Prob. overflow (simulasi) : ");#SpecialCharTok("{");#NormalTok("sim[");#StringTok("'prob_overflow_sim'");#NormalTok("]");#SpecialCharTok(":.4f}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("    ");#CommentTok("# Visualisasi");],
[#NormalTok("    model.plot_poisson_distributions()");],
[#NormalTok("    model.plot_backlog_histogram()");],
[#NormalTok("    model.plot_queue_risk_curve(max_capacity");#OperatorTok("=");#DecValTok("25");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("=== RINGKASAN MODEL ===");],
[#NormalTok("arrival_rate_per_hour: 50.0");],
[#NormalTok("service_rate_per_hour: 50.0");],
[#NormalTok("waiting_capacity: 10");],
[#NormalTok("prob_queue_exact: 0.48002777483392056");],
[#NormalTok("prob_overflow_exact: 0.14656723321985607");],
[],
[#NormalTok("=== HASIL SIMULASI ===");],
[#NormalTok("Prob. queue (simulasi)    : 0.4792");],
[#NormalTok("Prob. overflow (simulasi) : 0.1461");],));
]
#box(image("06_antrian_files/figure-typst/cell-2-output-2.svg"))

#block[
#box(image("06_antrian_files/figure-typst/cell-2-output-3.svg"))

]
#block[
#box(image("06_antrian_files/figure-typst/cell-2-output-4.svg"))

]
=== Apa yang dilakukan kode ini
<apa-yang-dilakukan-kode-ini>
Class #NormalTok("PoissonQueueHourModel"); bisa dipakai ulang untuk kasus lain. Misalnya:

#Skylighting(([#NormalTok("model2 ");#OperatorTok("=");#NormalTok(" PoissonQueueHourModel(");],
[#NormalTok("    arrival_rate_per_hour");#OperatorTok("=");#DecValTok("60");#NormalTok(",");],
[#NormalTok("    service_rate_per_hour");#OperatorTok("=");#DecValTok("55");#NormalTok(",");],
[#NormalTok("    waiting_capacity");#OperatorTok("=");#DecValTok("15");],
[#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(model2.summary())");],));
=== Interpretasi model
<interpretasi-model>
Dalam 1 jam:

- #NormalTok("arrivals ~ Poisson(50)");
- #NormalTok("services ~ Poisson(50)");

Lalu:

- #strong[antrian terjadi] bila #NormalTok("arrivals > services");
- #strong[luber] bila #NormalTok("arrivals - services > 10");

=== Kelebihan desain class ini
<kelebihan-desain-class-ini>
- parameter mudah diubah
- ada metode #strong[eksak]
- ada #strong[simulasi]
- ada #strong[plot]
- cocok dikembangkan ke model yang lebih realistis

=== Catatan penting
<catatan-penting>
Ini masih model #strong[sederhana per jam], belum model antrian kontinu menit demi menit. Untuk model yang lebih realistis, tahap berikutnya adalah membuat class #strong[M/M/c] dengan:

- arrival Poisson
- service time exponential
- jumlah loket #NormalTok("c");

== penjelasan
<penjelasan>
Dengan data yang diberikan, cara paling sederhana adalah memodelkan #strong[selisih antara jumlah datang dan jumlah yang bisa dilayani selama 1 jam].

== 1) Ubah ke laju per jam
<ubah-ke-laju-per-jam>
Jam kerja 8--16 = #strong[8 jam].

- Rata-rata #strong[kedatangan] per hari = 400 orang ⇒ rata-rata per jam = (400/8 = 50)

- Rata-rata #strong[pelayanan] per hari = 400 orang ⇒ rata-rata per jam = (400/8 = 50)

Jadi untuk jam #strong[08.00--09.00] kita ambil:

$ A tilde.op upright("Poisson") \( 50 \) \, #h(2em) S tilde.op upright("Poisson") \( 50 \) $

dengan:

- #block[
  #set enum(numbering: "(A)", start: 1)
  + = jumlah orang datang dalam 1 jam
  ]
- #block[
  #set enum(numbering: "(A)", start: 19)
  + = jumlah orang yang selesai dilayani dalam 1 jam
  ]

#horizontalrule

== 2) Kapan terjadi antrian?
<kapan-terjadi-antrian>
Dalam pendekatan sederhana ini, #strong[antrian muncul] bila dalam jam itu jumlah datang #strong[lebih banyak] daripada jumlah yang dapat dilayani:

$ A > S $

Karena rata-ratanya sama, distribusi selisih (D=A-S) simetris di sekitar 0.

Maka:

$ P \( A > S \) = frac(1 - P \( A = S \), 2) $

Untuk (\_A=\_S=50), hasilnya:

$ P \( A = S \) approx 0.03994 $

sehingga:

$ P \( A > S \) approx frac(1 - 0.03994, 2) approx 0.4800 $

=== Jadi peluang terjadi antrian pada jam 08--09 kira-kira:
<jadi-peluang-terjadi-antrian-pada-jam-0809-kira-kira>
\$\$
\\boxed{0.48 \\text{ atau } 48%}
\$\$

#horizontalrule

== 3) Kapan ruang tunggu 10 kursi luber?
<kapan-ruang-tunggu-10-kursi-luber>
Ruang tunggu luber bila yang tidak tertangani melebihi 10 orang, yaitu:

$ A - S > 10 $

Hasilnya:

$ P \( A - S > 10 \) approx 0.1466 $

=== Jadi peluang luber pada jam 08--09 kira-kira:
<jadi-peluang-luber-pada-jam-0809-kira-kira>
\$\$
\\boxed{0.1466 \\text{ atau } 14.7%}
\$\$

#horizontalrule

== 4) Intuisi
<intuisi>
Walaupun #strong[rata-rata datang = rata-rata pelayanan = 50 per jam], karena keduanya acak:

- kadang datang 43, dilayani 55 → tidak ada antrian
- kadang datang 58, dilayani 47 → ada antrian 11 orang
- kadang datang 50, dilayani 50 → seimbang

Jadi #strong[rata-rata sama tidak berarti antrian hilang].

#horizontalrule

== 5) Catatan penting
<catatan-penting-1>
Hasil di atas memakai #strong[penyederhanaan per jam]:

- sistem dianggap mulai kosong pada pukul 08.00
- antrian dilihat dari #strong[selisih total datang dan total pelayanan dalam 1 jam]
- belum memodelkan detail banyak loket, lama pelayanan per orang, dan dinamika menit demi menit

Kalau ingin model antrian yang lebih realistis, biasanya dipakai #strong[M/M/c]:

- arrival Poisson
- service time eksponensial
- #block[
  #set enum(numbering: "(a)", start: 3)
  + loket
  ]

Di sana kita bisa hitung:

- peluang semua loket sibuk
- rata-rata panjang antrian
- peluang ruang tunggu penuh

Untuk itu saya perlu tahu #strong[berapa jumlah loket] dan #strong[rata-rata waktu pelayanan per orang].

= MMC
<mmc>
Berikut versi #strong[M/M/c] yang #strong[reusable dengan class], dengan asumsi:

- kedatangan mengikuti #strong[Poisson] dengan laju #NormalTok("λ");
- waktu pelayanan tiap loket mengikuti #strong[Eksponensial] dengan laju #NormalTok("μ");
- jumlah loket aktif #strong[tidak tetap], tetapi acak: $ C tilde.op upright("Binomial") \( n \, p \) $ artinya dari #NormalTok("n"); loket maksimum, tiap loket aktif dengan peluang #NormalTok("p");.

Ini cocok untuk situasi seperti:

- ada #NormalTok("n"); loket terpasang,
- tapi tidak semua petugas selalu hadir / aktif,
- sehingga jumlah loket yang benar-benar melayani berubah-ubah.

Kode di bawah memberi:

- metrik analitik berbasis #strong[conditioning pada c]

- simulasi #strong[discrete-event] per jam

- visualisasi:

  - distribusi jumlah loket aktif
  - peluang antrian terhadap jumlah loket aktif
  - histogram panjang antrian akhir
  - kurva risiko overflow vs kapasitas kursi

#horizontalrule

== Python code
<python-code>
#Skylighting(([#ImportTok("import");#NormalTok(" math");],
[#ImportTok("import");#NormalTok(" heapq");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" binom");],
[],
[],
[#KeywordTok("class");#NormalTok(" MMcBinomialServers:");],
[#NormalTok("    ");#CommentTok("\"\"\"");],
[#CommentTok("    M/M/c dengan jumlah loket aktif C ~ Binomial(n_servers_max, p_active).");],
[],
[#CommentTok("    Asumsi:");],
[#CommentTok("    - Arrival process: Poisson dengan rate lambda_per_hour");],
[#CommentTok("    - Service time per server: Exponential dengan rate mu_per_server_per_hour");],
[#CommentTok("    - Jumlah server aktif untuk setiap interval/simulasi diambil dari Binomial(n, p)");],
[],
[#CommentTok("    Fitur:");],
[#CommentTok("    - Analitik steady-state dengan conditioning pada c");],
[#CommentTok("    - Simulasi discrete-event selama satu horizon waktu (mis. 1 jam)");],
[#CommentTok("    - Visualisasi reusable");],
[#CommentTok("    \"\"\"");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(",");],
[#NormalTok("        lambda_per_hour,");],
[#NormalTok("        mu_per_server_per_hour,");],
[#NormalTok("        n_servers_max,");],
[#NormalTok("        p_active,");],
[#NormalTok("        waiting_capacity");#OperatorTok("=");#DecValTok("10");#NormalTok(",");],
[#NormalTok("    ):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(lambda_per_hour)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".mu ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(mu_per_server_per_hour)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".n ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(n_servers_max)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".p ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(p_active)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(waiting_capacity)");],
[],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#CommentTok("# Bagian 1: Distribusi jumlah loket aktif");],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" server_pmf(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        c_vals ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", ");#VariableTok("self");#NormalTok(".n ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        probs ");#OperatorTok("=");#NormalTok(" binom.pmf(c_vals, ");#VariableTok("self");#NormalTok(".n, ");#VariableTok("self");#NormalTok(".p)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" c_vals, probs");],
[],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#CommentTok("# Bagian 2: Rumus M/M/c klasik");],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _p0_mmc(");#VariableTok("self");#NormalTok(", c):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Probabilitas sistem kosong untuk M/M/c steady-state.");],
[#CommentTok("        Berlaku bila rho = lam / (c*mu) < 1.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("None");],
[#NormalTok("        a ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu");],
[#NormalTok("        rho ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("/");#NormalTok(" (c ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" rho ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("None");],
[],
[#NormalTok("        s ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("sum");#NormalTok("((a ");#OperatorTok("**");#NormalTok(" k) ");#OperatorTok("/");#NormalTok(" math.factorial(k) ");#ControlFlowTok("for");#NormalTok(" k ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(c))");],
[#NormalTok("        s ");#OperatorTok("+=");#NormalTok(" ((a ");#OperatorTok("**");#NormalTok(" c) ");#OperatorTok("/");#NormalTok(" math.factorial(c)) ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" rho))");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" s");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" erlang_c_prob_wait_given_c(");#VariableTok("self");#NormalTok(", c):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        P(wait | c) untuk M/M/c steady-state.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#FloatTok("1.0");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#FloatTok("0.0");],
[],
[#NormalTok("        rho ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("/");#NormalTok(" (c ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" rho ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#FloatTok("1.0");],
[],
[#NormalTok("        p0 ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok("._p0_mmc(c)");],
[#NormalTok("        a ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu");],
[#NormalTok("        pw ");#OperatorTok("=");#NormalTok(" ((a ");#OperatorTok("**");#NormalTok(" c) ");#OperatorTok("/");#NormalTok(" math.factorial(c)) ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" rho)) ");#OperatorTok("*");#NormalTok(" p0");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" pw");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" lq_given_c(");#VariableTok("self");#NormalTok(", c):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Expected queue length Lq | c.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" math.inf ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#FloatTok("0.0");],
[],
[#NormalTok("        rho ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("/");#NormalTok(" (c ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" rho ");#OperatorTok(">=");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" math.inf");],
[],
[#NormalTok("        pw ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".erlang_c_prob_wait_given_c(c)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" pw ");#OperatorTok("*");#NormalTok(" rho ");#OperatorTok("/");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" rho)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" wq_given_c(");#VariableTok("self");#NormalTok(", c):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Expected waiting time Wq | c.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        lq ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lq_given_c(c)");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" math.isinf(lq):");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" math.inf");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" lq ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#FloatTok("0.0");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" summary_by_c(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Ringkasan metrik untuk setiap kemungkinan c.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        rows ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("        c_vals, probs ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".server_pmf()");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" c, pc ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(c_vals, probs):");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                util ");#OperatorTok("=");#NormalTok(" math.inf ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("            ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("                util ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("/");#NormalTok(" (c ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu)");],
[],
[#NormalTok("            rows.append({");],
[#NormalTok("                ");#StringTok("\"c\"");#NormalTok(": ");#BuiltInTok("int");#NormalTok("(c),");],
[#NormalTok("                ");#StringTok("\"P(C=c)\"");#NormalTok(": ");#BuiltInTok("float");#NormalTok("(pc),");],
[#NormalTok("                ");#StringTok("\"utilization_rho\"");#NormalTok(": util,");],
[#NormalTok("                ");#StringTok("\"P_wait_given_c\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".erlang_c_prob_wait_given_c(");#BuiltInTok("int");#NormalTok("(c)),");],
[#NormalTok("                ");#StringTok("\"Lq_given_c\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".lq_given_c(");#BuiltInTok("int");#NormalTok("(c)),");],
[#NormalTok("                ");#StringTok("\"Wq_hours_given_c\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".wq_given_c(");#BuiltInTok("int");#NormalTok("(c)),");],
[#NormalTok("            })");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" rows");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" unconditional_prob_wait(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        P(wait) = E[ P(wait | C) ]");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        c_vals, probs ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".server_pmf()");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(");#BuiltInTok("sum");#NormalTok("(");],
[#NormalTok("            pc ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".erlang_c_prob_wait_given_c(");#BuiltInTok("int");#NormalTok("(c))");],
[#NormalTok("            ");#ControlFlowTok("for");#NormalTok(" c, pc ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(c_vals, probs)");],
[#NormalTok("        ))");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" unconditional_expected_lq(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        E[Lq], bisa tak hingga jika ada peluang state tidak stabil.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        c_vals, probs ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".server_pmf()");],
[#NormalTok("        vals ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" c, pc ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(c_vals, probs):");],
[#NormalTok("            lq ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".lq_given_c(");#BuiltInTok("int");#NormalTok("(c))");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" math.isinf(lq) ");#KeywordTok("and");#NormalTok(" pc ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                ");#ControlFlowTok("return");#NormalTok(" math.inf");],
[#NormalTok("            vals.append(pc ");#OperatorTok("*");#NormalTok(" lq)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(");#BuiltInTok("sum");#NormalTok("(vals))");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" unconditional_expected_wq(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        E[Wq], bisa tak hingga jika ada peluang state tidak stabil.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        c_vals, probs ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".server_pmf()");],
[#NormalTok("        vals ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" c, pc ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(c_vals, probs):");],
[#NormalTok("            wq ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".wq_given_c(");#BuiltInTok("int");#NormalTok("(c))");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" math.isinf(wq) ");#KeywordTok("and");#NormalTok(" pc ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                ");#ControlFlowTok("return");#NormalTok(" math.inf");],
[#NormalTok("            vals.append(pc ");#OperatorTok("*");#NormalTok(" wq)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(");#BuiltInTok("sum");#NormalTok("(vals))");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" analytical_summary(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" {");],
[#NormalTok("            ");#StringTok("\"lambda_per_hour\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".lam,");],
[#NormalTok("            ");#StringTok("\"mu_per_server_per_hour\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".mu,");],
[#NormalTok("            ");#StringTok("\"n_servers_max\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".n,");],
[#NormalTok("            ");#StringTok("\"p_active\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".p,");],
[#NormalTok("            ");#StringTok("\"expected_active_servers\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".n ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".p,");],
[#NormalTok("            ");#StringTok("\"P_wait_unconditional\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".unconditional_prob_wait(),");],
[#NormalTok("            ");#StringTok("\"E_Lq_unconditional\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".unconditional_expected_lq(),");],
[#NormalTok("            ");#StringTok("\"E_Wq_hours_unconditional\"");#NormalTok(": ");#VariableTok("self");#NormalTok(".unconditional_expected_wq(),");],
[#NormalTok("        }");],
[],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#CommentTok("# Bagian 3: Simulasi discrete-event");],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _simulate_one_run(");#VariableTok("self");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", rng");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#CommentTok("\"\"\"");],
[#CommentTok("        Simulasi satu horizon waktu.");],
[#CommentTok("        Mengembalikan statistik run.");],
[#CommentTok("        \"\"\"");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" rng ");#KeywordTok("is");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng()");],
[],
[#NormalTok("        c ");#OperatorTok("=");#NormalTok(" rng.binomial(");#VariableTok("self");#NormalTok(".n, ");#VariableTok("self");#NormalTok(".p)");],
[],
[#NormalTok("        ");#CommentTok("# Generate arrival times selama horizon");],
[#NormalTok("        arrival_times ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("        t ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("        ");#ControlFlowTok("while");#NormalTok(" ");#VariableTok("True");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                ");#ControlFlowTok("break");],
[#NormalTok("            t ");#OperatorTok("+=");#NormalTok(" rng.exponential(");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".lam)");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" t ");#OperatorTok(">");#NormalTok(" horizon_hours:");],
[#NormalTok("                ");#ControlFlowTok("break");],
[#NormalTok("            arrival_times.append(t)");],
[],
[#NormalTok("        ");#CommentTok("# Min-heap waktu selesai pelayanan");],
[#NormalTok("        service_heap ");#OperatorTok("=");#NormalTok(" []");],
[],
[#NormalTok("        num_arrivals ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("        num_waited ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("        max_queue_len ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("        overflow_happened ");#OperatorTok("=");#NormalTok(" ");#VariableTok("False");],
[#NormalTok("        queue_len_trace ");#OperatorTok("=");#NormalTok(" []");],
[],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" t_arr ");#KeywordTok("in");#NormalTok(" arrival_times:");],
[#NormalTok("            num_arrivals ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[],
[#NormalTok("            ");#CommentTok("# Bersihkan semua layanan yang sudah selesai sebelum arrival ini");],
[#NormalTok("            ");#ControlFlowTok("while");#NormalTok(" service_heap ");#KeywordTok("and");#NormalTok(" service_heap[");#DecValTok("0");#NormalTok("] ");#OperatorTok("<=");#NormalTok(" t_arr:");],
[#NormalTok("                heapq.heappop(service_heap)");],
[],
[#NormalTok("            in_service ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(service_heap)");],
[#NormalTok("            queue_len ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(");#DecValTok("0");#NormalTok(", in_service ");#OperatorTok("-");#NormalTok(" c) ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("            ");#CommentTok("# Untuk implementasi yang benar, jumlah dalam heap = sedang dilayani + yang sudah dijadwalkan dari antrian.");],
[#NormalTok("            ");#CommentTok("# Maka queue sebenarnya adalah total dalam sistem selain yang sedang dilayani.");],
[#NormalTok("            queue_len ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#BuiltInTok("len");#NormalTok("(service_heap) ");#OperatorTok("-");#NormalTok(" c)");],
[],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                ");#CommentTok("# semua harus menunggu");],
[#NormalTok("                num_waited ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("                queue_len ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("                ");#CommentTok("# pelanggan akan mulai dilayani setelah server tersedia? Dalam horizon ini server nol terus.");],
[#NormalTok("                ");#CommentTok("# Untuk simulasi satu jam, kita anggap dia tetap di antrean.");],
[#NormalTok("                service_completion ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("float");#NormalTok("(");#StringTok("\"inf\"");#NormalTok(")");],
[#NormalTok("                heapq.heappush(service_heap, service_completion)");],
[#NormalTok("            ");#ControlFlowTok("elif");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(service_heap) ");#OperatorTok("<");#NormalTok(" c:");],
[#NormalTok("                ");#CommentTok("# langsung dilayani");],
[#NormalTok("                service_time ");#OperatorTok("=");#NormalTok(" rng.exponential(");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu)");],
[#NormalTok("                finish_time ");#OperatorTok("=");#NormalTok(" t_arr ");#OperatorTok("+");#NormalTok(" service_time");],
[#NormalTok("                heapq.heappush(service_heap, finish_time)");],
[#NormalTok("            ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("                ");#CommentTok("# harus menunggu sampai server tercepat selesai");],
[#NormalTok("                num_waited ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("                earliest_finish ");#OperatorTok("=");#NormalTok(" heapq.heappop(service_heap)");],
[#NormalTok("                start_service ");#OperatorTok("=");#NormalTok(" earliest_finish");],
[#NormalTok("                service_time ");#OperatorTok("=");#NormalTok(" rng.exponential(");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".mu)");],
[#NormalTok("                new_finish ");#OperatorTok("=");#NormalTok(" start_service ");#OperatorTok("+");#NormalTok(" service_time");],
[#NormalTok("                heapq.heappush(service_heap, new_finish)");],
[],
[#NormalTok("                ");#CommentTok("# Queue length saat sesaat setelah kedatangan");],
[#NormalTok("                queue_len ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#BuiltInTok("len");#NormalTok("(service_heap) ");#OperatorTok("-");#NormalTok(" c)");],
[],
[#NormalTok("            max_queue_len ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(max_queue_len, queue_len)");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" queue_len ");#OperatorTok(">");#NormalTok(" ");#VariableTok("self");#NormalTok(".waiting_capacity:");],
[#NormalTok("                overflow_happened ");#OperatorTok("=");#NormalTok(" ");#VariableTok("True");],
[],
[#NormalTok("            queue_len_trace.append(queue_len)");],
[],
[#NormalTok("        end_queue_len ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" c ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#KeywordTok("and");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(service_heap) ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#BuiltInTok("len");#NormalTok("(service_heap) ");#OperatorTok("-");#NormalTok(" c)");],
[],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" {");],
[#NormalTok("            ");#StringTok("\"active_servers\"");#NormalTok(": c,");],
[#NormalTok("            ");#StringTok("\"num_arrivals\"");#NormalTok(": num_arrivals,");],
[#NormalTok("            ");#StringTok("\"num_waited\"");#NormalTok(": num_waited,");],
[#NormalTok("            ");#StringTok("\"prob_wait_empirical_run\"");#NormalTok(": (num_waited ");#OperatorTok("/");#NormalTok(" num_arrivals) ");#ControlFlowTok("if");#NormalTok(" num_arrivals ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#FloatTok("0.0");#NormalTok(",");],
[#NormalTok("            ");#StringTok("\"max_queue_len\"");#NormalTok(": max_queue_len,");],
[#NormalTok("            ");#StringTok("\"overflow_happened\"");#NormalTok(": overflow_happened,");],
[#NormalTok("            ");#StringTok("\"end_queue_len\"");#NormalTok(": end_queue_len,");],
[#NormalTok("            ");#StringTok("\"queue_len_trace\"");#NormalTok(": queue_len_trace,");],
[#NormalTok("        }");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" simulate(");#VariableTok("self");#NormalTok(", n_sim");#OperatorTok("=");#DecValTok("5000");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("123");#NormalTok("):");],
[#NormalTok("        rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(random_seed)");],
[#NormalTok("        runs ");#OperatorTok("=");#NormalTok(" [");#VariableTok("self");#NormalTok("._simulate_one_run(horizon_hours");#OperatorTok("=");#NormalTok("horizon_hours, rng");#OperatorTok("=");#NormalTok("rng) ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(n_sim)]");],
[],
[#NormalTok("        active_servers ");#OperatorTok("=");#NormalTok(" np.array([r[");#StringTok("\"active_servers\"");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" runs])");],
[#NormalTok("        num_arrivals ");#OperatorTok("=");#NormalTok(" np.array([r[");#StringTok("\"num_arrivals\"");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" runs])");],
[#NormalTok("        max_queue_len ");#OperatorTok("=");#NormalTok(" np.array([r[");#StringTok("\"max_queue_len\"");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" runs])");],
[#NormalTok("        end_queue_len ");#OperatorTok("=");#NormalTok(" np.array([r[");#StringTok("\"end_queue_len\"");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" runs])");],
[#NormalTok("        overflow ");#OperatorTok("=");#NormalTok(" np.array([r[");#StringTok("\"overflow_happened\"");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" runs], dtype");#OperatorTok("=");#BuiltInTok("float");#NormalTok(")");],
[#NormalTok("        waited ");#OperatorTok("=");#NormalTok(" np.array([r[");#StringTok("\"prob_wait_empirical_run\"");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" r ");#KeywordTok("in");#NormalTok(" runs])");],
[],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" {");],
[#NormalTok("            ");#StringTok("\"runs\"");#NormalTok(": runs,");],
[#NormalTok("            ");#StringTok("\"avg_active_servers\"");#NormalTok(": active_servers.mean(),");],
[#NormalTok("            ");#StringTok("\"avg_num_arrivals\"");#NormalTok(": num_arrivals.mean(),");],
[#NormalTok("            ");#StringTok("\"avg_prob_wait_per_run\"");#NormalTok(": waited.mean(),");],
[#NormalTok("            ");#StringTok("\"prob_overflow\"");#NormalTok(": overflow.mean(),");],
[#NormalTok("            ");#StringTok("\"avg_max_queue_len\"");#NormalTok(": max_queue_len.mean(),");],
[#NormalTok("            ");#StringTok("\"avg_end_queue_len\"");#NormalTok(": end_queue_len.mean(),");],
[#NormalTok("            ");#StringTok("\"active_servers_samples\"");#NormalTok(": active_servers,");],
[#NormalTok("            ");#StringTok("\"max_queue_len_samples\"");#NormalTok(": max_queue_len,");],
[#NormalTok("            ");#StringTok("\"end_queue_len_samples\"");#NormalTok(": end_queue_len,");],
[#NormalTok("        }");],
[],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#CommentTok("# Bagian 4: Visualisasi");],
[#NormalTok("    ");#CommentTok("# =========================");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_server_distribution(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        c_vals, probs ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".server_pmf()");],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("        plt.bar(c_vals, probs)");],
[#NormalTok("        plt.title(");#StringTok("\"Distribusi Jumlah Loket Aktif\"");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("\"Jumlah loket aktif (c)\"");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("\"Probabilitas\"");#NormalTok(")");],
[#NormalTok("        plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.show()");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_prob_wait_by_c(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        c_vals, _ ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".server_pmf()");],
[#NormalTok("        pw ");#OperatorTok("=");#NormalTok(" [");#VariableTok("self");#NormalTok(".erlang_c_prob_wait_given_c(");#BuiltInTok("int");#NormalTok("(c)) ");#ControlFlowTok("for");#NormalTok(" c ");#KeywordTok("in");#NormalTok(" c_vals]");],
[],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("        plt.plot(c_vals, pw, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(")");],
[#NormalTok("        plt.title(");#StringTok("\"Peluang Harus Menunggu vs Jumlah Loket Aktif\"");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("\"Jumlah loket aktif (c)\"");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("\"P(wait | c)\"");#NormalTok(")");],
[#NormalTok("        plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.show()");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_simulated_end_queue_hist(");#VariableTok("self");#NormalTok(", n_sim");#OperatorTok("=");#DecValTok("5000");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("123");#NormalTok("):");],
[#NormalTok("        sim ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".simulate(n_sim");#OperatorTok("=");#NormalTok("n_sim, horizon_hours");#OperatorTok("=");#NormalTok("horizon_hours, random_seed");#OperatorTok("=");#NormalTok("random_seed)");],
[#NormalTok("        data ");#OperatorTok("=");#NormalTok(" sim[");#StringTok("\"end_queue_len_samples\"");#NormalTok("]");],
[],
[#NormalTok("        bins ");#OperatorTok("=");#NormalTok(" np.arange(data.");#BuiltInTok("min");#NormalTok("() ");#OperatorTok("-");#NormalTok(" ");#FloatTok("0.5");#NormalTok(", data.");#BuiltInTok("max");#NormalTok("() ");#OperatorTok("+");#NormalTok(" ");#FloatTok("1.5");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("        plt.hist(data, bins");#OperatorTok("=");#NormalTok("bins, density");#OperatorTok("=");#VariableTok("True");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(")");],
[#NormalTok("        plt.axvline(");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.5");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Batas kursi tunggu\"");#NormalTok(")");],
[#NormalTok("        plt.title(");#StringTok("\"Histogram Panjang Antrean di Akhir Horizon\"");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("\"Jumlah dalam antrean\"");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("\"Frekuensi relatif\"");#NormalTok(")");],
[#NormalTok("        plt.legend()");],
[#NormalTok("        plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.show()");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" plot_overflow_vs_capacity(");#VariableTok("self");#NormalTok(", max_capacity");#OperatorTok("=");#DecValTok("20");#NormalTok(", n_sim");#OperatorTok("=");#DecValTok("3000");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("123");#NormalTok("):");],
[#NormalTok("        caps ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("0");#NormalTok(", max_capacity ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        probs ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("        old_cap ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".waiting_capacity");],
[],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" cap ");#KeywordTok("in");#NormalTok(" caps:");],
[#NormalTok("            ");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(cap)");],
[#NormalTok("            sim ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".simulate(n_sim");#OperatorTok("=");#NormalTok("n_sim, horizon_hours");#OperatorTok("=");#NormalTok("horizon_hours, random_seed");#OperatorTok("=");#NormalTok("random_seed)");],
[#NormalTok("            probs.append(sim[");#StringTok("\"prob_overflow\"");#NormalTok("])");],
[],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".waiting_capacity ");#OperatorTok("=");#NormalTok(" old_cap");],
[],
[#NormalTok("        plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("        plt.plot(caps, probs, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(")");],
[#NormalTok("        plt.title(");#StringTok("\"Peluang Overflow vs Kapasitas Kursi Tunggu\"");#NormalTok(")");],
[#NormalTok("        plt.xlabel(");#StringTok("\"Kapasitas kursi tunggu\"");#NormalTok(")");],
[#NormalTok("        plt.ylabel(");#StringTok("\"P(overflow dalam horizon)\"");#NormalTok(")");],
[#NormalTok("        plt.grid(alpha");#OperatorTok("=");#FloatTok("0.3");#NormalTok(")");],
[#NormalTok("        plt.show()");],
[],
[],
[#CommentTok("# =========================");],
[#CommentTok("# DEMO");],
[#CommentTok("# =========================");],
[#ControlFlowTok("if");#NormalTok(" ");#VariableTok("__name__");#NormalTok(" ");#OperatorTok("==");#NormalTok(" ");#StringTok("\"__main__\"");#NormalTok(":");],
[#NormalTok("    ");#CommentTok("# Contoh:");],
[#NormalTok("    ");#CommentTok("# rata-rata kedatangan 50 orang/jam");],
[#NormalTok("    ");#CommentTok("# tiap loket rata-rata melayani 12 orang/jam");],
[#NormalTok("    ");#CommentTok("# ada maksimum 6 loket");],
[#NormalTok("    ");#CommentTok("# tiap loket aktif dengan peluang 0.8");],
[#NormalTok("    ");#CommentTok("# kapasitas kursi tunggu 10");],
[#NormalTok("    model ");#OperatorTok("=");#NormalTok(" MMcBinomialServers(");],
[#NormalTok("        lambda_per_hour");#OperatorTok("=");#DecValTok("50");#NormalTok(",");],
[#NormalTok("        mu_per_server_per_hour");#OperatorTok("=");#DecValTok("12");#NormalTok(",");],
[#NormalTok("        n_servers_max");#OperatorTok("=");#DecValTok("6");#NormalTok(",");],
[#NormalTok("        p_active");#OperatorTok("=");#FloatTok("0.8");#NormalTok(",");],
[#NormalTok("        waiting_capacity");#OperatorTok("=");#DecValTok("10");#NormalTok(",");],
[#NormalTok("    )");],
[],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"=== ANALYTICAL SUMMARY ===\"");#NormalTok(")");],
[#NormalTok("    summary ");#OperatorTok("=");#NormalTok(" model.analytical_summary()");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" k, v ");#KeywordTok("in");#NormalTok(" summary.items():");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"");#SpecialCharTok("{");#NormalTok("k");#SpecialCharTok("}");#SpecialStringTok(": ");#SpecialCharTok("{");#NormalTok("v");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("=== SUMMARY BY c ===\"");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" row ");#KeywordTok("in");#NormalTok(" model.summary_by_c():");],
[#NormalTok("        ");#BuiltInTok("print");#NormalTok("(row)");],
[],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("=== SIMULATION SUMMARY ===\"");#NormalTok(")");],
[#NormalTok("    sim ");#OperatorTok("=");#NormalTok(" model.simulate(n_sim");#OperatorTok("=");#DecValTok("5000");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("42");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" k, v ");#KeywordTok("in");#NormalTok(" sim.items():");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" k ");#OperatorTok("!=");#NormalTok(" ");#StringTok("\"runs\"");#NormalTok(" ");#KeywordTok("and");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#BuiltInTok("isinstance");#NormalTok("(v, np.ndarray):");],
[#NormalTok("            ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"");#SpecialCharTok("{");#NormalTok("k");#SpecialCharTok("}");#SpecialStringTok(": ");#SpecialCharTok("{");#NormalTok("v");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("    ");#CommentTok("# plots");],
[#NormalTok("    model.plot_server_distribution()");],
[#NormalTok("    model.plot_prob_wait_by_c()");],
[#NormalTok("    model.plot_simulated_end_queue_hist(n_sim");#OperatorTok("=");#DecValTok("5000");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("42");#NormalTok(")");],
[#NormalTok("    model.plot_overflow_vs_capacity(max_capacity");#OperatorTok("=");#DecValTok("20");#NormalTok(", n_sim");#OperatorTok("=");#DecValTok("3000");#NormalTok(", horizon_hours");#OperatorTok("=");#FloatTok("1.0");#NormalTok(", random_seed");#OperatorTok("=");#DecValTok("42");#NormalTok(")");],));

#horizontalrule

== Cara membaca model ini
<cara-membaca-model-ini>
=== 1. Jumlah loket aktif acak
<jumlah-loket-aktif-acak>
Kalau ada maksimum 6 loket dan tiap loket aktif dengan peluang 0.8, maka:

\[ C \(6, 0.8)\]

Jadi bisa saja:

- 4 loket aktif
- 5 loket aktif
- 6 loket aktif dengan probabilitas masing-masing.

#horizontalrule

=== 2. Conditional M/M/c
<conditional-mmc>
Begitu #NormalTok("c"); diketahui, sistem menjadi #strong[M/M/c biasa].

Untuk tiap #NormalTok("c");, kita bisa hitung:

- \(P( c))
- \(L\_q c)
- \(W\_q c)

Lalu dirata-ratakan terhadap distribusi Binomial jumlah loket aktif.

#horizontalrule

=== 3. Overflow
<overflow>
Untuk #strong[overflow ruang tunggu], saya pakai #strong[simulasi discrete-event], karena:

- jumlah loket aktif acak,
- horizon waktu terbatas,
- kapasitas tunggu terbatas,

sehingga simulasi lebih mudah dipakai dan lebih fleksibel untuk demo kelas.

#horizontalrule

== Contoh interpretasi parameter
<contoh-interpretasi-parameter>
Misalnya:

- #NormalTok("lambda_per_hour = 50"); rata-rata 50 orang datang per jam

- #NormalTok("mu_per_server_per_hour = 12"); satu loket rata-rata melayani 12 orang per jam berarti rata-rata 1 orang tiap 5 menit

- #NormalTok("n_servers_max = 6");

- #NormalTok("p_active = 0.8"); rata-rata loket aktif = (6 = 4.8)

Karena kapasitas pelayanan rata-rata kira-kira:

\[ 4.8 = 57.6 \]

maka sistem cenderung masih aman, tetapi bila loket aktif kebetulan hanya 3 atau 4, antrean bisa muncul.

#horizontalrule

== Kalau ingin dipakai untuk kasus kantor catatan sipil tadi
<kalau-ingin-dipakai-untuk-kasus-kantor-catatan-sipil-tadi>
Anda bisa mulai dengan misalnya:

#Skylighting(([#NormalTok("model ");#OperatorTok("=");#NormalTok(" MMcBinomialServers(");],
[#NormalTok("    lambda_per_hour");#OperatorTok("=");#DecValTok("50");#NormalTok(",      ");#CommentTok("# 400/hari selama 8 jam");],
[#NormalTok("    mu_per_server_per_hour");#OperatorTok("=");#DecValTok("10");#NormalTok(",");],
[#NormalTok("    n_servers_max");#OperatorTok("=");#DecValTok("6");#NormalTok(",");],
[#NormalTok("    p_active");#OperatorTok("=");#FloatTok("0.9");#NormalTok(",");],
[#NormalTok("    waiting_capacity");#OperatorTok("=");#DecValTok("10");#NormalTok(",");],
[#NormalTok(")");],));
Lalu ubah #NormalTok("mu");, #NormalTok("n");, dan #NormalTok("p"); sesuai skenario:

- petugas penuh
- petugas kurang
- beberapa loket sering kosong
- jam sibuk vs jam sepi

#horizontalrule

== Catatan penting
<catatan-penting-2>
Model ini memakai asumsi:

- kedatangan Poisson
- waktu pelayanan eksponensial
- jumlah loket aktif tetap selama satu horizon simulasi, tetapi berubah antar run

Kalau Anda ingin, langkah berikutnya yang sangat bagus adalah membuat versi yang lebih realistis, misalnya:

- #strong[jumlah loket aktif berubah per menit]
- #strong[kedatangan berbeda per jam]
- #strong[pelanggan prioritas]
- #strong[kapasitas sistem total terbatas]
- atau #strong[dashboard interaktif] dengan slider memakai #NormalTok("ipywidgets"); atau #NormalTok("streamlit");

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
== Perhitungan Secara Manual
<perhitungan-secara-manual>
suato kantor catab sipil elayanirata-rata 400 orang per hari. b=dalam kenyataannya bisa 100, 300, 500, 700, atau angka lainberarti rata-rata per jam 50 orang. 8sa30, bisa 100, yang pasti rata rata 50. ini poisson Katakanlah dalam suatu interval 60 menit rata rata 5 kendaraan per 10 menit pelanggan tiba di loket pelayanan, meskipun tidak bersamaan.

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
#Skylighting(([#NormalTok("Arrival times: [1.8990419584469318, 5.253672784648889, 9.786470531833697, 9.858215771915864, 10.27620222085709, 10.722322550219051, 11.686371884875255, 15.443551726902612, 16.549538134145443, 17.48095878533312, 17.551891162412456, 17.56353467408023, 19.511271764756653, 19.511895190765983, 21.201363262607465, 22.061597714881746, 22.225339061883847, 22.22755309190093, 23.691107167453936, 23.856594208452922, 24.395620964705813, 25.47848215867778, 25.864237378572817, 26.101738528035323, 30.986098916454146, 34.50422385355723, 35.935685930201494, 36.27301139217622, 38.472927869063525, 40.881897314214214, 41.12937457562638, 43.65640014049428, 44.763175356415786, 49.11100940511131, 53.212282143613706, 57.13720345297227, 57.3856835913603, 57.572917196245285]");],
[#NormalTok("Total arrivals: 38");],));
]
]
Artinya: selama 60 detik terjadi 38 \*\* request\*\*.

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
#Skylighting(([#NormalTok("Arrival times: [1.1448430756706613, 1.193964964511888, 1.3427590948890764, 1.7363468307564165, 2.2362625224424324, 2.350589368945147, 2.666372409905928, 2.8453217634899888, 3.4914775185177986, 3.601322959650952, 3.666976747055993, 4.404879000410703, 4.431031687510749, 4.649038526612885, 6.109774887586973, 6.61883710640846, 7.0245489531604175, 7.049179286947824, 7.189481028713378, 7.323234859098078, 7.879877044708906, 8.043286464220948, 8.961581235051723, 9.374329163349797, 9.4789956081444, 9.76005887570681]");],
[#NormalTok("Total arrivals: 26");],));
]
]
Artinya: selama 10 detik terjadi 26 \*\* request\*\*.

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
#box(image("06_antrian_files/figure-typst/cell-13-output-1.svg"))

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
#box(image("06_antrian_files/figure-typst/cell-14-output-1.svg"))

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
#Skylighting(([#NormalTok("Average waiting time: 0.862136137615603");],));
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



