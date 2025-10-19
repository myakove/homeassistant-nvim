-- Configuration management
local M = {}

-- Default configuration
local defaults = {
  -- LSP Server settings
  lsp = {
    enabled = true, -- Enable LSP client
    cmd = { "homeassistant-lsp", "--stdio" }, -- LSP server command
    filetypes = { "yaml", "yaml.homeassistant", "python" }, -- File types to attach
    root_dir = nil, -- Auto-detect root directory (uses lspconfig.util.root_pattern)
    settings = {
      homeassistant = {
        host = "ws://localhost:8123/api/websocket", -- WebSocket URL
        token = nil, -- REQUIRED: Long-lived access token
        timeout = 5000, -- Request timeout in ms
      },
      cache = {
        enabled = true,
        ttl = 300, -- Cache TTL in seconds (5 minutes)
      },
      diagnostics = {
        enabled = true,
        debounce = 500, -- Debounce diagnostics in ms
      },
      completion = {
        minChars = 3, -- Minimum characters for domain completion
      },
    },
  },

  -- UI settings (Neovim-specific)
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

  -- Logging (plugin-level, not LSP)
  logging = {
    level = "info", -- debug, info, warn, error
  },

  -- Keymaps
  keymaps = {
    enabled = true, -- Set to false to disable all default keymaps
    dashboard = "<leader>hd",       -- Toggle dashboard
    picker = "<leader>hp",           -- Open entity picker (requires telescope)
    reload_cache = "<leader>hr",     -- Reload LSP cache
    debug = "<leader>hD",            -- Show debug info
    edit_dashboard = "<leader>he",   -- Edit HA Lovelace dashboards
  },
}

local config = vim.deepcopy(defaults)

-- Setup configuration with user overrides
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", defaults, user_config or {})

  -- Validate required fields
  if config.lsp.settings and config.lsp.settings.homeassistant and not config.lsp.settings.homeassistant.token then
    vim.notify(
      "Home Assistant token not configured. Please set lsp.settings.homeassistant.token in setup()",
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
