-- Distinct colors for type kinds via LSP semantic tokens, across all languages.
--
-- Language servers classify each type reference by kind and Neovim exposes that
-- as `@lsp.type.<kind>`. Catppuccin links most of these to a single color, so
-- classes/interfaces/structs/... all look alike. Overriding each base group
-- gives them their own color in every language whose server reports the kind.
-- Filetype-scoped variants (e.g. `@lsp.type.class.cs`) inherit from these base
-- groups, so per-language highlighting picks them up too.
--
-- NOTE: coverage depends on what each server emits. `class`/`interface`/`enum`/
-- `typeParameter` are common (C#, TypeScript, ...); `struct` comes from C#, Rust,
-- etc.; `recordClass`/`recordStruct`/`delegate` are C#-specific. Kinds a server
-- doesn't report just keep the theme default. Modifier distinctions such as
-- abstract/sealed/static are generally not emitted, so an abstract class stays a
-- plain `class`.

-- Colors are chosen to avoid Catppuccin's core token colors so type kinds stay
-- distinct from them: mauve (keywords), green (strings), blue (functions).
local mocha = {
  flamingo = "#f2cdcd",
  maroon = "#eba0ac",
  peach = "#fab387",
  yellow = "#f9e2af",
  green = "#a6e3a1",
  teal = "#94e2d5",
  sky = "#89dceb",
}

-- One entry per semantic token type kind (base, language-agnostic groups).
local type_colors = {
  ["@lsp.type.class"] = { fg = mocha.yellow },
  -- Generic "named type" kind: TypeScript `type` aliases, many Zig type
  -- references, etc. Matches the class/Treesitter `@type` color so plain types
  -- stay consistent; the specific kinds below override where the server knows
  -- more.
  ["@lsp.type.type"] = { fg = mocha.yellow },
  ["@lsp.type.interface"] = { fg = mocha.green, italic = true },
  ["@lsp.type.struct"] = { fg = mocha.teal },
  ["@lsp.type.enum"] = { fg = mocha.peach },
  -- record is class-like; maroon keeps it well clear of the mauve keyword color.
  ["@lsp.type.recordClass"] = { fg = mocha.maroon },
  ["@lsp.type.recordStruct"] = { fg = mocha.maroon },
  ["@lsp.type.delegate"] = { fg = mocha.sky },
  ["@lsp.type.typeParameter"] = { fg = mocha.flamingo, italic = true },

  -- Roslyn (unlike most servers) emits a semantic token for every bracket as
  -- `@lsp.type.punctuation`, which is unstyled and sits on top of
  -- rainbow-delimiters, flattening all C# brackets to gray. Clearing it lets
  -- rainbow-delimiters show through, so nested generics like
  -- `IEnumerable<IThing>` get per-depth bracket colors and read structurally.
  ["@lsp.type.punctuation"] = {},
}

local function apply()
  for group, opts in pairs(type_colors) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

-- Re-apply after any colorscheme load, which resets these groups.
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply })
apply()
