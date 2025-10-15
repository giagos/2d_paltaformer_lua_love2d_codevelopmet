---@diagnostic disable: undefined-global
-- camera.lua
-- Draws a non-filled rectangle that follows the player smoothly in world space.
-- The rectangle stays centered on the player with simple exponential smoothing.
-- This module has no persistent references to Map or World, so it naturally
-- survives map switches. Call Camera.update(dt, player) each frame and
-- Camera.draw(player) during world-space drawing (inside the scaled block).

local Camera = {}

-- Config
local cfg = {
  -- Size of the rectangle relative to player size (in world pixels)
  padX = 8,      -- horizontal padding around player
  padY = 8,      -- vertical padding around player
  color = {1, 0.85, 0.2, 1}, -- line color (gold-ish)
  lineWidth = 1,
  -- Smoothing factor (0..1). Higher = faster catch-up. 0.15 is fairly smooth.
  lerpAlpha = 0.15,
  -- If player teleports farther than this distance, snap to player immediately
  snapDistance = 128,
  -- Aspect and size controls
  baseHeight = 120,   -- base height in world pixels before applying scale
  minScale = 0.3,
  maxScale = 3.0,
  boxScale = 1.6,     -- externally adjustable via Camera.setBoxScale
  -- Vertical screen-space offset (in world pixels). Positive moves box down.
  offsetY = -30,
  minOffsetY = -200,
  maxOffsetY = 200,
}

-- Internal smoothed center
local sx, sy

-- Utility: exponential smoothing towards target
local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Update the smoothed center so we can draw a stable box even if the player jitters
function Camera.update(dt, player)
  if not player then return end
  local px, py = player.x or 0, player.y or 0

  -- Initialize on first update or after map switch if nil
  if sx == nil or sy == nil then
    sx, sy = px, py
    return
  end

  -- If player made a big jump (e.g., level transition teleport), snap to target
  local dx, dy = px - sx, py - sy
  if (dx * dx + dy * dy) > (cfg.snapDistance * cfg.snapDistance) then
    sx, sy = px, py
    return
  end

  -- Smooth follow
  local alpha = cfg.lerpAlpha
  sx = lerp(sx, px, alpha)
  sy = lerp(sy, py, alpha)
end

-- Draw the non-filled rectangle in world space.
-- Assumes the caller already applied world scale (Map:getScale()).
function Camera.draw(player)
  if not player then return end
  if sx == nil or sy == nil then return end

  -- Maintain rectangle aspect to match current window
  local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
  local aspect = (winW > 0 and winH > 0) and (winW / winH) or 16/9

  -- Minimum size must still encompass the player + padding
  local minW = (player.width or 16) + cfg.padX * 2
  local minH = (player.height or 16) + cfg.padY * 2

  -- Desired height from configurable scale
  local desiredH = (cfg.baseHeight or 120) * (cfg.boxScale or 1.0)
  -- Ensure height large enough to cover both minH and minW/aspect to keep aspect
  local h = math.max(desiredH, minH, minW / aspect)
  local w = h * aspect

  local x = sx - w / 2
  local y = (sy + (cfg.offsetY or 0)) - h / 2

  love.graphics.push("all")
  love.graphics.setColor(cfg.color)
  love.graphics.setLineWidth(cfg.lineWidth)
  love.graphics.rectangle("line", x, y, w, h)
  love.graphics.pop()
end

-- Optional helper to reset smoothing, e.g., if you manually want to snap now
function Camera.snapTo(player)
  if not player then return end
  sx, sy = player.x or sx, player.y or sy
end

-- Debug/menu integration: expose size controls
function Camera.getBoxScale()
  return cfg.boxScale or 1.0
end

function Camera.setBoxScale(s)
  local minS = cfg.minScale or 0.3
  local maxS = cfg.maxScale or 3.0
  if type(s) ~= 'number' then return end
  if s ~= s then return end -- NaN guard
  cfg.boxScale = math.max(minS, math.min(maxS, s))
end

function Camera.getBoxScaleLimits()
  return (cfg.minScale or 0.3), (cfg.maxScale or 3.0)
end

function Camera.getYOffset()
  return cfg.offsetY or 0
end

function Camera.setYOffset(v)
  if type(v) ~= 'number' then return end
  if v ~= v then return end -- NaN guard
  local minV = cfg.minOffsetY or -200
  local maxV = cfg.maxOffsetY or 200
  cfg.offsetY = math.max(minV, math.min(maxV, v))
end

function Camera.getYOffsetLimits()
  return (cfg.minOffsetY or -200), (cfg.maxOffsetY or 200)
end

return Camera
