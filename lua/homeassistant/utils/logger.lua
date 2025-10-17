-- Logging utility
local M = {}

local config = nil
local log_levels = {
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

-- Initialize logger with config
function M.init(cfg)
  config = cfg
end

-- Get current log level number
local function get_level_num()
  if not config then
    return log_levels.info
  end
  return log_levels[config.logging.level] or log_levels.info
end

-- Log message
local function log(level, message)
  local level_num = log_levels[level]
  if level_num < get_level_num() then
    return
  end
  
  local prefix = string.format("[homeassistant.nvim] [%s]", level:upper())
  local full_message = string.format("%s %s", prefix, message)
  
  -- Log to Neovim
  local vim_level = vim.log.levels[level:upper()] or vim.log.levels.INFO
  vim.notify(full_message, vim_level)
  
  -- Log to file if configured
  if config and config.logging.file then
    local file = io.open(config.logging.file, "a")
    if file then
      file:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), full_message))
      file:close()
    end
  end
end

function M.debug(message)
  log("debug", message)
end

function M.info(message)
  log("info", message)
end

function M.warn(message)
  log("warn", message)
end

function M.error(message)
  log("error", message)
end

return M
