-- Service call actions
local M = {}

-- Prompt for service call
function M.prompt()
  vim.ui.input({ prompt = "Service (domain.service): " }, function(service)
    if not service then return end
    
    local domain, service_name = service:match("^([^.]+)%.(.+)$")
    if not domain or not service_name then
      vim.notify("Invalid service format. Use: domain.service", vim.log.levels.ERROR)
      return
    end
    
    vim.ui.input({ prompt = "Entity ID (optional): " }, function(entity_id)
      local service_data = {}
      if entity_id and entity_id ~= "" then
        service_data.entity_id = entity_id
      end
      
      M.call(domain, service_name, service_data)
    end)
  end)
end

-- Call a service
function M.call(domain, service, data)
  local api = require("homeassistant").get_api()
  if not api then
    vim.notify("Home Assistant not initialized", vim.log.levels.ERROR)
    return
  end
  
  api:call_service(domain, service, data, function(err, result)
    if err then
      vim.notify("Service call failed: " .. (err.message or err), vim.log.levels.ERROR)
    else
      vim.notify("Service called successfully", vim.log.levels.INFO)
    end
  end)
end

return M
