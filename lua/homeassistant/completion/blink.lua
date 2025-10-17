-- Blink.cmp completion source for Home Assistant
local M = {}

-- Create blink-compatible entity completion source
function M.entity_source(api)
  return {
    name = "homeassistant_entities",
    module = "homeassistant.completion.blink",
    
    -- Check if completion should be available
    enabled = function()
      return vim.bo.filetype == "yaml"
    end,
    
    -- Transform items for blink.cmp
    transform_items = function(_, items)
      return items
    end,
    
    -- Get completion items
    get_completions = function(_, context, callback)
      local line = context.line
      
      -- Check for entity_id patterns
      local patterns = {
        "entity_id:%s*(%S*)$",
        'entity_id:%s*"([^"]*)"?$',
        "entity_id:%s*'([^']*)'?$",
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
      
      -- Get entities from API
      api:get_states(function(err, entities)
        if err then
          callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
          return
        end
        
        local items = {}
        for _, entity in ipairs(entities) do
          table.insert(items, {
            label = entity.entity_id,
            kind = 5, -- Variable kind
            detail = entity.name,
            documentation = {
              kind = "markdown",
              value = string.format(
                "**%s**\n\nState: `%s`\n\nDomain: `%s`",
                entity.name,
                entity.state,
                entity.domain
              ),
            },
            insertText = entity.entity_id,
          })
        end
        
        callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
      end)
    end,
  }
end

-- Create blink-compatible service completion source
function M.service_source(api)
  local services_cache = nil
  
  return {
    name = "homeassistant_services",
    module = "homeassistant.completion.blink",
    
    enabled = function()
      return vim.bo.filetype == "yaml"
    end,
    
    transform_items = function(_, items)
      return items
    end,
    
    get_completions = function(_, context, callback)
      local line = context.line
      
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
      if services_cache then
        callback({ items = services_cache, is_incomplete_forward = false, is_incomplete_backward = false })
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
        
        services_cache = items
        callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
      end)
    end,
  }
end

return M
