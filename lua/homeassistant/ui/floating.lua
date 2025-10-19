-- Floating window utilities
local M = {}

-- Create a centered floating window
function M.create_centered_float(config)
  config = config or {}

  local width = config.width or 0.8
  local height = config.height or 0.8
  local border = config.border or "rounded"

  -- Calculate dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = math.floor(ui.width * width)
  local win_height = math.floor(ui.height * height)

  -- Calculate position
  local row = math.floor((ui.height - win_height) / 2)
  local col = math.floor((ui.width - win_width) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", config.filetype or "")

  -- Window options
  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
  }

  -- Handle border configuration
  if type(border) == "table" and border.text then
    -- Advanced border with text
    win_opts.border = border.style or "rounded"
    if border.text.top then
      win_opts.title = border.text.top
      win_opts.title_pos = border.text.top_align or "center"
    end
    if border.text.bottom then
      win_opts.footer = border.text.bottom
      win_opts.footer_pos = border.text.bottom_align or "center"
    end
  else
    -- Simple border
    win_opts.border = border
    if config.title then
      win_opts.title = config.title
      win_opts.title_pos = "center"
    end
  end

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Set window options
  vim.api.nvim_win_set_option(win, "cursorline", true)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)

  -- Close keymaps
  local close_keys = { "q", "<Esc>" }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(
      buf,
      "n",
      key,
      string.format(":lua vim.api.nvim_win_close(%d, true)<CR>", win),
      { noremap = true, silent = true }
    )
  end

  return buf, win
end

-- Set buffer lines with proper formatting
function M.set_lines(buf, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Add highlight to buffer
function M.add_highlight(buf, namespace, hl_group, line, col_start, col_end)
  vim.api.nvim_buf_add_highlight(
    buf,
    namespace,
    hl_group,
    line,
    col_start,
    col_end
  )
end

return M
