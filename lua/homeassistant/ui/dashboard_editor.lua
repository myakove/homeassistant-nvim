-- Home Assistant Dashboard Editor
local logger = require("homeassistant.utils.logger")

local M = {}

-- Pick a dashboard to edit
function M.pick_dashboard()
  local api = require("homeassistant").get_api()
  if not api then
    vim.notify("Home Assistant not initialized", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Fetching dashboards...", vim.log.levels.INFO)
  
  api:get_dashboards(function(err, dashboards)
    if err then
      vim.notify("Failed to fetch dashboards: " .. err, vim.log.levels.ERROR)
      return
    end
    
    if #dashboards == 0 then
      vim.notify("No editable dashboards found (only storage-mode dashboards can be edited)", vim.log.levels.WARN)
      return
    end
    
    -- Filter out non-editable dashboards by checking their configs
    M._filter_editable_dashboards(dashboards, function(editable_dashboards)
      if #editable_dashboards == 0 then
        vim.notify("No editable Lovelace dashboards found (webpage/auto-managed dashboards excluded)", vim.log.levels.WARN)
        return
      end
      
      -- Try Telescope first
      local has_telescope = pcall(require, "telescope.builtin")
      if has_telescope then
        M._telescope_picker(editable_dashboards)
      else
        M._vim_select_picker(editable_dashboards)
      end
    end)
  end)
end

-- Filter dashboards to only include truly editable Lovelace configs
function M._filter_editable_dashboards(dashboards, callback)
  local api = require("homeassistant").get_api()
  local editable = {}
  local checked = 0
  local total = #dashboards
  
  if total == 0 then
    callback(editable)
    return
  end
  
  for _, dashboard in ipairs(dashboards) do
    api:get_dashboard_config(dashboard.url_path, function(err, config)
      checked = checked + 1
      
      -- Include dashboard if:
      -- 1. No error fetching config
      -- 2. Config has 'views' field (indicates it's a proper Lovelace dashboard)
      -- 3. Not a simple panel/iframe dashboard
      if not err and config and type(config) == "table" then
        -- Check if it's a valid Lovelace config (has views array)
        if config.views and type(config.views) == "table" then
          table.insert(editable, dashboard)
        end
      end
      
      -- When all dashboards are checked, return results
      if checked == total then
        callback(editable)
      end
    end)
  end
end

-- Telescope picker implementation
function M._telescope_picker(dashboards)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  pickers.new({}, {
    prompt_title = "Home Assistant Dashboards",
    finder = finders.new_table({
      results = dashboards,
      entry_maker = function(dashboard)
        local display_title = dashboard.title or dashboard.url_path or "Default"
        return {
          value = dashboard,
          display = string.format("%s (%s)", display_title, dashboard.mode or "storage"),
          ordinal = display_title,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.edit_dashboard(selection.value)
      end)
      return true
    end,
  }):find()
end

-- Fallback vim.ui.select picker
function M._vim_select_picker(dashboards)
  local items = {}
  for _, dashboard in ipairs(dashboards) do
    local title = dashboard.title or dashboard.url_path or "Default"
    table.insert(items, title)
  end
  
  vim.ui.select(items, {
    prompt = "Select dashboard to edit:",
  }, function(choice, idx)
    if choice and idx then
      M.edit_dashboard(dashboards[idx])
    end
  end)
end

-- Edit a dashboard
function M.edit_dashboard(dashboard)
  local api = require("homeassistant").get_api()
  
  vim.notify("Fetching dashboard configuration...", vim.log.levels.INFO)
  
  api:get_dashboard_config(dashboard.url_path, function(err, config)
    if err then
      vim.notify("Failed to fetch dashboard config: " .. err, vim.log.levels.ERROR)
      return
    end
    
    -- Create new buffer
    local buf = vim.api.nvim_create_buf(true, false)
    
    -- Set buffer name
    local buf_name = "ha://dashboards/" .. (dashboard.title or dashboard.url_path or "default")
    vim.api.nvim_buf_set_name(buf, buf_name)
    
    -- Convert config to YAML string using vim.json
    -- We'll use JSON format for now (easier to parse back)
    local json_content = vim.json.encode(config)
    
    -- Pretty print the JSON with indentation
    local lines = {}
    local indent = 0
    local in_string = false
    local current_line = ""
    
    for i = 1, #json_content do
      local char = json_content:sub(i, i)
      
      if char == '"' and (i == 1 or json_content:sub(i-1, i-1) ~= "\\") then
        in_string = not in_string
      end
      
      if not in_string then
        if char == "{" or char == "[" then
          current_line = current_line .. char
          table.insert(lines, string.rep("  ", indent) .. current_line)
          current_line = ""
          indent = indent + 1
        elseif char == "}" or char == "]" then
          if current_line ~= "" then
            table.insert(lines, string.rep("  ", indent) .. current_line)
            current_line = ""
          end
          indent = indent - 1
          table.insert(lines, string.rep("  ", indent) .. char)
        elseif char == "," then
          current_line = current_line .. char
          table.insert(lines, string.rep("  ", indent) .. current_line)
          current_line = ""
        else
          current_line = current_line .. char
        end
      else
        current_line = current_line .. char
      end
    end
    
    if current_line ~= "" then
      table.insert(lines, current_line)
    end
    
    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    -- Set filetype to json for syntax highlighting
    vim.api.nvim_buf_set_option(buf, "filetype", "json")
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    
    -- Store metadata for save operation
    vim.b[buf].ha_dashboard = {
      url_path = dashboard.url_path,
      title = dashboard.title,
      mode = dashboard.mode,
    }
    
    -- Attach save handler
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = buf,
      callback = function()
        M._save_dashboard(buf)
      end,
    })
    
    -- Display buffer
    vim.api.nvim_set_current_buf(buf)
    
    vim.notify(
      string.format("Editing dashboard: %s\nSave with :w to update Home Assistant", dashboard.title or "Default"),
      vim.log.levels.INFO
    )
  end)
end

-- Save dashboard back to HA
function M._save_dashboard(buf)
  local api = require("homeassistant").get_api()
  if not api then
    vim.notify("Home Assistant not initialized", vim.log.levels.ERROR)
    return
  end
  
  local metadata = vim.b[buf].ha_dashboard
  if not metadata then
    vim.notify("Invalid dashboard buffer", vim.log.levels.ERROR)
    return
  end
  
  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Parse JSON back to table
  local ok, config = pcall(vim.json.decode, content)
  
  if not ok then
    vim.notify("Failed to parse dashboard config. Make sure JSON syntax is valid: " .. tostring(config), vim.log.levels.ERROR)
    return
  end
  
  -- Save to HA
  vim.notify("Saving dashboard...", vim.log.levels.INFO)
  api:save_dashboard_config(metadata.url_path, config, function(err, result)
    if err then
      vim.notify("Failed to save dashboard: " .. tostring(err), vim.log.levels.ERROR)
    else
      vim.notify("Dashboard saved successfully!", vim.log.levels.INFO)
      vim.api.nvim_buf_set_option(buf, "modified", false)
    end
  end)
end

return M
