// Import bookly and its key functions
#import "@local/bookly:1.1.3": bookly, part, appendix, front-matter, main-matter

// Apply bookly template
// Note: title-page: none disables bookly's title page (Quarto handles its own)
#show: bookly.with(
$if(title)$
  title: [$title$],
$endif$
$if(by-author)$
  author: "$for(by-author)$$it.name.literal$$sep$, $endfor$",
$endif$
  title-page: none,
)

// Use main-matter for standard book content
#show: main-matter

$if(margin-geometry)$
// Configure marginalia page geometry for book context
// Geometry computed by Quarto's meta.lua filter (typstGeometryFromPaperWidth)
// IMPORTANT: This must come AFTER bookly.with() to override bookly's margin settings
#import "@preview/marginalia:0.3.1" as marginalia

#show: marginalia.setup.with(
  inner: (
    far: $margin-geometry.inner.far$,
    width: $margin-geometry.inner.width$,
    sep: $margin-geometry.inner.separation$,
  ),
  outer: (
    far: $margin-geometry.outer.far$,
    width: $margin-geometry.outer.width$,
    sep: $margin-geometry.outer.separation$,
  ),
  top: $if(margin.top)$$margin.top$$else$1.25in$endif$,
  bottom: $if(margin.bottom)$$margin.bottom$$else$1.25in$endif$,
  // CRITICAL: Enable book mode for recto/verso awareness
  book: true,
  clearance: $margin-geometry.clearance$,
)
$endif$

// Apply chapter-based numbering to all figures
// Bookly may not number Quarto's custom figure kinds (quarto-float-fig, etc.)
#set figure(numbering: figure-numbering)
