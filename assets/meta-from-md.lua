function Pandoc (doc)
  doc.meta.date_meta = os.date("%Y-%m-%d") -- for use in html `meta name=date`
  doc.meta.date = os.date("%d %B 1%Y HE"):gsub("^0*", "", 1) -- human date format for the footer
  doc.blocks:walk {
    Header = function (h)
      -- use top-level heading as title, unless the doc
      -- already has a title
      if h.level == 1 and not doc.meta.title then
        doc.meta.title = h.content
        -- return {}  -- remove this heading from the body
      end
    end
  }
  return doc
end

