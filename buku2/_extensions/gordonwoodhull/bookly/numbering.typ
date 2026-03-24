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
