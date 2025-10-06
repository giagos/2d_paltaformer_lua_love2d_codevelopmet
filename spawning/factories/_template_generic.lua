-- spawning/factories/_template_generic.lua
-- General-purpose factory template for new spawnable types.
--
-- How to use:
-- 1) Copy this file and rename it, e.g. `spawning/factories/spike.lua`.
-- 2) Implement the `create` function to construct your real entity (or keep the
--    placeholder body until you wire a proper module).
-- 3) Register the new type in `data/spawn_registry.lua` with your factory path
--    and any defaults/variants.
--
-- Factory contract:
--   create(world, x, y, obj, cfg, ctx) -> instance
--   - world: love.physics World
--   - x, y: center position in pixels (Spawner converts from Tiled object)
--   - obj: full Tiled object (name, type, properties, width/height)
--   - cfg: merged config from registry.defaults, variant preset, and obj.properties
--   - ctx: extra context (e.g., { registry, level, map }) — optional
--
-- Tips:
-- - Keep this adapter tiny: route to your entity module if you have one.
-- - Use `cfg` to receive tunables (e.g., size, sensor, restitution).
-- - The Spawner already enforces exact-variant matching from names.

---@diagnostic disable: undefined-global
local M = {}

local function tryRequire(path)
  local ok, mod = pcall(require, path)
  if ok then return mod end
  print('[Factory:template] require failed for ' .. tostring(path) .. ': ' .. tostring(mod))
  return nil
end

-- Example: adapt to an existing module if/when you add it.
-- Replace 'foo' below with your real module name (e.g., 'spike', 'enemy.slime').
local function tryExistingModule()
  return tryRequire('foo') or tryRequire('entities.foo')
end

-- Helper: build physics and fixture with common options
local function buildPlaceholderBody(world, x, y, cfg)
  cfg = cfg or {}
  local bodyType = cfg.type or 'dynamic' -- 'dynamic' | 'static' | 'kinematic'
  local body = love.physics.newBody(world, x, y, bodyType)

  local shape
  if cfg.shape == 'circle' then
    local r = cfg.r or math.max( (cfg.w or 16), (cfg.h or 16) ) * 0.5
    shape = love.physics.newCircleShape(r)
  else
    local w = cfg.w or 16
    local h = cfg.h or 16
    shape = love.physics.newRectangleShape(w, h)
  end

  local fixture = love.physics.newFixture(body, shape)
  fixture:setDensity(cfg.density or 1)
  fixture:setFriction(cfg.friction or 0.6)
  fixture:setRestitution(cfg.restitution or 0.0)
  fixture:setSensor(cfg.sensor == true)

  -- Optional collision filtering
  if cfg.categoryBits or cfg.maskBits or cfg.groupIndex then
    fixture:setFilterData(cfg.categoryBits or 1, cfg.maskBits or 65535, cfg.groupIndex or 0)
  end

  -- Tagging for debug/dispatch
  fixture:setUserData({ kind = cfg.kind or 'generic', name = cfg.name, properties = cfg })
  return { body = body, shape = shape, fixture = fixture, kind = cfg.kind or 'generic', name = cfg.name, cfg = cfg }
end

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  cfg.name = obj and obj.name or cfg.name

  -- 1) If you have a proper module, adapt to its constructor here.
  local mod = tryExistingModule()
  if mod and (mod.new or mod.create) then
    local ctor = mod.new or mod.create
    -- Example signatures you might adopt in your module:
    --   ctor(world, x, y, cfg)                        -- simple unified options
    --   ctor(world, x, y, w, h, cfg)                  -- rectangle-centric
    --   ctor(world, x, y, r, cfg)                     -- circle-centric
    -- Pick ONE and delete the others. Here we choose a unified `cfg` form.
    return ctor(world, x, y, cfg)
  end

  -- 2) Otherwise, return a functional placeholder so you can see something in-game.
  print(string.format('[Factory:template] Using placeholder for "%s"', tostring(cfg.name)))
  return buildPlaceholderBody(world, x, y, cfg)
end

return M
