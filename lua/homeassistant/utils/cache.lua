-- Simple caching mechanism with TTL
local M = {}

-- Cache storage
local cache = {}

-- Cache entry structure: { data, timestamp, ttl }

-- Set cache entry
function M.set(key, value, ttl)
  cache[key] = {
    data = value,
    timestamp = os.time(),
    ttl = ttl or 300, -- Default 5 minutes
  }
end

-- Get cache entry
function M.get(key)
  local entry = cache[key]
  
  if not entry then
    return nil
  end
  
  -- Check if expired
  if os.time() - entry.timestamp > entry.ttl then
    cache[key] = nil
    return nil
  end
  
  return entry.data
end

-- Clear specific cache entry
function M.clear(key)
  cache[key] = nil
end

-- Clear all cache
function M.clear_all()
  cache = {}
end

-- Check if key exists and is valid
function M.has(key)
  return M.get(key) ~= nil
end

return M
