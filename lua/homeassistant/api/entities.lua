-- Entity management with caching
local cache = require("homeassistant.utils.cache")
local logger = require("homeassistant.utils.logger")

local M = {}
M.__index = M

-- Create new entity manager
function M.new(client, cache_config)
  local self = setmetatable({}, M)
  
  self.client = client
  self.cache_enabled = cache_config.enabled ~= false
  self.cache_ttl = cache_config.ttl or 300
  self.entities = {}
  
  return self
end

-- Get all entities (with caching)
function M:get_all(callback)
  -- Check cache first
  if self.cache_enabled then
    local cached = cache.get("entities:all")
    if cached then
      logger.debug("Returning cached entities")
      if callback then
        callback(nil, cached)
      end
      return cached
    end
  end
  
  -- Fetch from API
  self.client:get_states(function(err, data)
    if err then
      logger.error("Failed to fetch entities: " .. err)
      if callback then
        callback(err, nil)
      end
      return
    end
    
    -- Process entities
    self.entities = self:_process_entities(data)
    
    -- Cache results
    if self.cache_enabled then
      cache.set("entities:all", self.entities, self.cache_ttl)
    end
    
    logger.debug(string.format("Fetched %d entities", #self.entities))
    
    if callback then
      callback(nil, self.entities)
    end
  end)
  
  return self.entities
end

-- Process raw entity data
function M:_process_entities(raw_data)
  local processed = {}
  
  for _, entity in ipairs(raw_data) do
    table.insert(processed, {
      entity_id = entity.entity_id,
      state = entity.state,
      attributes = entity.attributes,
      last_changed = entity.last_changed,
      last_updated = entity.last_updated,
      context = entity.context,
      
      -- Parsed components
      domain = self:_get_domain(entity.entity_id),
      name = entity.attributes.friendly_name or entity.entity_id,
    })
  end
  
  return processed
end

-- Extract domain from entity_id
function M:_get_domain(entity_id)
  return entity_id:match("^([^.]+)")
end

-- Get entities by domain
function M:get_by_domain(domain)
  local filtered = {}
  
  for _, entity in ipairs(self.entities) do
    if entity.domain == domain then
      table.insert(filtered, entity)
    end
  end
  
  return filtered
end

-- Search entities by query
function M:search(query)
  query = query:lower()
  local results = {}
  
  for _, entity in ipairs(self.entities) do
    if entity.entity_id:lower():find(query, 1, true) or
       entity.name:lower():find(query, 1, true) then
      table.insert(results, entity)
    end
  end
  
  return results
end

-- Clear cache
function M:clear_cache()
  cache.clear("entities:all")
  logger.info("Entity cache cleared")
end

return M
