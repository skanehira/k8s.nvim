-- vim: ft=lua
std = "luajit"
cache = true

globals = {
  "vim",
}

read_globals = {
  -- plenary/busted test globals
  "describe",
  "it",
  "before_each",
  "after_each",
  "assert",
  "spy",
  "stub",
  "mock",
}

-- Ignore line length for now
ignore = {
  "631", -- max_line_length
}

exclude_files = {
  ".luarocks",
  "lua_modules",
}
