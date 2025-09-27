---@diagnostic disable: undefined-global
-- Transparent Box2D collider debug drawing
-- Purpose:
-- - Visualize all Box2D fixtures with a semi-transparent overlay.
-- - Player fixtures are colored red; map fixtures green.
-- Behavior:
-- - Does NOT change global graphics scale. Draw it after applying your visual scale
--   (we scale by `scale` in main.lua before calling this).
-- Usage:
--   local DebugDraw = require('debugdraw')
--   DebugDraw.drawWorldTransparent(world) -- call inside love.draw(), after scaling

local DebugDraw = {}

function DebugDraw.drawWorldTransparent(world)
  if not world then return end
  -- With meter=1 (pixels as meters), coords are already in pixels
  local meter = love.physics.getMeter()
  for _, body in ipairs(world:getBodies()) do
    for _, fixture in ipairs(body:getFixtures()) do
      local shape = fixture:getShape()
      local st = shape:getType()
      local ud = fixture:getUserData()
      local isPlayer = type(ud) == 'table' and ud.tag == 'player'
      if st == 'polygon' then
        local points = { body:getWorldPoints(shape:getPoints()) }
  -- no scaling needed when meter==1
        if isPlayer then love.graphics.setColor(1, 0, 0, 0.35) else love.graphics.setColor(0, 1, 0, 0.25) end
        love.graphics.polygon('fill', points)
        if isPlayer then love.graphics.setColor(1, 0.2, 0.2, 0.95) else love.graphics.setColor(0, 1, 0, 0.85) end
        love.graphics.polygon('line', points)
      elseif st == 'circle' then
        local cx, cy = body:getWorldPoints(shape:getPoint())
  local r = shape:getRadius()
        if isPlayer then love.graphics.setColor(1, 0, 0, 0.35) else love.graphics.setColor(0, 1, 0, 0.25) end
        love.graphics.circle('fill', cx, cy, r)
        if isPlayer then love.graphics.setColor(1, 0.2, 0.2, 0.95) else love.graphics.setColor(0, 1, 0, 0.85) end
        love.graphics.circle('line', cx, cy, r)
      elseif st == 'edge' then
        local x1, y1, x2, y2 = shape:getPoints()
        local wx1, wy1 = body:getWorldPoints(x1, y1)
        local wx2, wy2 = body:getWorldPoints(x2, y2)
  -- no scaling needed when meter==1
        love.graphics.setColor(1, 0.6, 0, 0.9)
        love.graphics.line(wx1, wy1, wx2, wy2)
      elseif st == 'chain' then
        local cpts = { shape:getPoints() }
        for i = 1, #cpts, 2 do
          local wx, wy = body:getWorldPoints(cpts[i], cpts[i+1])
          cpts[i], cpts[i+1] = wx, wy
        end
        love.graphics.setColor(0, 0.6, 1, 0.9)
        love.graphics.line(cpts)
      end
    end
  end
  love.graphics.setColor(1,1,1,1)
end

return DebugDraw
