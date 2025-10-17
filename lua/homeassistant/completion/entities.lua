-- Entity completion source for nvim-cmp
local M = {}

function M.new(api)
  local self = setmetatable({}, { __index = M })
  self.api = api
  return self
end

-- Get completion source name
function M:get_debug_name()
  return "homeassistant_entities"
end

-- Check if completion should be triggered
function M:is_available()
  -- Available in YAML and Python files
  return vim.bo.filetype == "yaml" or vim.bo.filetype == "python"
end

-- Get trigger characters
function M:get_trigger_characters()
  return { ":", "." }
end

-- Main completion function
function M:complete(params, callback)
  local line = params.context.cursor_before_line
  
  -- Check for domain pattern (sensor., light., cover., etc.)
  -- Captures both domain and any text after the dot for filtering
  local domain_match, filter_text = line:match("([%w_]+)%.([%w_]*)$")
  
  -- Check for any word at the end of the line (domain completion)
  -- Triggers on any 3+ character word without a dot
  local word_at_end = line:match("([%w_]+)$")
  
  -- Domain completion: 3+ character word without dot
  if word_at_end and not word_at_end:match("%.") and #word_at_end >= 3 and not domain_match then
    local domain_prefix = word_at_end
    
    self.api:get_states(function(err, entities)
      if err then
        callback({ items = {}, isIncomplete = false })
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
            kind = require("cmp").lsp.CompletionItemKind.Keyword,
            detail = "Home Assistant domain",
            documentation = {
              kind = "markdown",
              value = string.format("**%s**\n\nHome Assistant domain - type `.` to see entities", domain),
            },
            insertText = domain,
          })
        end
      end
      
      callback({ items = items, isIncomplete = false })
    end)
    return
  end
  
  -- If no domain match, skip
  if not domain_match then
    callback({ items = {}, isIncomplete = false })
    return
  end
  
  -- Entity completion: filter by domain and optional text
  self.api:get_states(function(err, entities)
    if err then
      callback({ items = {}, isIncomplete = false })
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
              kind = require("cmp").lsp.CompletionItemKind.Variable,
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
          kind = require("cmp").lsp.CompletionItemKind.Variable,
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
    
    callback({ items = items, isIncomplete = false })
  end)
end

return M
