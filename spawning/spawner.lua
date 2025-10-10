---@diagnostic disable: undefined-global
-- spawning/spawner.lua
-- Turns Tiled entity objects into live instances using a registry-driven approach.

local Spawner = {}

local function toCenter(obj)
  local cx = (obj.x or 0) + (obj.width or 0) / 2
  local cy = (obj.y or 0) + (obj.height or 0) / 2
  return cx, cy
end

local function startsWith(s, prefix)
  return type(s) == 'string' and s:sub(1, #prefix):lower() == prefix:lower()
end

local function deepMerge(a, b)
  local out = {}
  for k,v in pairs(a or {}) do out[k] = v end
  for k,v in pairs(b or {}) do
    if type(v) == 'table' and type(out[k]) == 'table' then
      out[k] = deepMerge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

local function loadFactory(path)
  local ok, mod = pcall(require, path)
  if not ok then
    print('[Spawner] Failed to require factory ' .. tostring(path) .. ': ' .. tostring(mod))
    return nil
  end
  return mod
end

local function resolveTypeAndVariant(obj, reg)
  local otype = obj.type and obj.type ~= '' and obj.type or nil
  local name  = obj.name or ''
  for _, rule in ipairs(reg.rules or {}) do
    local ok = true
    local when = rule.when or {}
    if when.type and when.type ~= otype then ok = false end
    if when.namePrefix and not startsWith(name, when.namePrefix) then ok = false end
    if ok then
      local t = rule.type or otype
      local variant = nil
      if rule.variant and rule.variant.fromName then
        variant = name ~= '' and name:lower() or nil
      end
      return t, variant, rule
    end
  end
  return nil, nil
end

-- Public API: spawn(world, objects, ctx)
function Spawner.spawn(world, objects, ctx)
  ctx = ctx or {}
  local reg = ctx.registry or require('data.spawn_registry')
  local results = {
    boxes = {}, balls = {}, bells = {}, statues = {}, others = {},
    all = {},
    byType = { box = {}, ball = {}, bell = {}, statue = {}, other = {} },
  }
  local hasStatue = false

  for _, obj in ipairs(objects or {}) do
    local objProps = obj.properties or {}
    local t, variant, rule = resolveTypeAndVariant(obj, reg)
    if t and reg.types[t] then
      local typeEntry = reg.types[t]
      local factory = loadFactory(typeEntry.factory)
      if factory and factory.create then
        local presetsForType = (reg.variants or {})[t] or {}
        -- Enforce strict variant matching when deriving variant from name
        if rule and rule.variant and rule.variant.fromName then
          if not (variant and presetsForType[variant]) then
            -- Unknown name, skip spawn to preserve exact-name semantics
            goto continue
          end
        end
        local preset = (variant and presetsForType[variant]) or {}
        -- Merge order: type defaults <- variant preset <- object properties
        local cfg = deepMerge(typeEntry.defaults or {}, preset or {})
        cfg = deepMerge(cfg, objProps or {})
        local cx, cy = toCenter(obj)
        local instance = factory.create(world, cx, cy, obj, cfg, ctx)
        if instance then
          -- Tag instance with a kind/type for generic loops
          if instance.kind == nil then instance.kind = t end
          if instance.type == nil then instance.type = t end
          table.insert(results.all, instance)
          results.byType[t] = results.byType[t] or {}
          table.insert(results.byType[t], instance)
          if t == 'box' then table.insert(results.boxes, instance)
          elseif t == 'ball' then table.insert(results.balls, instance)
          elseif t == 'bell' then table.insert(results.bells, instance)
          elseif t == 'statue' then
            if not hasStatue then
              table.insert(results.statues, instance)
              hasStatue = true
            end
          else table.insert(results.others, instance) end
        end
      end
    end
    ::continue::
  end

  return results
end

return Spawner
