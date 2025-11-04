" homeassistant.vim - Home Assistant integration for Neovim
" Maintainer: Your Name
" Version: 0.1.0

if exists('g:loaded_homeassistant')
  finish
endif
let g:loaded_homeassistant = 1

" This file runs when lazy.nvim loads the plugin (which only happens when paths match)
" Set up autocommands to check paths when switching buffers
augroup HomeAssistantPathCheck
  autocmd!
  autocmd BufEnter * lua pcall(function() require("homeassistant")._lazy_setup(vim.api.nvim_get_current_buf()) end)
  autocmd BufRead * lua pcall(function() require("homeassistant")._lazy_setup(vim.api.nvim_get_current_buf()) end)
augroup END
