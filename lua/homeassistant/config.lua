-- Configuration management
local M = {}

-- Default configuration
local defaults = {
  -- Home Assistant connection settings
  homeassistant = {
    host = "http://localhost:8123",
    token = nil, -- Long-lived access token
    timeout = 5000, -- Request timeout in ms
    verify_ssl = true,
  },
  
  -- Completion settings
  completion = {
    enabled = true,
    entity_prefix = "entity:", -- Trigger prefix for entity completion
    service_prefix = "service:", -- Trigger prefix for service completion
    auto_trigger = true, -- Auto-trigger on typing
  },
  
  -- UI settings
  ui = {
    dashboard = {
      width = 0.8, -- 80% of screen width
      height = 0.8,
      border = "rounded",
      favorites = {}, -- List of favorite entity IDs
    },
    state_viewer = {
      border = "rounded",
      show_attributes = true,
    },
  },
  
  -- Cache settings
  cache = {
    enabled = true,
    ttl = 300, -- Cache TTL in seconds (5 minutes)
    auto_refresh = true, -- Auto-refresh cache on file save
  },
  
  -- Logging
  logging = {
    level = "info", -- debug, info, warn, error
    file = nil, -- Log file path (nil = no file logging)
  },
  
  -- WebSocket settings (for live updates)
  websocket = {
    enabled = false, -- Disabled by default
    auto_reconnect = true,
  },
}

local config = vim.deepcopy(defaults)

-- Setup configuration with user overrides
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", defaults, user_config or {})
  
  -- Validate required fields
  if not config.homeassistant.token then
    vim.notify(
      "Home Assistant token not configured. Please set homeassistant.token in setup()",
      vim.log.levels.WARN
    )
  end
end

-- Get current configuration
function M.get()
  return config
end

-- Get specific config value
function M.get_value(path)
  local keys = vim.split(path, ".", { plain = true })
  local value = config
  
  for _, key in ipairs(keys) do
    if value[key] then
      value = value[key]
    else
      return nil
    end
  end
  
  return value
end

return M
