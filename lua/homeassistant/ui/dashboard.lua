-- Home Assistant dashboard
local floating = require("homeassistant.ui.floating")
local logger = require("homeassistant.utils.logger")

local M = {}

-- Dashboard state
M.buf = nil
M.win = nil
M.is_open = false

-- Toggle dashboard
function M.toggle()
  if M.is_open then
    M.close()
  else
    M.open()
  end
end

-- Open dashboard
function M.open()
  if M.is_open then
    return
  end
  
  local api = require("homeassistant").get_api()
  if not api then
    logger.error("API not initialized")
    return
  end
  
  local config = require("homeassistant.config").get()
  
  -- Create floating window
  M.buf, M.win = floating.create_centered_float({
    width = config.ui.dashboard.width,
    height = config.ui.dashboard.height,
    border = config.ui.dashboard.border,
    title = " Home Assistant Dashboard ",
    filetype = "ha-dashboard",
  })
  
  M.is_open = true
  
  -- Set loading message
  floating.set_lines(M.buf, { "Loading entities..." })
  
  -- Fetch entities
  api:get_states(function(err, entities)
    if err then
      floating.set_lines(M.buf, { "Error loading entities: " .. err })
      return
    end
    
    M._render_dashboard(entities, config)
  end)
  
  -- Setup keymaps
  M._setup_keymaps()
  
  -- Autocommand to update state when window closes
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = M.buf,
    once = true,
    callback = function()
      M.is_open = false
      M.buf = nil
      M.win = nil
    end,
  })
end

-- Close dashboard
function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.is_open = false
  M.buf = nil
  M.win = nil
end

-- Render dashboard content
function M._render_dashboard(entities, config)
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  
  local lines = {}
  
  -- Header
  table.insert(lines, "═══════════════════════════════════════")
  table.insert(lines, " Home Assistant Entities")
  table.insert(lines, "═══════════════════════════════════════")
  table.insert(lines, "")
  
  -- Group entities by domain
  local by_domain = {}
  for _, entity in ipairs(entities) do
    local domain = entity.domain
    if not by_domain[domain] then
      by_domain[domain] = {}
    end
    table.insert(by_domain[domain], entity)
  end
  
  -- Render by domain
  for domain, domain_entities in pairs(by_domain) do
    table.insert(lines, string.format("▶ %s (%d)", domain:upper(), #domain_entities))
    table.insert(lines, "")
    
    for _, entity in ipairs(domain_entities) do
      local state_indicator = M._get_state_indicator(entity)
      local line = string.format(
        "  %s  %s",
        state_indicator,
        entity.name
      )
      table.insert(lines, line)
      
      local detail = string.format("      State: %s | ID: %s", entity.state, entity.entity_id)
      table.insert(lines, detail)
      table.insert(lines, "")
    end
  end
  
  floating.set_lines(M.buf, lines)
end

-- Get visual indicator for entity state
function M._get_state_indicator(entity)
  local state = entity.state:lower()
  
  if state == "on" or state == "home" or state == "open" then
    return "🟢"
  elseif state == "off" or state == "away" or state == "closed" then
    return "⚫"
  elseif state == "unavailable" then
    return "❌"
  else
    return "🔵"
  end
end

-- Setup dashboard keymaps
function M._setup_keymaps()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  
  -- Refresh
  vim.api.nvim_buf_set_keymap(
    M.buf,
    "n",
    "r",
    ":lua require('homeassistant.ui.dashboard')._refresh()<CR>",
    { noremap = true, silent = true }
  )
end

-- Refresh dashboard
function M._refresh()
  M.close()
  M.open()
end

return M
