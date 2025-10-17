-- Telescope entity picker
local M = {}

-- Show entity picker
function M.entities()
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  if not has_telescope then
    vim.notify("Telescope not installed", vim.log.levels.WARN)
    return
  end
  
  local api = require("homeassistant").get_api()
  if not api then
    vim.notify("Home Assistant not initialized", vim.log.levels.ERROR)
    return
  end
  
  api:get_states(function(err, entities)
    if err then
      vim.notify("Failed to fetch entities: " .. err, vim.log.levels.ERROR)
      return
    end
    
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
  end)
end

return M
