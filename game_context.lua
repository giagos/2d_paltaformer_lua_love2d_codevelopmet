---@diagnostic disable: undefined-global
-- Simple shared context to expose current STI level and Box2D world to modules
local C = { level = nil, world = nil }

function C.setLevel(level)
  C.level = level
end

function C.getLevel()
  return C.level
end

function C.setWorld(world)
  C.world = world
end

function C.getWorld()
  return C.world
end

-- Helpers: convenient accessors for STI layers/properties
function C.getLayer(name)
  local lvl = C.level
  if not (lvl and lvl.layers) then return nil end
  -- Access by key (named layer) or linear search fallback
  if lvl.layers[name] then return lvl.layers[name] end
  for _, layer in ipairs(lvl.layers) do
    if layer and layer.name == name then return layer end
  end
  return nil
end

function C.getLayerProperties(name)
  local layer = C.getLayer(name)
  return (layer and layer.properties) or nil
end

function C.withLayerProps(name, fn)
  local props = C.getLayerProperties(name)
  if props and type(fn) == 'function' then
    return fn(props)
  end
  return nil
end

--[[
USAGE EXAMPLE: Access Tiled layer properties (e.g., solid.collidable) inside box.lua

  local GameContext = require("game_context")

  -- inside Box:load(world, x, y, w, h, opts)
  local level = GameContext and GameContext.getLevel and GameContext.getLevel() or nil
  local solidLayer = level and level.layers and level.layers.solid or nil
  local props = solidLayer and solidLayer.properties or nil

  if props and props.collidable == true then
    -- Flip a variable or change behavior based on layer properties
    self.color = opts.color or { 0.25, 0.85, 0.35, 1 } -- example tweak
  end

Shorter with helpers:

  local GameContext = require("game_context")
  local solidProps = GameContext.getLayerProperties("solid")
  if solidProps and solidProps.collidable then
    self.color = opts.color or { 0.25, 0.85, 0.35, 1 }
  end

Setup requirements:
  - Map must set the current world/level into GameContext.
    This repo already does:
      * After creating the world in Map:load -> GameContext.setWorld(state.world)
      * After loading STI in Map:init      -> GameContext.setLevel(state.level)
      * After map switches (post-init)     -> GameContext.setLevel(state.level)

Tips:
  - Add your own custom properties to any Tiled layer (e.g., solid, sensor, transitions) or object.
  - For object-level properties, pass obj.properties via constructors (recommended) or walk STI structures directly.
  - The helpers here are read-only views so modules can query without tightly coupling to Map.
]]

return C
