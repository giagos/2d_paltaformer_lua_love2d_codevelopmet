-- spawning/factories/bell.lua
-- Factory adapter for bell entity

---@diagnostic disable: undefined-global
local M = {}

local function tryRequire(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print('[Factory:bell] require failed for ' .. tostring(path) .. ': ' .. tostring(mod))
  return nil
end

-- Expected contract of existing bell module (best-effort):
-- bell.new(world, x, y, optionsTable)

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  local options = {
    w = cfg.w or obj.width,
    h = cfg.h or obj.height,
    name = obj.name,
    properties = cfg,
  }

  local bellModule = tryRequire('bell') or tryRequire('entities.bell')
  if bellModule and (bellModule.new or bellModule.create) then
    local ctor = bellModule.new or bellModule.create
    -- Prefer signature (world, x, y, w, h, opts) if provided by project
    return ctor(world, x, y, options.w, options.h, options)
  end

  -- Fallback: simple placeholder that can be drawn or interacted with minimally
  print('[Factory:bell] Using placeholder implementation for ' .. tostring(obj.name))
  local body = love.physics.newBody(world, x, y, 'static')
  local shape = love.physics.newRectangleShape(options.w or 16, options.h or 16)
  local fixture = love.physics.newFixture(body, shape)
  fixture:setSensor(true)
  fixture:setUserData({ kind = 'bell', name = obj.name })
  return { body = body, shape = shape, fixture = fixture, kind = 'bell', name = obj.name }
end

return M
