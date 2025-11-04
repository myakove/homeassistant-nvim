" homeassistant.vim - Home Assistant integration for Neovim
" Maintainer: Your Name
" Version: 0.1.0

if exists('g:loaded_homeassistant')
  finish
endif
let g:loaded_homeassistant = 1

" Function to check if current buffer should trigger plugin loading
" This is called by autocommands to check if we should initialize lazily
function! s:maybe_load_plugin()
  " Call Lua function to check and potentially initialize
  " The Lua function handles all the logic (checking if initialized, if setup() was called, path matching)
  lua require("homeassistant")._lazy_setup()
endfunction

" Set up autocommands to check paths on buffer enter/read
augroup HomeAssistantPathCheck
  autocmd!
  " Check when entering a buffer
  autocmd BufEnter * call s:maybe_load_plugin()
  " Check when reading a file
  autocmd BufRead * call s:maybe_load_plugin()
augroup END

" Also check current buffer immediately (for when plugin is first loaded)
call s:maybe_load_plugin()
