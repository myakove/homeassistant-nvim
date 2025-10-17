-- Completion module initialization
local M = {}

-- Setup completion sources
function M.setup(api)
  local logger = require("homeassistant.utils.logger")
  
  -- Try blink.cmp first
  local blink_ok, blink = pcall(require, "blink.cmp")
  if blink_ok then
    M._setup_blink(api, logger)
    return
  end
  
  -- Fall back to nvim-cmp
  local cmp_ok, cmp = pcall(require, "cmp")
  if cmp_ok then
    M._setup_nvim_cmp(api, logger)
    return
  end
  
  -- Check for blink.compat (nvim-cmp sources work with blink.cmp)
  local compat_ok = pcall(require, "blink.compat")
  if compat_ok then
    M._setup_nvim_cmp(api, logger)
    logger.debug("Completion sources registered (nvim-cmp via blink.compat)")
    return
  end
  
  logger.warn("No completion plugin found (nvim-cmp or blink.cmp). Completion disabled.")
end

-- Setup blink.cmp native sources
function M._setup_blink(api, logger)
  local blink_sources = require("homeassistant.completion.blink")
  
  -- Register sources with blink.cmp config
  -- Users need to add these to their blink.cmp config:
  -- sources = {
  --   default = { ..., "homeassistant_entities", "homeassistant_services" },
  --   providers = {
  --     homeassistant_entities = { name = "HomeAssistant", module = "homeassistant.completion.blink" },
  --     homeassistant_services = { name = "HomeAssistant", module = "homeassistant.completion.blink" },
  --   }
  -- }
  
  logger.debug("Completion sources ready for blink.cmp")
  logger.debug("Add 'homeassistant_entities' and 'homeassistant_services' to your blink.cmp config sources")
end

-- Setup nvim-cmp sources
function M._setup_nvim_cmp(api, logger)
  local cmp = require("cmp")
  
  -- Register entity completion source
  local entity_source = require("homeassistant.completion.entities").new(api)
  cmp.register_source("homeassistant_entities", entity_source)
  
  -- Register service completion source
  local service_source = require("homeassistant.completion.services").new(api)
  cmp.register_source("homeassistant_services", service_source)
  
  logger.debug("Completion sources registered (nvim-cmp)")
end

return M
