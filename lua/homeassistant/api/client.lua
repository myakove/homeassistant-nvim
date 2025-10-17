-- WebSocket client for Home Assistant API (wrapper)
local WebSocket = require("homeassistant.api.websocket")
local logger = require("homeassistant.utils.logger")

local M = {}
M.__index = M

-- Create new client
function M.new(config)
  local self = setmetatable({}, M)
  
  self.ws = WebSocket.new(config)
  
  -- Auto-connect on initialization
  self:connect()
  
  return self
end

-- Connect to Home Assistant
function M:connect(callback)
  if self.ws:is_connected() then
    if callback then callback(nil, true) end
    return
  end
  
  self.ws:connect(function(err, success)
    if err then
      logger.error("Failed to connect to Home Assistant: " .. err)
      if callback then callback(err, false) end
      return
    end
    
    logger.info("Connected to Home Assistant via WebSocket")
    if callback then callback(nil, true) end
  end)
end

-- Get all states
function M:get_states(callback)
  -- Use websocket's is_connected() instead of self.connected
  if not self.ws:is_connected() then
    logger.debug("get_states called but WebSocket not connected yet")
    if callback then callback("Not connected", nil) end
    return
  end
  
  self.ws:get_states(callback)
end

-- Get specific entity state
function M:get_state(entity_id, callback)
  -- Get all states and filter
  self:get_states(function(err, states)
    if err then
      callback(err, nil)
      return
    end
    
    for _, state in ipairs(states) do
      if state.entity_id == entity_id then
        callback(nil, state)
        return
      end
    end
    
    callback("Entity not found", nil)
  end)
end

-- Get all services
function M:get_services(callback)
  -- Use websocket's is_connected() instead of self.connected
  if not self.ws:is_connected() then
    logger.debug("get_services called but WebSocket not connected yet")
    if callback then callback("Not connected", nil) end
    return
  end
  
  self.ws:get_services(callback)
end

-- Call a service
function M:call_service(domain, service, data, callback)
  -- Use websocket's is_connected() instead of self.connected
  if not self.ws:is_connected() then
    logger.debug("call_service called but WebSocket not connected yet")
    if callback then callback("Not connected", nil) end
    return
  end
  
  self.ws:call_service(domain, service, data, callback)
end

-- Subscribe to state changes
function M:subscribe_state_changes(callback)
  if not self.ws:is_connected() then
    logger.error("Not connected to Home Assistant")
    return
  end
  
  self.ws:subscribe_events("state_changed", callback)
end

-- Test connection
function M:test_connection(callback)
  if self.ws:is_connected() then
    callback(true, "Connected")
  else
    callback(false, "Not connected")
  end
end

-- Disconnect
function M:disconnect()
  if self.ws then
    self.ws:disconnect()
  end
end

-- Check if connected
function M:is_connected()
  return self.ws and self.ws:is_connected()
end

return M
