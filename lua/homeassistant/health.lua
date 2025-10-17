-- Health check for :checkhealth homeassistant
local M = {}

function M.check()
  local health = vim.health or require("health")
  
  health.start("homeassistant.nvim")
  
  -- Check if homeassistant-lsp is installed
  if vim.fn.executable("homeassistant-lsp") == 1 then
    health.ok("homeassistant-lsp is installed")
  else
    health.error("homeassistant-lsp is not installed", {
      "Install: npm install -g homeassistant-lsp",
      "Or see: https://github.com/myakove/homeassistant-lsp",
    })
  end
  
  -- Check nvim-lspconfig
  local has_lspconfig = pcall(require, "lspconfig")
  if has_lspconfig then
    health.ok("nvim-lspconfig is installed")
  else
    health.error("nvim-lspconfig is not installed", {
      "Install: lazy = { 'neovim/nvim-lspconfig' }",
    })
  end
  
  -- Check if plugin is initialized
  local ok, ha = pcall(require, "homeassistant")
  if ok and ha.get_lsp_client then
    local lsp_client = ha.get_lsp_client()
    if lsp_client then
      health.ok("Plugin is initialized")
      
      -- Check LSP connection
      if lsp_client.is_connected() then
        health.ok("LSP client is connected")
        
        -- Show configured URL
        local config = require("homeassistant.config")
        local lsp_config = config.get().lsp
        if lsp_config and lsp_config.settings and lsp_config.settings.homeassistant then
          health.info("Host: " .. (lsp_config.settings.homeassistant.host or "not configured"))
        end
        
        health.info("LSP server is providing: completion, hover, diagnostics, commands")
      else
        health.warn("LSP client not connected", {
          "Make sure you're in a YAML or Python file",
          "Check :LspInfo for connection status",
          "Check LSP logs: ~/.local/state/nvim/lsp.log",
        })
      end
    else
      health.error("Plugin initialized but LSP client not available", {
        "LSP may be disabled in config",
        "Check your setup() call",
      })
    end
  else
    health.error("Plugin not initialized", {
      "Add to your Neovim config:",
      'require("homeassistant").setup({',
      '  lsp = {',
      '    settings = {',
      '      homeassistant = {',
      '        host = "ws://localhost:8123/api/websocket",',
      '        token = "your-token-here"',
      '      }',
      '    }',
      '  }',
      '})',
    })
  end
  
  -- Check LSP completion capability
  health.info("Completion is provided by LSP (works with any LSP-compatible client)")
  
  -- Check telescope (optional)
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    health.ok("telescope.nvim detected (optional)")
  else
    health.info("telescope.nvim not found (optional - needed for :HAPicker)")
  end
end

return M
