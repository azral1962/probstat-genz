-- bookly.lua
-- Bookly-specific part and appendix handling for Typst books

local function is_typst_book()
  local file_state = quarto.doc.file_metadata()
  return quarto.doc.is_format("typst") and
         file_state ~= nil and
         file_state.file ~= nil
end

local header_filter = {
  Header = function(el)
    local file_state = quarto.doc.file_metadata()

    if not is_typst_book() then
      return nil
    end

    if file_state == nil or file_state.file == nil then
      return nil
    end

    local file = file_state.file
    local bookItemType = file.bookItemType

    -- Only handle H1 book items (parts and appendices)
    if el.level ~= 1 or bookItemType == nil then
      return nil
    end

    -- Handle parts: use bookly's #part() function
    if bookItemType == "part" then
      return pandoc.RawBlock('typst', '#part("' .. pandoc.utils.stringify(el.content) .. '")')
    end

    -- Handle appendices: use bookly's #show: appendix ambient
    if bookItemType == "appendix" then
      if file.bookItemNumber == 1 or file.bookItemNumber == nil then
        -- Update Quarto's appendix state for numbering
        local stateUpdate = pandoc.RawBlock('typst', '#appendix-state.update(true)')

        -- Apply bookly's appendix environment
        local appendixStyle = pandoc.RawBlock('typst', '#show: appendix')

        -- If this is the synthetic "Appendices" divider heading,
        -- emit a heading for TOC display (bookly doesn't auto-create one)
        if el.classes:includes("unnumbered") then
          local language = quarto.doc.language
          local appendicesTitle = (language and language["section-title-appendices"]) or "Appendices"
          local appendicesHeading = pandoc.RawBlock('typst',
            '#heading(level: 1, numbering: none)[' .. appendicesTitle .. ']')
          return {stateUpdate, appendixStyle, appendicesHeading}
        end

        -- First actual appendix chapter
        return {stateUpdate, appendixStyle, el}
      end
    end

    return nil
  end
}

-- Combine with file_metadata_filter so book metadata markers are parsed
-- during this filter's document traversal (needed for bookItemType, etc.)
return quarto.utils.combineFilters({
  quarto.utils.file_metadata_filter(),
  header_filter
})
