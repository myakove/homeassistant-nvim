-- WebSocket client for Home Assistant API
local logger = require("homeassistant.utils.logger")

local M = {}
M.__index = M

-- WebSocket connection states
local STATE = {
  DISCONNECTED = "disconnected",
  CONNECTING = "connecting",
  AUTHENTICATING = "authenticating",
  CONNECTED = "connected",
  ERROR = "error",
}

-- Create new WebSocket client
function M.new(config)
  local self = setmetatable({}, M)
  
  -- Parse host to get WebSocket URL
  local host = config.host:gsub("/$", "")
  host = host:gsub("^http://", "ws://")
  host = host:gsub("^https://", "wss://")
  self.url = host .. "/api/websocket"
  
  self.token = config.token
  
  -- Connection state
  self.state = STATE.DISCONNECTED
  self.job_id = nil
  self.message_id = 1
  self.pending_requests = {}
  self.event_handlers = {}
  self.subscriptions = {}
  self.message_buffer = ""
  
  return self
end

-- Connect to Home Assistant WebSocket API
function M:connect(callback)
  if self.state == STATE.CONNECTED then
    if callback then callback(nil, true) end
    return
  end
  
  if self.state == STATE.CONNECTING or self.state == STATE.AUTHENTICATING then
    logger.debug("Already connecting...")
    return
  end
  
  self.state = STATE.CONNECTING
  self.connect_callback = callback
  logger.debug("Connecting to Home Assistant WebSocket: " .. self.url)
  
  -- No installation needed - use uv run --with!
  self:_connect_via_python()
end

-- Connect using Python websockets client
function M:_connect_via_python()
  -- Get the path to the Python script using Neovim's runtime path
  -- This works with all plugin managers (lazy.nvim, packer, vim-plug, etc.)
  local script_paths = vim.api.nvim_get_runtime_file("scripts/websocket_client.py", false)
  
  if #script_paths == 0 then
    logger.error("Could not find websocket_client.py in runtime path")
    self.state = STATE.ERROR
    if self.connect_callback then
      self.connect_callback("Script not found", false)
    end
    return
  end
  
  local script_path = script_paths[1]
  
  -- Use uv run --with (zero installation, on-demand dependencies)
  self.job_id = vim.fn.jobstart({"uv", "run", "--with", "websockets", "python3", script_path, self.url, self.token}, {
    on_stdout = function(_, data, _)
      self:_on_stdout(data)
    end,
    on_stderr = function(_, data, _)
      self:_on_stderr(data)
    end,
    on_exit = function(_, code, _)
      self:_on_exit(code)
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if self.job_id <= 0 then
    logger.error("Failed to start WebSocket client. Is 'uv' installed? See: https://docs.astral.sh/uv/getting-started/installation/")
    self.state = STATE.ERROR
    if self.connect_callback then
      self.connect_callback("Failed to start WebSocket client - uv not found", false)
    end
  end
end

-- Handle stdout from WebSocket process
function M:_on_stdout(data)
  local logger = require("homeassistant.utils.logger")
  
  for _, line in ipairs(data) do
    if line and line ~= "" then
      self.message_buffer = self.message_buffer .. line
      
      -- Try to parse complete JSON messages
      local success, message = pcall(vim.json.decode, self.message_buffer)
      if success then
        logger.debug("Received complete message: " .. (message.type or "unknown") .. " (buffer size: " .. #self.message_buffer .. " bytes)")
        self:_handle_message(message)
        self.message_buffer = ""
      else
        -- Still accumulating message
        logger.debug("Buffering partial message, current size: " .. #self.message_buffer .. " bytes")
      end
    end
  end
end

-- Handle stderr from WebSocket process
function M:_on_stderr(data)
  local logger = require("homeassistant.utils.logger")
  for _, line in ipairs(data) do
    if line and line ~= "" then
      logger.error("WebSocket stderr: " .. line)
      -- If Python script crashes, we'll see it here
    end
  end
end

-- Handle process exit
function M:_on_exit(code)
  local logger = require("homeassistant.utils.logger")
  logger.error("WebSocket process exited with code: " .. code .. " (this should not happen unless connection closed)")
  self:_handle_disconnect()
end

-- Subscribe to state changes
function M:_subscribe_to_states()
  -- Just subscribe to the event - handlers will be called by _handle_message
  -- Don't create a recursive handler!
  local id = self:_send_message({
    type = "subscribe_events",
    event_type = "state_changed",
  })
  
  self.pending_requests[id] = {
    callback = function(err, result)
      if err then
        logger.debug("Failed to subscribe to state_changed: " .. (err.message or "unknown error"))
      else
        logger.debug("Subscribed to state_changed events")
        self.subscriptions["state_changed"] = id
      end
    end,
  }
end

-- Send WebSocket message
function M:_send_message(message)
  local logger = require("homeassistant.utils.logger")
  
  if not self.job_id or self.job_id <= 0 then
    logger.error("Cannot send message: job_id=" .. tostring(self.job_id))
    return nil
  end
  
  -- Add message ID if not present
  if message.type ~= "auth" and not message.id then
    message.id = self.message_id
    self.message_id = self.message_id + 1
  end
  
  local ok, json = pcall(vim.json.encode, message)
  if not ok then
    logger.error("Failed to encode message: " .. tostring(json))
    return nil
  end
  
  json = json .. "\n"
  
  local send_ok, send_err = pcall(vim.fn.chansend, self.job_id, json)
  if not send_ok then
    logger.error("Failed to send message: " .. tostring(send_err))
    return nil
  end
  
  logger.debug("Sent message: " .. message.type .. " (id=" .. tostring(message.id) .. ")")
  
  return message.id
end

-- Handle incoming message
function M:_handle_message(message)
  if type(message) ~= "table" then
    logger.error("Invalid message format")
    return
  end
  
  logger.debug("Received message: " .. (message.type or "unknown"))
  
  -- Handle message by type
  if message.type == "auth_required" then
    logger.debug("Authentication required")
    self.state = STATE.AUTHENTICATING
    -- Python script handles auth automatically
  elseif message.type == "auth_ok" then
    logger.debug("Authentication successful")
    self.state = STATE.CONNECTED
    if self.connect_callback then
      self.connect_callback(nil, true)
      self.connect_callback = nil
    end
    -- Subscribe to state changes
    self:_subscribe_to_states()
  elseif message.type == "auth_invalid" then
    logger.error("Authentication failed: " .. (message.message or "Invalid token"))
    self.state = STATE.ERROR
    if self.connect_callback then
      self.connect_callback("Authentication failed", false)
      self.connect_callback = nil
    end
  elseif message.type == "result" then
    -- Response to a command
    local req = self.pending_requests[message.id]
    if req then
      if message.success then
        req.callback(nil, message.result)
      else
        req.callback(message.error, nil)
      end
      self.pending_requests[message.id] = nil
    end
  elseif message.type == "event" then
    -- Event notification
    if message.event and message.event.event_type then
      local event_type = message.event.event_type
      if self.event_handlers[event_type] then
        for _, handler in ipairs(self.event_handlers[event_type]) do
          handler(message.event)
        end
      end
    end
  end
end

-- Subscribe to events
function M:subscribe_events(event_type, callback)
  -- Wait until connected
  if self.state ~= STATE.CONNECTED then
    vim.defer_fn(function()
      self:subscribe_events(event_type, callback)
    end, 100)
    return
  end
  
  local id = self:_send_message({
    type = "subscribe_events",
    event_type = event_type,
  })
  
  self.pending_requests[id] = {
    callback = function(err, result)
      if err then
        logger.error("Failed to subscribe to " .. event_type .. ": " .. (err.message or "unknown error"))
      else
        logger.debug("Subscribed to " .. event_type .. " events")
        
        -- Register event handler
        if not self.event_handlers[event_type] then
          self.event_handlers[event_type] = {}
        end
        table.insert(self.event_handlers[event_type], callback)
        
        self.subscriptions[event_type] = id
      end
    end,
  }
end

-- Get states
function M:get_states(callback)
  local logger = require("homeassistant.utils.logger")
  logger.debug("websocket:get_states called, state=" .. self.state .. ", job_id=" .. tostring(self.job_id))
  
  if self.state ~= STATE.CONNECTED then
    logger.debug("websocket:get_states - not connected, state=" .. self.state)
    if callback then
      callback("Not connected", nil)
    end
    return
  end
  
  local id = self:_send_message({
    type = "get_states",
  })
  
  logger.debug("websocket:get_states - message sent with id=" .. tostring(id))
  
  if id then
    self.pending_requests[id] = {
      callback = callback,
    }
  else
    logger.error("websocket:get_states - _send_message returned nil")
    if callback then
      callback("Failed to send message", nil)
    end
    return
  end
  
  self.pending_requests[id] = {
    callback = function(err, result)
      if callback then
        callback(err, result)
      end
    end,
  }
end

-- Get HA config (version, location, etc.)
function M:get_config(callback)
  local logger = require("homeassistant.utils.logger")
  
  if self.state ~= STATE.CONNECTED then
    if callback then
      callback("Not connected", nil)
    end
    return
  end
  
  local id = self:_send_message({
    type = "get_config",
  })
  
  if not id then
    logger.error("Failed to send get_config message")
    if callback then
      callback("Failed to send message", nil)
    end
    return
  end
  
  self.pending_requests[id] = {
    callback = function(err, result)
      if callback then
        callback(err, result)
      end
    end,
  }
end

-- Get services
function M:get_services(callback)
  local logger = require("homeassistant.utils.logger")
  logger.debug("websocket:get_services called, state=" .. self.state .. ", job_id=" .. tostring(self.job_id))
  
  if self.state ~= STATE.CONNECTED then
    logger.debug("websocket:get_services - not connected, state=" .. self.state)
    if callback then
      callback("Not connected", nil)
    end
    return
  end
  
  local id = self:_send_message({
    type = "get_services",
  })
  
  logger.debug("websocket:get_services - message sent with id=" .. tostring(id))
  
  if id then
    self.pending_requests[id] = {
      callback = callback,
    }
  else
    logger.error("websocket:get_services - _send_message returned nil")
    if callback then
      callback("Failed to send message", nil)
    end
  end
end

-- Get area registry
function M:get_areas(callback)
  local logger = require("homeassistant.utils.logger")
  
  if self.state ~= STATE.CONNECTED then
    if callback then
      callback("Not connected", nil)
    end
    return
  end
  
  local id = self:_send_message({
    type = "config/area_registry/list",
  })
  
  if not id then
    logger.error("Failed to send get_areas message")
    if callback then
      callback("Failed to send message", nil)
    end
    return
  end
  
  self.pending_requests[id] = {
    callback = function(err, result)
      if callback then
        callback(err, result)
      end
    end,
  }
end

-- Get entity registry (includes area assignments)
function M:get_entity_registry(callback)
  local logger = require("homeassistant.utils.logger")
  
  if self.state ~= STATE.CONNECTED then
    if callback then
      callback("Not connected", nil)
    end
    return
  end
  
  local id = self:_send_message({
    type = "config/entity_registry/list",
  })
  
  if not id then
    logger.error("Failed to send get_entity_registry message")
    if callback then
      callback("Failed to send message", nil)
    end
    return
  end
  
  self.pending_requests[id] = {
    callback = function(err, result)
      if callback then
        callback(err, result)
      end
    end,
  }
end

-- Handle disconnect
function M:_handle_disconnect()
  local logger = require("homeassistant.utils.logger")
  logger.debug("_handle_disconnect called, previous state=" .. self.state)
  
  self.state = STATE.DISCONNECTED
  
  if self.job_id and self.job_id > 0 then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
  
  logger.info("Disconnected from Home Assistant. Run :HAConnect to reconnect.")
end

-- Disconnect
function M:disconnect()
  logger.debug("Disconnecting from Home Assistant WebSocket")
  
  if self.job_id and self.job_id > 0 then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
  
  self.state = STATE.DISCONNECTED
end

-- Check if connected
function M:is_connected()
  return self.state == STATE.CONNECTED
end

return M
