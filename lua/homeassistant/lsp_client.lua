-- LSP Client setup for Home Assistant LSP server
local M = {}

local logger = require("homeassistant.utils.logger")

function M.setup(user_config)
  local init_opts = user_config.lsp.settings or {}
  local cmd = user_config.lsp.cmd or { "homeassistant-lsp", "--stdio" }
  local filetypes = user_config.lsp.filetypes or { "yaml", "yaml.homeassistant", "python", "json" }

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

  -- Start LSP immediately with hidden keepalive buffer
  vim.schedule(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'homeassistant-keepalive.yaml')
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].filetype = 'yaml'

    vim.lsp.start({
      name = 'homeassistant',
      cmd = cmd,
      root_dir = vim.fn.getcwd(),
      init_options = init_opts,
    }, { bufnr = buf })
  end)

  return true
end

function M._setup_lsp_commands(client, bufnr)
end

function M.execute_command(command, arguments, callback)
  vim.lsp.buf.execute_command({
    command = command,
    arguments = arguments or {},
  })

  if callback then
    vim.defer_fn(function()
      callback(nil, true)
    end, 100)
  end
end

function M.get_client()
  local clients = vim.lsp.get_active_clients({ name = "homeassistant" })
  if #clients > 0 then
    return clients[1]
  end
  return nil
end

function M.is_connected()
  local client = M.get_client()
  return client ~= nil
end

return M
