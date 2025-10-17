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
    
    get_state = function(self, entity_id, callback)
      return self.client:get_state(entity_id, callback)
    end,
    
    get_services = function(self, callback)
      return self.client:get_services(callback)
    end,
    
    refresh_cache = function(self)
      self.entities:clear_cache()
      return self.entities:get_all()
    end,
    
    get_dashboards = function(self, callback)
      return self.client:get_dashboards(callback)
    end,
    
    get_dashboard_config = function(self, url_path, callback)
      return self.client:get_dashboard_config(url_path, callback)
    end,
    
    save_dashboard_config = function(self, url_path, config, callback)
      return self.client:save_dashboard_config(url_path, config, callback)
    end,
  }
end

return M
