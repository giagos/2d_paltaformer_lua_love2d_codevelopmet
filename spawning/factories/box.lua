-- Factory adapter for box entity

---@diagnostic disable: undefined-global
local M = {}

local function tryRequire(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print('[Factory:box] require failed for ' .. tostring(path) .. ': ' .. tostring(mod))
  return nil
end

-- Expected contract of existing box module (best-effort):
-- box.new(world, x, y, width, height, optionsTable)

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  local w = cfg.w or obj.width or 16
  local h = cfg.h or obj.height or 16
  local options = {
    type = cfg.type or 'dynamic',
    restitution = cfg.restitution,
    friction = cfg.friction,
    name = obj.name,
    properties = cfg,
  }

  local boxModule = tryRequire('box') or tryRequire('entities.box')
  if boxModule and (boxModule.new or boxModule.create) then
    local ctor = boxModule.new or boxModule.create
    return ctor(world, x, y, w, h, options)
  end

  -- Fallback: create a simple placeholder body
  print('[Factory:box] Using placeholder implementation for ' .. tostring(obj.name))
  local body = love.physics.newBody(world, x, y, 'dynamic')
  local shape = love.physics.newRectangleShape(w, h)
  local fixture = love.physics.newFixture(body, shape)
  fixture:setUserData({ kind = 'box', name = obj.name })
  return { body = body, shape = shape, fixture = fixture, kind = 'box', name = obj.name }
end

return M
