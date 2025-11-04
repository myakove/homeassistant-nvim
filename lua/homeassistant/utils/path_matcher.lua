-- Path matching utility for conditional plugin loading
local M = {}

-- Check if a file path matches any of the configured patterns
-- @param filepath: The file path to check (absolute or relative)
-- @param patterns: Array of Lua patterns to match against
-- @return: boolean indicating if path matches any pattern
function M.matches(filepath, patterns)
  if not patterns or #patterns == 0 then
    -- No patterns configured = match everything
    return true
  end

  if not filepath or filepath == "" then
    return false
  end

  -- Normalize path: convert to forward slashes for consistent matching
  local normalized = filepath:gsub("\\", "/")

  -- Check each pattern
  for _, pattern in ipairs(patterns) do
    -- First try plain text matching (for simple paths)
    -- Then try Lua pattern matching (for patterns with escapes like %-)
    if normalized:find(pattern, 1, true) or normalized:match(pattern) then
      return true
    end
    -- Also try converting Lua pattern escapes to plain text for find()
    -- e.g., "%-" -> "-" for plain text matching
    local plain_pattern = pattern:gsub("%%([%-%.%+%*%?%^%$%(%)%[%]%%])", "%1")
    if plain_pattern ~= pattern and normalized:find(plain_pattern, 1, true) then
      return true
    end
  end

  return false
end

-- Get current buffer file path
-- @return: string path or nil if buffer has no file
function M.get_current_path()
  local buf = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(buf)

  if filepath == "" then
    return nil
  end

  -- Return absolute path
  return vim.fn.fnamemodify(filepath, ":p")
end

return M
