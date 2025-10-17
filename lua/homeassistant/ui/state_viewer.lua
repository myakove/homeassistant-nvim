-- Entity state viewer
local floating = require("homeassistant.ui.floating")
local logger = require("homeassistant.utils.logger")

local M = {}

-- Show entity state
function M.show(entity_id)
  local lsp_client = require("homeassistant").get_lsp_client()
  if not lsp_client or not lsp_client.is_connected() then
    logger.error("LSP not connected")
    vim.notify("Home Assistant LSP not connected", vim.log.levels.ERROR)
    return
  end
  
  local client = lsp_client.get_client()
  if not client then
    logger.error("LSP client not found")
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
  
  -- Fetch entity state via LSP
  client.request("workspace/executeCommand", {
    command = "homeassistant.getEntityState",
    arguments = { entity_id },
  }, function(err, result)
    if err or not result or not result.success then
      local error_msg = err and vim.inspect(err) or (result and result.error or "unknown error")
      floating.set_lines(buf, { "Error: " .. error_msg })
      return
    end
    
    M._render_state(buf, result.data, config)
  end, client.id)
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
