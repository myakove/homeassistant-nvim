-- Blink.cmp service completion source for Home Assistant
local Source = {}

-- Constructor required by blink.cmp
function Source.new()
  local logger = require("homeassistant.utils.logger")
  logger.debug("blink_services: Source.new() called - initializing service source")
  local self = setmetatable({}, { __index = Source })
  self.services_cache = nil
  return self
end

-- Get the API instance
local function get_api()
  return require("homeassistant").get_api()
end

-- Get source name
function Source:get_debug_name()
  return "homeassistant_services"
end

-- Check if source should be enabled
function Source:enabled()
  local enabled = vim.bo.filetype == "yaml" or vim.bo.filetype == "python"
  local logger = require("homeassistant.utils.logger")
  logger.debug("blink_services: enabled() called, filetype=" .. vim.bo.filetype .. ", enabled=" .. tostring(enabled))
  return enabled
end

-- Get trigger characters for blink.cmp
function Source:get_trigger_characters()
  return { ".", ":" }
end

-- Get completion items
function Source:get_completions(context, callback)
  local api = get_api()
  if not api then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  
  local line = context.line or context.cursor_before_line
  
  -- Check for service patterns
  local patterns = {
    "service:%s*(%S*)$",
    'service:%s*"([^"]*)"?$',
    "service:%s*'([^']*)'?$",
  }
  
  local should_complete = false
  for _, pattern in ipairs(patterns) do
    if line:match(pattern) then
      should_complete = true
      break
    end
  end
  
  if not should_complete then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  
  -- Use cached services if available
  if self.services_cache then
    callback({ items = self.services_cache, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  
  -- Get services from API
  api:get_services(function(err, services_data)
    if err then
      callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
      return
    end
    
    local items = {}
    for domain, services in pairs(services_data) do
      if type(services) == "table" then
        for service_name, service_info in pairs(services) do
          if type(service_info) == "table" then
            local full_name = domain .. "." .. service_name
            
            local doc = "**" .. (service_info.description or "Service") .. "**\n\n"
            if service_info.fields then
              doc = doc .. "**Fields:**\n"
              for field_name, field_info in pairs(service_info.fields) do
                doc = doc .. string.format("- `%s`: %s\n", field_name, field_info.description or "No description")
              end
            end
            
            table.insert(items, {
              label = full_name,
              kind = 3, -- Function kind
              detail = service_info.description or "Home Assistant service",
              documentation = {
                kind = "markdown",
                value = doc,
              },
              insertText = full_name,
            })
          end
        end
      end
    end
    
    self.services_cache = items
    callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
  end)
end

return Source
