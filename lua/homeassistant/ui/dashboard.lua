-- Home Assistant dashboard
local floating = require("homeassistant.ui.floating")
local logger = require("homeassistant.utils.logger")

local M = {}

-- Dashboard state
M.buf = nil
M.win = nil
M.is_open = false
M.current_view = "domains"  -- domains, areas, status
M.current_tab = "entities"   -- entities, services
M.filter_text = ""
M.collapsed_sections = {}    -- Track which sections are collapsed (default: all collapsed)
M.section_lines = {}         -- Map line number to section key
M.data = {
  entities = {},
  services = {},
  areas = {},
  entity_registry = {},
}

-- Toggle dashboard
function M.toggle()
  if M.is_open then
    M.close()
  else
    M.open()
  end
end

-- Open dashboard
function M.open()
  if M.is_open then
    return
  end
  
  local api = require("homeassistant").get_api()
  if not api then
    logger.error("API not initialized")
    return
  end
  
  local config = require("homeassistant.config").get()
  
  -- Create floating window with keybindings at bottom
  M.buf, M.win = floating.create_centered_float({
    width = config.ui.dashboard.width,
    height = config.ui.dashboard.height,
    border = {
      style = config.ui.dashboard.border,
      text = {
        top = " Home Assistant Dashboard ",
        bottom = " [r]refresh [d]domains [a]areas [s]status [t]tab [/]filter [Enter]expand [q]quit ",
        bottom_align = "center",
      },
    },
    filetype = "ha-dashboard",
  })
  
  M.is_open = true
  
  -- Set loading message
  floating.set_lines(M.buf, { "", "  Loading data...", "" })
  
  -- Fetch all data in parallel
  local fetch_count = 0
  local total_fetches = 4
  local function check_complete()
    fetch_count = fetch_count + 1
    if fetch_count == total_fetches then
      M._render()
    end
  end
  
  -- Fetch entities
  api:get_states(function(err, entities)
    if err then
      logger.error("Failed to fetch entities: " .. err)
      M.data.entities = {}
    else
      M.data.entities = entities or {}
    end
    check_complete()
  end)
  
  -- Fetch services
  api:get_services(function(err, services)
    if err then
      logger.error("Failed to fetch services: " .. err)
      M.data.services = {}
    else
      M.data.services = services or {}
    end
    check_complete()
  end)
  
  -- Fetch areas
  api.client.ws:get_areas(function(err, areas)
    if err then
      logger.debug("Failed to fetch areas: " .. err)
      M.data.areas = {}
    else
      M.data.areas = areas or {}
    end
    check_complete()
  end)
  
  -- Fetch entity registry
  api.client.ws:get_entity_registry(function(err, registry)
    if err then
      logger.debug("Failed to fetch entity registry: " .. err)
      M.data.entity_registry = {}
    else
      M.data.entity_registry = registry or {}
    end
    check_complete()
  end)
  
  -- Setup keymaps
  M._setup_keymaps()
  
  -- Autocommand to update state when window closes
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = M.buf,
    once = true,
    callback = function()
      M.is_open = false
      M.buf = nil
      M.win = nil
    end,
  })
end

-- Close dashboard
function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.is_open = false
  M.buf = nil
  M.win = nil
end

-- Render dashboard content
function M._render()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  
  -- Clear section line mapping
  M.section_lines = {}
  
  local lines = {}
  
  -- Simple clean header
  local entity_count = #M.data.entities
  local service_count = vim.tbl_count(M.data.services)
  
  table.insert(lines, "")
  table.insert(lines, string.format("  View: %s | Tab: %s | Filter: %s",
    M.current_view, M.current_tab, M.filter_text == "" and "none" or M.filter_text))
  table.insert(lines, string.format("  Entities: %d | Services: %d", entity_count, service_count))
  table.insert(lines, "")
  
  -- Render current tab content
  if M.current_tab == "entities" then
    M._render_entities(lines)
  else
    M._render_services(lines)
  end
  
  floating.set_lines(M.buf, lines)
end

-- Render entities view
function M._render_entities(lines)
  if M.current_view == "domains" then
    M._render_by_domains(lines)
  elseif M.current_view == "areas" then
    M._render_by_areas(lines)
  else
    M._render_by_status(lines)
  end
end

-- Render entities grouped by domain
function M._render_by_domains(lines)
  -- Group by domain
  local by_domain = {}
  for _, entity in ipairs(M.data.entities) do
    if M._matches_filter(entity) then
      local domain = entity.domain
      if not by_domain[domain] then
        by_domain[domain] = {}
      end
      table.insert(by_domain[domain], entity)
    end
  end
  
  -- Sort domains
  local sorted_domains = {}
  for domain, _ in pairs(by_domain) do
    table.insert(sorted_domains, domain)
  end
  table.sort(sorted_domains)
  
  -- Render each domain
  for _, domain in ipairs(sorted_domains) do
    local entities = by_domain[domain]
    local section_key = "domain_" .. domain
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    
    local icon = is_collapsed and "▶" or "▼"
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s %s (%d)", icon, domain:upper(), #entities))
    
    if not is_collapsed then
      for _, entity in ipairs(entities) do
        local area_name = M._get_entity_area(entity.entity_id)
        local state_icon = M._get_state_icon(entity.state)
        table.insert(lines, string.format("     %s %-30s [%-12s] %s",
          state_icon,
          entity.name:sub(1, 30),
          entity.state:sub(1, 12),
          area_name or ""))
      end
    end
  end
end

-- Render entities grouped by area
function M._render_by_areas(lines)
  -- Build area map
  local area_map = {}
  for _, area in ipairs(M.data.areas) do
    area_map[area.area_id] = area.name
  end
  
  -- Group by area
  local by_area = {}
  local unassigned = {}
  
  for _, entity in ipairs(M.data.entities) do
    if M._matches_filter(entity) then
      local area_id = M._get_entity_area_id(entity.entity_id)
      if area_id then
        local area_name = area_map[area_id] or "Unknown"
        if not by_area[area_name] then
          by_area[area_name] = {}
        end
        table.insert(by_area[area_name], entity)
      else
        table.insert(unassigned, entity)
      end
    end
  end
  
  -- Sort areas
  local sorted_areas = {}
  for area_name, _ in pairs(by_area) do
    table.insert(sorted_areas, area_name)
  end
  table.sort(sorted_areas)
  
  -- Render each area
  for _, area_name in ipairs(sorted_areas) do
    local entities = by_area[area_name]
    local section_key = "area_" .. area_name
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    
    local icon = is_collapsed and "▶" or "▼"
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s %s (%d)", icon, area_name, #entities))
    
    if not is_collapsed then
      for _, entity in ipairs(entities) do
        local state_icon = M._get_state_icon(entity.state)
        table.insert(lines, string.format("     %s %-35s [%-12s] %s",
          state_icon,
          entity.entity_id:sub(1, 35),
          entity.state:sub(1, 12),
          entity.domain:upper()))
      end
    end
  end
  
  -- Render unassigned
  if #unassigned > 0 then
    local section_key = "area_unassigned"
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    local icon = is_collapsed and "▶" or "▼"
    
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s Unassigned (%d)", icon, #unassigned))
    
    if not is_collapsed then
      for _, entity in ipairs(unassigned) do
        local state_icon = M._get_state_icon(entity.state)
        table.insert(lines, string.format("     %s %-35s [%-12s] %s",
          state_icon,
          entity.entity_id:sub(1, 35),
          entity.state:sub(1, 12),
          entity.domain:upper()))
      end
    end
  end
end

-- Render entities grouped by status
function M._render_by_status(lines)
  -- Group by status
  local on_states = {}
  local off_states = {}
  local unavailable_states = {}
  
  for _, entity in ipairs(M.data.entities) do
    if M._matches_filter(entity) then
      local state = entity.state:lower()
      if state == "unavailable" or state == "unknown" then
        table.insert(unavailable_states, entity)
      elseif state == "on" or state == "open" or state == "home" then
        table.insert(on_states, entity)
      elseif state == "off" or state == "closed" or state == "away" then
        table.insert(off_states, entity)
      else
        -- Numeric or other states
        table.insert(on_states, entity)
      end
    end
  end
  
  -- Render ON/OPEN/HOME
  if #on_states > 0 then
    local section_key = "status_on"
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    local icon = is_collapsed and "▶" or "▼"
    
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s ON/OPEN/HOME (%d)", icon, #on_states))
    
    if not is_collapsed then
      for _, entity in ipairs(on_states) do
        local area_name = M._get_entity_area(entity.entity_id)
        local state_icon = M._get_state_icon(entity.state)
        table.insert(lines, string.format("     %s %-28s %-18s %s",
          state_icon,
          entity.entity_id:sub(1, 28),
          (area_name or ""):sub(1, 18),
          entity.domain:upper()))
      end
    end
  end
  
  -- Render OFF/CLOSED/AWAY
  if #off_states > 0 then
    local section_key = "status_off"
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    local icon = is_collapsed and "▶" or "▼"
    
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s OFF/CLOSED/AWAY (%d)", icon, #off_states))
    
    if not is_collapsed then
      for _, entity in ipairs(off_states) do
        local area_name = M._get_entity_area(entity.entity_id)
        local state_icon = M._get_state_icon(entity.state)
        table.insert(lines, string.format("     %s %-28s %-18s %s",
          state_icon,
          entity.entity_id:sub(1, 28),
          (area_name or ""):sub(1, 18),
          entity.domain:upper()))
      end
    end
  end
  
  -- Render UNAVAILABLE
  if #unavailable_states > 0 then
    local section_key = "status_unavailable"
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    local icon = is_collapsed and "▶" or "▼"
    
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s UNAVAILABLE (%d)", icon, #unavailable_states))
    
    if not is_collapsed then
      for _, entity in ipairs(unavailable_states) do
        local area_name = M._get_entity_area(entity.entity_id)
        local state_icon = M._get_state_icon(entity.state)
        table.insert(lines, string.format("     %s %-28s %-18s %s",
          state_icon,
          entity.entity_id:sub(1, 28),
          (area_name or ""):sub(1, 18),
          entity.domain:upper()))
      end
    end
  end
end

-- Render services tab
function M._render_services(lines)
  -- Group services by domain
  local sorted_domains = {}
  for domain, _ in pairs(M.data.services) do
    table.insert(sorted_domains, domain)
  end
  table.sort(sorted_domains)
  
  -- Render each domain
  for _, domain in ipairs(sorted_domains) do
    local domain_services = M.data.services[domain]
    local service_count = vim.tbl_count(domain_services)
    
    local section_key = "service_" .. domain
    
    -- Default to collapsed if not set
    if M.collapsed_sections[section_key] == nil then
      M.collapsed_sections[section_key] = true
    end
    local is_collapsed = M.collapsed_sections[section_key]
    local icon = is_collapsed and "▶" or "▼"
    
    local line_num = #lines + 1
    M.section_lines[line_num] = section_key
    table.insert(lines, string.format("  %s %s (%d services)", icon, domain:upper(), service_count))
    
    if not is_collapsed then
      for service_name, service_data in pairs(domain_services) do
        local description = service_data.description or "No description"
        table.insert(lines, string.format("     • %-18s %s",
          service_name,
          description:sub(1, 45)))
      end
    end
  end
end

-- Get state icon
function M._get_state_icon(state)
  local s = state:lower()
  
  if s == "on" or s == "open" or s == "home" then
    return "●"  -- Green filled circle
  elseif s == "off" or s == "closed" or s == "away" then
    return "○"  -- Empty circle
  elseif s == "unavailable" or s == "unknown" then
    return "•"  -- Red bullet
  else
    return "•"  -- Blue bullet for numeric/other
  end
end

-- Get entity area name
function M._get_entity_area(entity_id)
  local area_id = M._get_entity_area_id(entity_id)
  if not area_id then
    return nil
  end
  
  for _, area in ipairs(M.data.areas) do
    if area.area_id == area_id then
      return area.name
    end
  end
  
  return nil
end

-- Get entity area ID from registry
function M._get_entity_area_id(entity_id)
  for _, entry in ipairs(M.data.entity_registry) do
    if entry.entity_id == entity_id then
      return entry.area_id
    end
  end
  return nil
end

-- Check if entity matches filter
function M._matches_filter(entity)
  if M.filter_text == "" then
    return true
  end
  
  local filter = M.filter_text:lower()
  local entity_id = entity.entity_id:lower()
  local name = entity.name:lower()
  local state = entity.state:lower()
  
  return entity_id:find(filter, 1, true) or 
         name:find(filter, 1, true) or 
         state:find(filter, 1, true)
end

-- Setup dashboard keymaps
function M._setup_keymaps()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  
  local opts = { noremap = true, silent = true, buffer = M.buf }
  
  -- Refresh
  vim.keymap.set("n", "r", function() M._refresh() end, opts)
  
  -- Switch views
  vim.keymap.set("n", "d", function() M._switch_view("domains") end, opts)
  vim.keymap.set("n", "a", function() M._switch_view("areas") end, opts)
  vim.keymap.set("n", "s", function() M._switch_view("status") end, opts)
  
  -- Switch tabs
  vim.keymap.set("n", "t", function() M._switch_tab() end, opts)
  
  -- Filter
  vim.keymap.set("n", "/", function() M._start_filter() end, opts)
  
  -- Toggle section collapse/expand
  vim.keymap.set("n", "<CR>", function() M._toggle_section() end, opts)
  vim.keymap.set("n", "<Space>", function() M._toggle_section() end, opts)
  
  -- Close
  vim.keymap.set("n", "q", function() M.close() end, opts)
  vim.keymap.set("n", "<Esc>", function() M.close() end, opts)
end

-- Switch view mode
function M._switch_view(view)
  M.current_view = view
  M._render()
end

-- Switch tab
function M._switch_tab()
  if M.current_tab == "entities" then
    M.current_tab = "services"
  else
    M.current_tab = "entities"
  end
  M._render()
end

-- Toggle section collapse/expand
function M._toggle_section()
  local cursor = vim.api.nvim_win_get_cursor(M.win)
  local line_num = cursor[1]
  local section_key = M.section_lines[line_num]
  
  if section_key then
    M.collapsed_sections[section_key] = not M.collapsed_sections[section_key]
    M._render()
    -- Restore cursor position
    vim.api.nvim_win_set_cursor(M.win, cursor)
  end
end

-- Start filter input
function M._start_filter()
  vim.ui.input({ prompt = "Filter: ", default = M.filter_text }, function(input)
    if input then
      M.filter_text = input
      M._render()
    end
  end)
end

-- Refresh dashboard
function M._refresh()
  M.close()
  M.open()
end

return M
