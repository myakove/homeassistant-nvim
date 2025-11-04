" homeassistant.vim - Home Assistant integration for Neovim
" Maintainer: Your Name
" Version: 0.1.0

if exists('g:loaded_homeassistant')
  finish
endif
let g:loaded_homeassistant = 1

" This file runs when lazy.nvim loads the plugin
" Initialization happens in setup() called from config function
" No autocommands here - path checking is handled by lazy.nvim's init function
