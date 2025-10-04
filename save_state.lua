---@diagnostic disable: undefined-global
---
--- Overview
--- - Do NOT modify Tiled-exported map files at runtime. This module stores changes in a
---   separate overlay and reapplies them after a map loads.
--- - Intended for values like: puzzle flags (isSolved), opened chests, switches, etc.
--- - Data layout: data[mapId][entityName][prop] = value
--- - Map ID is a stable string you pick (here we use the base path, e.g., 'tiled/map/1').
--- - Persistence format: a Lua table file in LÖVE's save directory (identity from conf.lua).
---
--- Quickstart
---   -- main.lua
---   local SaveState = require('save_state')
---   function love.load()
---     SaveState.init('save/slot1.lua')
---     Map:load(2)
---     SaveState.setCurrentMapId(Map:getCurrentLevel())
---     SaveState.applyToMapCurrent()
---   end
---
---   -- After a puzzle completes (e.g., in bell.lua)
---   SaveState.setEntityPropCurrent('bell1', 'isSolved', true)
---   SaveState.save()
---
--- Integration points
--- - Call applyToMapCurrent() after each map is constructed and GameContext points to it.
--- - On level transitions, update currentMapId and call applyToMapCurrent() again.
--- - Choose when to save: immediately on changes, on map switch, or in love.quit.

local SaveState = {
  path = 'save/slot1.lua',
  data = {},
  currentMapId = nil,
  persistent = false, -- default to session-only (no disk IO)
}

-- Serialize a Lua table to a deterministic Lua source string: return { ... }
-- Convert a Lua value to Lua source text. Supports nil/number/boolean/string/table.
-- Produces deterministic ordering for stable diffs.
local function serialize(value, indent)
  indent = indent or 0
  local t = type(value)
  if t == 'nil' then return 'nil'
  elseif t == 'number' or t == 'boolean' then return tostring(value)
  elseif t == 'string' then return string.format('%q', value)
  elseif t == 'table' then
    local pieces = {}
    local keys = {}
    for k in pairs(value) do table.insert(keys, k) end
    table.sort(keys, function(a,b)
      local ta, tb = type(a), type(b)
      if ta == tb and (ta == 'number' or ta == 'string') then return a < b end
      return tostring(a) < tostring(b)
    end)
    local pad = string.rep('  ', indent)
    local pad2 = string.rep('  ', indent+1)
    table.insert(pieces, '{')
    local first = true
    for _, k in ipairs(keys) do
      local v = value[k]
      if not first then table.insert(pieces, ',') end
      first = false
      local keyRepr
      if type(k) == 'string' and k:match('^[_%a][_%w]*$') then
        keyRepr = k .. ' = '
      else
        keyRepr = '[' .. serialize(k, indent+1) .. '] = '
      end
      table.insert(pieces, '\n' .. pad2 .. keyRepr .. serialize(v, indent+1))
    end
    if not first then table.insert(pieces, '\n' .. pad) end
    table.insert(pieces, '}')
    return table.concat(pieces)
  else
    error('Cannot serialize type: ' .. t)
  end
end

--- Initialize the save system and load from disk if present.
-- @param path string: relative path under LÖVE save dir (e.g., 'save/slot1.lua')
function SaveState.init(path)
  if path and path ~= '' then SaveState.path = path end
  if SaveState.persistent then
    -- Ensure directory exists
    local dir = SaveState.path:match('^(.*)/[^/]+$') or SaveState.path:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' then love.filesystem.createDirectory(dir) end
    SaveState.load()
  else
    -- Ephemeral session: start clean each run
    SaveState.data = {}
  end
end

--- Load overlay table from disk into memory.
-- @return boolean ok: true if loaded an existing file
function SaveState.load()
  if not SaveState.persistent then return false end
  if love.filesystem.getInfo(SaveState.path) then
    local okLoad, chunkOrErr = pcall(love.filesystem.load, SaveState.path)
    if okLoad and chunkOrErr then
      local okRun, res = pcall(chunkOrErr)
      if okRun and type(res) == 'table' then
        SaveState.data = res
        return true
      end
    end
  end
  SaveState.data = {}
  return false
end

--- Save current overlay to disk.
-- @return boolean|string, string|nil: ok or error message per love.filesystem.write
function SaveState.save()
  if not SaveState.persistent then return true end
  local content = 'return ' .. serialize(SaveState.data) .. '\n'
  return love.filesystem.write(SaveState.path, content)
end

--- Clear all in-memory data. Does not delete the file until next save.
function SaveState.reset()
  SaveState.data = {}
end

--- Set the current map id used by setEntityPropCurrent/applyToMapCurrent.
-- @param id string: stable identifier (e.g., 'tiled/map/1' or a custom Tiled property)
function SaveState.setCurrentMapId(id)
  SaveState.currentMapId = id
  return id
end

--- Get the current map id.
function SaveState.getCurrentMapId()
  return SaveState.currentMapId
end

--- Get saved props for an entity on a map.
-- @return table|nil props
function SaveState.get(mapId, entityName)
  local m = SaveState.data[mapId]
  return m and m[entityName] or nil
end

--- Set a property for an entity on a given map.
-- @return any the stored value
function SaveState.setEntityProp(mapId, entityName, key, value)
  if not mapId or not entityName or not key then return nil end
  SaveState.data[mapId] = SaveState.data[mapId] or {}
  SaveState.data[mapId][entityName] = SaveState.data[mapId][entityName] or {}
  SaveState.data[mapId][entityName][key] = value
  return value
end

--- Set a property for an entity on the current map.
-- @return any the stored value
function SaveState.setEntityPropCurrent(entityName, key, value)
  assert(SaveState.currentMapId, 'SaveState: currentMapId not set before calling setEntityPropCurrent')
  return SaveState.setEntityProp(SaveState.currentMapId, entityName, key, value)
end

-- Apply saved overrides to the live STI level via GameContext
--- Apply saved overrides to the live STI level via GameContext.
-- Must be called after GameContext.setLevel(level).
function SaveState.applyToMap(mapId)
  if not mapId then return end
  local entries = SaveState.data[mapId]
  if not entries then return end
  local GameContext = require('game_context')
  for entityName, props in pairs(entries) do
    if type(props) == 'table' then
      for k, v in pairs(props) do
        GameContext.setEntityProp(entityName, k, v)
      end
    end
  end
end

--- Convenience: apply overrides for the current map id.
function SaveState.applyToMapCurrent()
  if SaveState.currentMapId then SaveState.applyToMap(SaveState.currentMapId) end
end

--- Enable/disable disk persistence. When disabled (default), data lives only in memory.
-- @param flag boolean
function SaveState.setPersistent(flag)
  SaveState.persistent = flag and true or false
end

return SaveState
