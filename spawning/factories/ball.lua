-- spawning/factories/ball.lua
-- Factory adapter for ball entity

---@diagnostic disable: undefined-global
local M = {}

local function tryRequire(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print('[Factory:ball] require failed for ' .. tostring(path) .. ': ' .. tostring(mod))
  return nil
end

-- Expected contract of existing ball module (best-effort):
-- ball.new(world, x, y, radius, optionsTable)

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  local r = cfg.r or (math.min(obj.width or 16, obj.height or 16) / 2)
  local options = {
    restitution = cfg.restitution,
    friction = cfg.friction,
    name = obj.name,
    properties = cfg,
  }

  local ballModule = tryRequire('ball') or tryRequire('entities.ball')
  if ballModule and (ballModule.new or ballModule.create) then
    local ctor = ballModule.new or ballModule.create
    return ctor(world, x, y, r, options)
  end

  -- Fallback: create a simple placeholder body
  print('[Factory:ball] Using placeholder implementation for ' .. tostring(obj.name))
  local body = love.physics.newBody(world, x, y, 'dynamic')
  local shape = love.physics.newCircleShape(r)
  local fixture = love.physics.newFixture(body, shape)
  fixture:setRestitution(options.restitution or 0.6)
  fixture:setUserData({ kind = 'ball', name = obj.name })
  return { body = body, shape = shape, fixture = fixture, kind = 'ball', name = obj.name }
end

return M
