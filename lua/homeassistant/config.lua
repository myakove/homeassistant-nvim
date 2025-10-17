-- Configuration management
local M = {}

-- Helper function to read environment variable
local function get_env(name)
  local value = vim.fn.getenv(name)
  if value ~= vim.NIL and value ~= "" then
    return value
  end
  return nil
end

-- Helper function to convert string to boolean
local function to_boolean(value)
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "string" then
    local lower = value:lower()
    if lower == "true" or lower == "1" or lower == "yes" then
      return true
    elseif lower == "false" or lower == "0" or lower == "no" then
      return false
    end
  end
  return nil
end

-- Helper function to convert string to number
local function to_number(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" then
    return tonumber(value)
  end
  return nil
end

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
  
  -- LSP features
  lsp = {
    enabled = true, -- Enable LSP-like features
    hover = true, -- Show entity info on hover (CursorHold)
    diagnostics = true, -- Validate entity references and show warnings
    go_to_definition = true, -- Enable gd keymap to jump to entity info
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

-- Load configuration from environment variables
local function load_from_env()
  local env_config = {
    homeassistant = {},
  }
  
  -- Read environment variables (HOMEASSISTANT_ prefix)
  local host = get_env("HOMEASSISTANT_HOST")
  if host then
    env_config.homeassistant.host = host
  end
  
  local token = get_env("HOMEASSISTANT_TOKEN")
  if token then
    env_config.homeassistant.token = token
  end
  
  local timeout = get_env("HOMEASSISTANT_TIMEOUT")
  if timeout then
    local timeout_num = to_number(timeout)
    if timeout_num then
      env_config.homeassistant.timeout = timeout_num
    end
  end
  
  local verify_ssl = get_env("HOMEASSISTANT_VERIFY_SSL")
  if verify_ssl then
    local verify_bool = to_boolean(verify_ssl)
    if verify_bool ~= nil then
      env_config.homeassistant.verify_ssl = verify_bool
    end
  end
  
  return env_config
end

-- Setup configuration with user overrides
function M.setup(user_config)
  -- Priority: user_config > environment variables > defaults
  -- 1. Start with defaults
  local merged = vim.deepcopy(defaults)
  
  -- 2. Apply environment variables
  local env_config = load_from_env()
  merged = vim.tbl_deep_extend("force", merged, env_config)
  
  -- 3. Apply user config (highest priority)
  if user_config then
    merged = vim.tbl_deep_extend("force", merged, user_config)
  end
  
  config = merged
  
  -- Validate required fields
  if not config.homeassistant.token then
    vim.notify(
      "Home Assistant token not configured. Please set:\n" ..
      "1. homeassistant.token in setup(), OR\n" ..
      "2. HOMEASSISTANT_TOKEN environment variable",
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
