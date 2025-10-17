-- LSP Client setup for Home Assistant LSP server
local M = {}

local logger = require("homeassistant.utils.logger")

-- Setup the LSP client
function M.setup(user_config)
  -- Check if lspconfig is available
  local ok, lspconfig = pcall(require, "lspconfig")
  if not ok then
    logger.warn("nvim-lspconfig not found. LSP features disabled.")
    logger.info("Install with: lazy = { 'neovim/nvim-lspconfig' }")
    return false
  end
  
  local configs = require("lspconfig.configs")
  local util = require("lspconfig.util")
  
  -- Define the homeassistant LSP server
  if not configs.homeassistant then
    configs.homeassistant = {
      default_config = {
        cmd = user_config.lsp.cmd or { "homeassistant-lsp", "--stdio" },
        filetypes = user_config.lsp.filetypes or { "yaml", "yaml.homeassistant", "python" },
        root_dir = user_config.lsp.root_dir or function(fname)
          return util.root_pattern(".git", "configuration.yaml")(fname) or util.path.dirname(fname)
        end,
        settings = user_config.lsp.settings or {},
        single_file_support = true,
      },
    }
  end
  
  -- Setup the server
  local init_opts = user_config.lsp.settings or {}
  
  lspconfig.homeassistant.setup({
    cmd = user_config.lsp.cmd or { "homeassistant-lsp", "--stdio" },
    filetypes = user_config.lsp.filetypes or { "yaml", "yaml.homeassistant", "python" },
    init_options = init_opts,  -- Pass settings as init_options
    on_attach = function(client, bufnr)
      -- Setup custom commands that UI components will use
      M._setup_lsp_commands(client, bufnr)
    end,
    on_init = function(client, initialize_result)
      logger.info("Home Assistant LSP initialized")
    end,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
  })
  
  -- Start LSP immediately in a scratch buffer so it's available right away
  vim.defer_fn(function()
    -- Create a temporary scratch buffer
    local scratch_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(scratch_buf, 'filetype', 'yaml')
    
    -- Start the LSP client attached to this buffer
    vim.lsp.start({
      name = 'homeassistant',
      cmd = user_config.lsp.cmd or { "homeassistant-lsp", "--stdio" },
      root_dir = vim.fn.getcwd(),
      init_options = init_opts,
    }, {
      bufnr = scratch_buf,
      reuse_client = function(client, config)
        -- Reuse if same name
        return client.name == config.name
      end,
    })
    
    -- Delete the scratch buffer after LSP starts
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(scratch_buf) then
        vim.api.nvim_buf_delete(scratch_buf, { force = true })
      end
    end, 100)
  end, 100)
  
  return true
end

-- Setup LSP commands for UI integration
function M._setup_lsp_commands(client, bufnr)
  -- These commands will be used by UI components
  -- Commands are executed via vim.lsp.buf.execute_command()
end

-- Execute LSP command helper
function M.execute_command(command, arguments, callback)
  vim.lsp.buf.execute_command({
    command = command,
    arguments = arguments or {},
  })
  
  -- LSP commands return via handlers, use callback if needed
  if callback then
    -- Set up one-time handler for command result
    -- This is a simplified approach - production would need better handling
    vim.defer_fn(function()
      callback(nil, true)
    end, 100)
  end
end

-- Get LSP client for homeassistant
function M.get_client()
  local clients = vim.lsp.get_active_clients({ name = "homeassistant" })
  if #clients > 0 then
    return clients[1]
  end
  return nil
end

-- Check if LSP is connected
function M.is_connected()
  local client = M.get_client()
  return client ~= nil
end

return M
