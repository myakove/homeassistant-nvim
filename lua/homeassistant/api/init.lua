-- API module initialization
local M = {}
local Client = require("homeassistant.api.client")
local Entities = require("homeassistant.api.entities")

-- Create new API instance
function M.new(config)
  local client = Client.new(config.homeassistant)
  local entities = Entities.new(client, config.cache)
  
  return {
    client = client,
    entities = entities,
    
    -- Convenience methods
    get_states = function(self, callback)
      return self.entities:get_all(callback)
    end,
    
    get_services = function(self, callback)
      return self.client:get_services(callback)
    end,
    
    call_service = function(self, domain, service, data, callback)
      return self.client:call_service(domain, service, data, callback)
    end,
    
    refresh_cache = function(self)
      self.entities:clear_cache()
      return self.entities:get_all()
    end,
  }
end

return M
