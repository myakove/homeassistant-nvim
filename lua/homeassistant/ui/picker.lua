-- Telescope entity picker
local M = {}

-- Show entity picker
function M.entities()
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  if not has_telescope then
    vim.notify("Telescope not installed", vim.log.levels.WARN)
    return
  end
  
  local lsp_client = require("homeassistant").get_lsp_client()
  if not lsp_client or not lsp_client.is_connected() then
    vim.notify("Home Assistant LSP not connected", vim.log.levels.ERROR)
    return
  end
  
  local client = lsp_client.get_client()
  if not client then
    vim.notify("LSP client not found", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Fetching entities...", vim.log.levels.INFO)
  
  client.request("workspace/executeCommand", {
    command = "homeassistant.listEntities",
    arguments = {},
  }, function(err, result)
    if err then
      vim.notify("Failed to fetch entities: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    
    if not result or not result.success then
      vim.notify("Failed to fetch entities: " .. (result and result.error or "unknown error"), vim.log.levels.ERROR)
      return
    end
    
    local entities = result.data or {}
    
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "Home Assistant Entities",
      finder = finders.new_table({
        results = entities,
        entry_maker = function(entity)
          return {
            value = entity,
            display = string.format("%s - %s (%s)", entity.entity_id, entity.name, entity.state),
            ordinal = entity.entity_id .. " " .. entity.name,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          require("homeassistant.ui.state_viewer").show(selection.value.entity_id)
        end)
        return true
      end,
    }):find()
  end, client.id)
end

return M
