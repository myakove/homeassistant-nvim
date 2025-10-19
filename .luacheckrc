-- Luacheck configuration for Neovim plugin development
std = "luajit+busted"
cache = true

-- Global vim object
globals = {
  "vim",
}

-- Read-only globals
read_globals = {
  "vim",
}

-- Ignore warnings
ignore = {
  "212", -- Unused argument (common in callbacks)
  "213", -- Unused loop variable
}

-- Exclude test files from certain checks
files["test_*.lua"] = {
  std = "+busted",
}

-- Exclude certain directories
exclude_files = {
  ".luarocks",
  "lua_modules",
}

-- Maximum line length
max_line_length = 100
