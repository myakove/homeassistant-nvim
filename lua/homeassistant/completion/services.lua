-- Service completion source for nvim-cmp
local M = {}

function M.new(api)
  local self = setmetatable({}, { __index = M })
  self.api = api
  self.services_cache = nil
  return self
end

function M:get_debug_name()
  return "homeassistant_services"
end

function M:is_available()
  return vim.bo.filetype == "yaml" or vim.bo.filetype == "python"
end

function M:get_trigger_characters()
  return { ":", "." }
end

function M:complete(params, callback)
  local line = params.context.cursor_before_line
  
  -- Check for service patterns (YAML and Python/AppDaemon)
  local patterns = {
    -- YAML patterns
    "service:%s*(%S*)$",
    'service:%s*"([^"]*)"?$',
    "service:%s*'([^']*)'?$",
    -- Python/AppDaemon patterns
    'call_service%s*%(%s*"([^"]*)"?$',  -- self.call_service("
    "call_service%s*%(%s*'([^']*)'?$",  -- self.call_service('
  }
  
  local should_complete = false
  for _, pattern in ipairs(patterns) do
    if line:match(pattern) then
      should_complete = true
      break
    end
  end
  
  if not should_complete then
    callback({ items = {}, isIncomplete = false })
    return
  end
  
  -- Get services from API (with caching)
  if self.services_cache then
    callback({ items = self.services_cache, isIncomplete = false })
    return
  end
  
  self.api:get_services(function(err, services_data)
    if err then
      callback({ items = {}, isIncomplete = false })
      return
    end
    
    local items = {}
    for domain, services in pairs(services_data) do
      if type(services) == "table" then
        for service_name, service_info in pairs(services) do
          if type(service_info) == "table" then
            local full_name = domain .. "." .. service_name
            table.insert(items, {
              label = full_name,
              kind = require("cmp").lsp.CompletionItemKind.Function,
              detail = service_info.description or "Home Assistant service",
              documentation = {
                kind = "markdown",
                value = self:_format_service_doc(service_info),
              },
              insertText = full_name,
            })
          end
        end
      end
    end
    
    self.services_cache = items
    callback({ items = items, isIncomplete = false })
  end)
end

function M:_format_service_doc(service_info)
  local doc = "**" .. (service_info.description or "Service") .. "**\n\n"
  
  if service_info.fields then
    doc = doc .. "**Fields:**\n"
    for field_name, field_info in pairs(service_info.fields) do
      doc = doc .. string.format(
        "- `%s`: %s\n",
        field_name,
        field_info.description or "No description"
      )
    end
  end
  
  return doc
end

return M
