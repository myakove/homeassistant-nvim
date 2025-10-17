-- Health check for :checkhealth homeassistant
local M = {}

function M.check()
  local health = vim.health or require("health")
  
  health.start("homeassistant.nvim")
  
  -- Check uv installation
  if vim.fn.executable("uv") == 1 then
    local version = vim.fn.system("uv --version"):gsub("\n", "")
    health.ok("uv is installed: " .. version)
  else
    health.error("uv is not installed", {
      "Install uv: https://docs.astral.sh/uv/getting-started/installation/",
      "curl -LsSf https://astral.sh/uv/install.sh | sh",
    })
  end
  
  -- Check Python 3
  if vim.fn.executable("python3") == 1 then
    local version = vim.fn.system("python3 --version"):gsub("\n", "")
    health.ok("Python 3 is available: " .. version)
  else
    health.warn("Python 3 not found (uv will handle it)")
  end
  
  -- Check if plugin is initialized
  local ok, ha = pcall(require, "homeassistant")
  if ok and ha.get_api then
    local api = ha.get_api()
    if api then
      health.ok("Plugin is initialized")
      
      -- Check WebSocket connection state
      if api.client and api.client.ws then
        local ws = api.client.ws
        
        -- Show configured URL
        local config = require("homeassistant.config")
        local ha_config = config.get().homeassistant
        health.info("URL: " .. (ha_config.host or "not configured"))
        
        -- Check WebSocket state directly (synchronous)
        if ws.state == "connected" then
          health.ok("Connected to Home Assistant WebSocket")
          
          -- Check cache for HA config
          local cache = require("homeassistant.utils.cache")
          local ha_info = cache.get("ha_config")
          local cached_entities = cache.get("entities:all")
          
          if ha_info then
            health.info("Version: " .. (ha_info.version or "unknown"))
            health.info("Location: " .. (ha_info.location_name or "unknown"))
          end
          
          if cached_entities and #cached_entities > 0 then
            local domains = {}
            for _, entity in ipairs(cached_entities) do
              domains[entity.domain] = (domains[entity.domain] or 0) + 1
            end
            health.info("Entities: " .. #cached_entities .. " across " .. vim.tbl_count(domains) .. " domains")
          end
          
          if not ha_info or not cached_entities then
            health.info("Run :HADebug to fetch and cache HA version info")
          end
        elseif ws.state == "connecting" or ws.state == "authenticating" then
          health.warn("WebSocket is connecting...", {
            "Wait a moment and run :checkhealth again",
          })
        else
          health.error("WebSocket not connected (state: " .. (ws.state or "unknown") .. ")", {
            "Check your host and token in config",
            "Verify Home Assistant is running",
            "Check :messages for connection errors",
          })
        end
      else
        health.error("WebSocket client not initialized", {
          "Plugin may not be configured correctly",
        })
      end
    else
      health.error("Plugin initialized but API not available")
    end
  else
    health.error("Plugin not initialized", {
      "Add to your Neovim config:",
      'require("homeassistant").setup({ homeassistant = { host = "...", token = "..." } })',
    })
  end
  
  -- Check completion engines
  local has_blink = pcall(require, "blink.cmp")
  local has_cmp = pcall(require, "cmp")
  
  if has_blink then
    health.ok("Completion engine: blink.cmp detected")
  elseif has_cmp then
    health.ok("Completion engine: nvim-cmp detected")
  else
    health.warn("No completion engine found", {
      "Install blink.cmp or nvim-cmp for completion support",
    })
  end
  
  -- Check telescope (optional)
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    health.ok("telescope.nvim detected (optional)")
  else
    health.info("telescope.nvim not found (optional - needed for :HAPicker)")
  end
end

return M
