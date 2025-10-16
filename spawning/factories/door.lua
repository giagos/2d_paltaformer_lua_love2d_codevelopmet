-- spawning/factories/door.lua
-- Factory adapter for door entity

---@diagnostic disable: undefined-global
local M = {}

local function tryRequire(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print('[Factory:door] require failed for ' .. tostring(path) .. ': ' .. tostring(mod))
  return nil
end

-- Expected contract of door module:
-- door.new(world, x, y, w, h, optionsTable)

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  local w = cfg.w or obj.width or 16
  local h = cfg.h or obj.height or 32
  local options = {
    name = obj.name,
    properties = cfg,
    key = cfg.key or 'e',
    unlockKey = cfg.unlockKey, -- optional
    sensor = cfg.sensor,       -- number or name (e.g., 1 or 'interactableSensor1')
    locked = cfg.locked == true,
    isOpen = cfg.isOpen == true,
    w = w, h = h,
  }

  local Door = tryRequire('door') or tryRequire('entities.door')
  if Door and (Door.new or Door.create) then
    local ctor = Door.new or Door.create
    local inst = ctor(world, x, y, w, h, options)
    if inst then
      inst.kind = inst.kind or 'door'
      inst.type = inst.type or 'door'
      inst.name = inst.name or obj.name
    end
    return inst
  end

  -- Fallback placeholder (non-physics sprite)
  print('[Factory:door] Using placeholder implementation for ' .. tostring(obj.name))
  local inst = {
    x = x, y = y, w = w, h = h, kind = 'door', name = obj.name,
    isOpen = cfg.isOpen == true, isLocked = cfg.locked == true,
    draw = function(self)
      local col = self.isLocked and {0.85,0.3,0.3,1} or (self.isOpen and {0.25,0.85,0.35,0.7} or {0.55,0.55,0.8,1})
      love.graphics.setColor(col)
      love.graphics.rectangle('fill', self.x - self.w/2, self.y - self.h/2, self.w, self.h, 2, 2)
      love.graphics.setColor(0,0,0,0.8)
      love.graphics.rectangle('line', self.x - self.w/2, self.y - self.h/2, self.w, self.h, 2, 2)
      love.graphics.setColor(1,1,1,1)
    end,
  }
  return inst
end

return M
