-- Blink.cmp entity completion source for Home Assistant
local Source = {}

-- Constructor required by blink.cmp
function Source.new()
  return setmetatable({}, { __index = Source })
end

-- Get the API instance
local function get_api()
  return require("homeassistant").get_api()
end

-- Get source name
function Source:get_debug_name()
  return "homeassistant_entities"
end

-- Check if source should be enabled
function Source:enabled()
  return vim.bo.filetype == "yaml" or vim.bo.filetype == "python"
end

-- Get trigger characters for blink.cmp
function Source:get_trigger_characters()
  return { ".", ":" }
end

-- Get completion items
function Source:get_completions(context, callback)
  local api = get_api()
  if not api then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  
  local line = context.line or context.cursor_before_line
  
  -- Check for domain pattern (sensor., light., cover., etc.)
  -- Captures both domain and any text after the dot for filtering
  local domain_match, filter_text = line:match("([%w_]+)%.([%w_]*)$")
  
  -- Check for any word at the end of the line (domain completion)
  -- Triggers on any 3+ character word without a dot
  local word_at_end = line:match("([%w_]+)$")
  
  -- Domain completion: 3+ character word without dot
  if word_at_end and not word_at_end:match("%.") and #word_at_end >= 3 and not domain_match then
    local domain_prefix = word_at_end
    
    api:get_states(function(err, entities)
      if err then
        callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
        return
      end
      
      -- Extract unique domains
      local domains = {}
      local domain_set = {}
      
      for _, entity in ipairs(entities) do
        if not domain_set[entity.domain] then
          domain_set[entity.domain] = true
          table.insert(domains, entity.domain)
        end
      end
      
      -- Filter domains by prefix
      local items = {}
      for _, domain in ipairs(domains) do
        if domain:lower():find(domain_prefix:lower(), 1, true) then
          table.insert(items, {
            label = domain,
            kind = 14, -- Keyword kind
            detail = "Home Assistant domain",
            documentation = {
              kind = "markdown",
              value = string.format("**%s**\n\nHome Assistant domain - type `.` to see entities", domain),
            },
            insertText = domain,
          })
        end
      end
      
      callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
    end)
    return
  end
  
  -- If no domain match, skip
  if not domain_match then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  
  -- Entity completion: filter by domain and optional text
  api:get_states(function(err, entities)
    if err then
      callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
      return
    end
    
    local items = {}
    for _, entity in ipairs(entities) do
      -- Filter by domain if domain pattern was matched
      if domain_match then
        if entity.domain == domain_match then
          -- If we have filter text, also check if entity_id contains it
          if not filter_text or filter_text == "" or entity.entity_id:lower():find(filter_text:lower(), 1, true) then
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
        end
      else
        -- No domain filter, show all entities
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
    end
    
    callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
  end)
end

return Source
