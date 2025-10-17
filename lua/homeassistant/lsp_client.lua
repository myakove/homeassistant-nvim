-- LSP Client setup for Home Assistant LSP server
local M = {}

local logger = require("homeassistant.utils.logger")

-- Setup the LSP client
function M.setup(user_config)
  local init_opts = user_config.lsp.settings or {}
  local cmd = user_config.lsp.cmd or { "homeassistant-lsp", "--stdio" }
  local filetypes = user_config.lsp.filetypes or { "yaml", "yaml.homeassistant", "python" }
  
  -- Register homeassistant LSP using native Neovim API with REAL filetypes
  vim.lsp.config('homeassistant', {
    cmd = cmd,
    filetypes = filetypes,
    root_dir = vim.fn.getcwd(),
    init_options = init_opts,
    on_attach = function(client, bufnr)
      M._setup_lsp_commands(client, bufnr)
    end,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
  })
  
  vim.lsp.enable('homeassistant')
  
  -- Create hidden keepalive buffer to start LSP immediately on Neovim launch
  vim.schedule(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'homeassistant-keepalive.yaml')
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].filetype = 'yaml' -- Use real filetype
    
    -- Start LSP on keepalive buffer
    vim.lsp.start({
      name = 'homeassistant',
      cmd = cmd,
      root_dir = vim.fn.getcwd(),
      init_options = init_opts,
    }, { bufnr = buf })
  end)
  
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
