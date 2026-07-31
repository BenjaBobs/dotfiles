; extends

; nvim-treesitter's json `locals` query only defines scopes ((object) and
; (array)) — it captures no definitions. Symbol pickers driven by the `locals`
; query (e.g. Snacks' treesitter picker) therefore find nothing in a JSON
; buffer. Capturing object keys as field definitions gives them a nested
; outline of the document to navigate.
(pair
  key: (string (string_content) @local.definition.field))
