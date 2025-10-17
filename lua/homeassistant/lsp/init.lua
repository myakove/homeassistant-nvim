-- LSP-like features for Home Assistant YAML files
local M = {}

-- Diagnostic namespace
M.ns = vim.api.nvim_create_namespace("homeassistant_lsp")

-- Setup LSP features
function M.setup(api, config)
  M.api = api
  M.config = config or {}
  
  -- Setup diagnostics validation
  if M.config.diagnostics ~= false then
    vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
      pattern = {"*.yaml", "*.yml", "*.py"},
      callback = function()
        M.validate_buffer()
      end,
    })
  end
  
  -- Setup smart hover that tries HA first, then falls back to LSP
  if M.config.hover ~= false then
    -- Override K keymap for yaml/python files
    -- Use multiple events to ensure we override LazyVim's keymap
    vim.api.nvim_create_autocmd({"FileType", "LspAttach", "BufEnter"}, {
      pattern = {"*.yaml", "*.yml", "*.py", "yaml", "python"},
      callback = function(args)
        local bufnr = args.buf
        local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
        
        if ft == "yaml" or ft == "python" then
          -- Delay to ensure we run after LazyVim sets its keymaps
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              vim.keymap.set("n", "K", function()
                M.smart_hover()
              end, { buffer = bufnr, desc = "HA hover (or LSP)", silent = true })
            end
          end, 100)  -- 100ms delay
        end
      end,
    })
  end
  
  -- Add go-to-definition keymap
  if M.config.go_to_definition ~= false then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {"yaml", "python"},
      callback = function()
        vim.keymap.set("n", "gd", function()
          M.go_to_definition()
        end, { buffer = true, desc = "Go to entity definition" })
      end,
    })
  end
end

-- Get entity ID under cursor
function M.get_entity_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  
  -- Try to match entity_id pattern (domain.entity_name)
  local patterns = {
    "([%w_]+%.[%w_]+)",  -- Basic pattern: sensor.temperature
    '"([%w_]+%.[%w_]+)"',  -- Quoted
    "'([%w_]+%.[%w_]+)'",  -- Single quoted
  }
  
  for _, pattern in ipairs(patterns) do
    for entity_id in line:gmatch(pattern) do
      -- Check if cursor is within this entity_id
      local start_pos, end_pos = line:find(entity_id, 1, true)
      if start_pos and end_pos and col >= start_pos - 1 and col <= end_pos then
        return entity_id
      end
    end
  end
  
  return nil
end

-- Smart hover: Try HA entity first, fall back to LSP
function M.smart_hover()
  -- Quick check: Is there an entity under cursor?
  local entity_id = M.get_entity_under_cursor()
  
  -- No entity detected or HA not connected → use LSP hover
  if not entity_id or not M.api or not M.api.client or not M.api.client:is_connected() then
    vim.lsp.buf.hover()
    return
  end
  
  -- Entity detected and HA connected → show HA info
  M.show_hover()
end

-- Show hover documentation
function M.show_hover()
  if not M.api then
    vim.notify("Home Assistant API not available", vim.log.levels.WARN)
    return
  end
  
  local entity_id = M.get_entity_under_cursor()
  if not entity_id then
    vim.notify("No entity ID under cursor", vim.log.levels.INFO)
    return
  end
  
  M.api:get_states(function(err, entities)
    if err then
      vim.notify("Failed to fetch entities: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    
    -- Find the entity
    local entity = nil
    for _, e in ipairs(entities) do
      if e.entity_id == entity_id then
        entity = e
        break
      end
    end
    
    if not entity then
      vim.notify("Entity not found: " .. entity_id, vim.log.levels.WARN)
      return
    end
    
    -- Create hover content
    local lines = {
      "# " .. entity.name,
      "",
      "**Entity ID:** `" .. entity.entity_id .. "`",
      "**Domain:** `" .. entity.domain .. "`",
      "**State:** `" .. tostring(entity.state) .. "`",
      "",
      "**Attributes:**",
    }
    
    -- Add attributes
    if entity.attributes then
      for key, value in pairs(entity.attributes) do
        if type(value) == "table" then
          table.insert(lines, string.format("- **%s:** `%s`", key, vim.inspect(value)))
        else
          table.insert(lines, string.format("- **%s:** `%s`", key, tostring(value)))
        end
      end
    end
    
    -- Show in floating window
    vim.lsp.util.open_floating_preview(lines, "markdown", {
      border = "rounded",
      focusable = false,
      close_events = {"CursorMoved", "BufLeave"},
    })
  end)
end

-- Validate buffer and show diagnostics
function M.validate_buffer()
  if not M.api then return end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Collect all entity IDs in the buffer
  local entity_refs = {}
  for lnum, line in ipairs(lines) do
    for entity_id in line:gmatch("([%w_]+%.[%w_]+)") do
      table.insert(entity_refs, {
        entity_id = entity_id,
        lnum = lnum,
        line = line,
      })
    end
  end
  
  if #entity_refs == 0 then
    -- Clear diagnostics if no entity refs
    vim.diagnostic.set(M.ns, bufnr, {})
    return
  end
  
  -- Fetch entities from HA and validate
  M.api:get_states(function(err, entities)
    if err then return end
    
    -- Create a set of valid entity IDs
    local valid_entities = {}
    for _, entity in ipairs(entities) do
      valid_entities[entity.entity_id] = true
    end
    
    -- Check each reference
    local diagnostics = {}
    for _, ref in ipairs(entity_refs) do
      if not valid_entities[ref.entity_id] then
        table.insert(diagnostics, {
          lnum = ref.lnum - 1,  -- 0-indexed
          col = ref.line:find(ref.entity_id, 1, true) - 1,  -- 0-indexed
          end_col = ref.line:find(ref.entity_id, 1, true) + #ref.entity_id - 1,
          severity = vim.diagnostic.severity.WARN,
          message = string.format("Unknown entity: %s", ref.entity_id),
          source = "homeassistant",
        })
      end
    end
    
    -- Set diagnostics
    vim.diagnostic.set(M.ns, bufnr, diagnostics)
  end)
end

-- Go to definition (for now, just show entity info in a split)
function M.go_to_definition()
  local entity_id = M.get_entity_under_cursor()
  if not entity_id then
    vim.notify("No entity ID under cursor", vim.log.levels.WARN)
    return
  end
  
  require("homeassistant.ui.state_viewer").show(entity_id)
end

return M
