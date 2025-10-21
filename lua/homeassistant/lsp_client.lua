-- LSP Client setup for Home Assistant LSP server
local M = {}

local logger = require("homeassistant.utils.logger")

function M.setup(user_config)
  local ok, err = pcall(function()
    local init_opts = user_config.lsp.settings or {}
    local cmd = user_config.lsp.cmd or { "homeassistant-lsp", "--stdio" }
    local filetypes = user_config.lsp.filetypes or { "yaml", "yaml.homeassistant", "python", "json" }

    -- Validate command exists
    if cmd[1] and vim.fn.executable(cmd[1]) == 0 then
      logger.warn(string.format("LSP command '%s' not found in PATH. Please install homeassistant-lsp: npm install -g homeassistant-lsp", cmd[1]))
    end

    -- Get completion capabilities from completion plugin (blink.cmp, nvim-cmp, etc.)
    local capabilities = vim.lsp.protocol.make_client_capabilities()

    -- Try to get capabilities from blink.cmp
    local has_blink, blink = pcall(require, 'blink.cmp')
    if has_blink then
      -- blink.cmp v0.8+ uses get_lsp_capabilities()
      if blink.get_lsp_capabilities then
        capabilities = blink.get_lsp_capabilities(capabilities)
      -- Older versions might store it differently
      elseif blink.config and blink.config.capabilities then
        capabilities = vim.tbl_deep_extend('force', capabilities, blink.config.capabilities)
      end
    else
      -- Fallback to nvim-cmp
      local has_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
      if has_cmp and cmp_nvim_lsp.default_capabilities then
        capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
      end
    end

    logger.debug("LSP capabilities: " .. vim.inspect(capabilities.textDocument.completion))

    vim.lsp.config('homeassistant', {
      cmd = cmd,
      filetypes = filetypes,
      root_dir = vim.fn.getcwd(),
      init_options = init_opts,
      on_attach = function(client, bufnr)
        M._setup_lsp_commands(client, bufnr)
      end,
      capabilities = capabilities,
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
  end)

  if not ok then
    logger.error("LSP setup failed: " .. tostring(err))
    return false
  end

  return true
end

function M._setup_lsp_commands(client, bufnr)
end

function M.execute_command(command, arguments, callback)
  local client = M.get_client()
  if not client then
    if callback then
      callback({ message = "LSP client not available" }, nil)
    end
    return
  end

  client.request('workspace/executeCommand', {
    command = command,
    arguments = arguments or {},
  }, callback)
end

function M.get_client()
  local clients = vim.lsp.get_clients({ name = "homeassistant" })
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
