-- Entity state viewer
local floating = require("homeassistant.ui.floating")
local logger = require("homeassistant.utils.logger")

local M = {}

-- Show entity state
function M.show(entity_id)
  local api = require("homeassistant").get_api()
  if not api then
    logger.error("API not initialized")
    return
  end
  
  local config = require("homeassistant.config").get()
  
  -- Create floating window
  local buf, win = floating.create_centered_float({
    width = 0.6,
    height = 0.6,
    border = config.ui.state_viewer.border,
    title = " Entity State: " .. entity_id .. " ",
    filetype = "yaml",
  })
  
  -- Set loading message
  floating.set_lines(buf, { "Loading..." })
  
  -- Fetch entity state
  api:get_state(entity_id, function(err, state)
    if err then
      floating.set_lines(buf, { "Error: " .. err })
      return
    end
    
    M._render_state(buf, state, config)
  end)
end

-- Render entity state
function M._render_state(buf, state, config)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  
  local lines = {}
  
  table.insert(lines, "Entity ID: " .. state.entity_id)
  table.insert(lines, "State: " .. state.state)
  table.insert(lines, "")
  
  if config.ui.state_viewer.show_attributes and state.attributes then
    table.insert(lines, "Attributes:")
    for key, value in pairs(state.attributes) do
      local value_str = type(value) == "table" and vim.inspect(value) or tostring(value)
      table.insert(lines, string.format("  %s: %s", key, value_str))
    end
    table.insert(lines, "")
  end
  
  table.insert(lines, "Last Changed: " .. (state.last_changed or "unknown"))
  table.insert(lines, "Last Updated: " .. (state.last_updated or "unknown"))
  
  floating.set_lines(buf, lines)
end

return M
