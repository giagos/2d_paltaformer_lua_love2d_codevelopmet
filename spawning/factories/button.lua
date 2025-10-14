---@diagnostic disable: undefined-global
-- spawning/factories/button.lua
-- Factory adapter for button entity

local M = {}

local function tryRequire(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print('[Factory:button] require failed for ' .. tostring(path) .. ': ' .. tostring(mod))
  return nil
end

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  local w = cfg.w or obj.width or 16
  local h = cfg.h or obj.height or 16
  local options = {
    name = obj.name,
    properties = cfg,
    key = cfg.key,
    sensor = cfg.sensor,
  }

  local Button = tryRequire('button') or tryRequire('entities.button')
  if Button and (Button.new or Button.create) then
    local ctor = Button.new or Button.create
    local inst = ctor(world, x, y, w, h, options)
    -- Tag kind/type for generic loops
    if inst then
      inst.kind = inst.kind or 'button'
      inst.type = inst.type or 'button'
    end
    return inst
  end

  -- Fallback placeholder (non-physics sprite)
  print('[Factory:button] Using placeholder implementation for ' .. tostring(obj.name))
  local inst = {
    x = x, y = y, w = w, h = h, kind = 'button', name = obj.name,
    isPressed = false,
    draw = function(self)
      local r,g,b = self.isPressed and 0.2 or 0.9, self.isPressed and 0.8 or 0.2, self.isPressed and 0.3 or 0.2
      love.graphics.setColor(r,g,b,1)
      love.graphics.rectangle('fill', self.x - self.w/2, self.y - self.h/2, self.w, self.h)
      love.graphics.setColor(0,0,0,0.9)
      love.graphics.rectangle('line', self.x - self.w/2, self.y - self.h/2, self.w, self.h)
      love.graphics.setColor(1,1,1,1)
    end
  }
  return inst
end

return M
