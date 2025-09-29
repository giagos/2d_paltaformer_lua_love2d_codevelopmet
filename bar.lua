---@diagnostic disable: undefined-global
-- bar.lua — Minimal template for Love2D + Box2D objects
--
-- Intent
-- - Keep ONLY the essential structure every object uses.
-- - No physics properties (density, friction, sensors, filters) are set here.
-- - You copy this file when starting a new object and fill in specifics later.
--
-- What you get
-- - new/load: create instance and minimal physics (a small rectangle body)
-- - update/syncPhysics: pull pixel position/angle from Box2D
-- - draw: draw a simple rectangle centered on the body
-- - remove/removeAll: cleanup helpers
-- - updateAll/drawAll: batch helpers
-- - beginContact/endContact: optional routing to instance handlers if you add them

local Bar = {}
Bar.__index = Bar

-- Registry of live Bar instances
local ActiveBars = {}

-- Create and register a new instance
function Bar.new(world, x, y)
  local self = setmetatable({}, Bar)
  self:load(world, x, y)
  table.insert(ActiveBars, self)
  return self
end

-- Minimal init: stores position and creates a basic static rectangle fixture
function Bar:load(world, x, y)
  -- Pixel-space fields used by draw/debug
  self.x = x or 100
  self.y = y or 100
  self.w = 16   -- default visual width (px)
  self.h = 16   -- default visual height (px)

  -- Create Box2D body + fixture (no extra properties set here)
  local meter = love.physics.getMeter()
  self.physics = {}
  self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, 'static')
  self.physics.shape = love.physics.newRectangleShape(self.w / meter, self.h / meter)
  self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
end

-- Per-frame update: keep pixel coords in sync with body
function Bar:update(dt)
  self:syncPhysics()
end

-- Pulls x/y/angle from Box2D into pixel space
function Bar:syncPhysics()
  local meter = love.physics.getMeter()
  local bx, by = self.physics.body:getPosition()
  self.x, self.y = bx * meter, by * meter
  self.r = self.physics.body:getAngle() or 0
end

-- Minimal draw: centered rectangle following body angle
function Bar:draw()
  love.graphics.push()
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r or 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle('fill', -self.w/2, -self.h/2, self.w, self.h)
  love.graphics.setColor(0,0,0,0.9)
  love.graphics.rectangle('line', -self.w/2, -self.h/2, self.w, self.h)
  love.graphics.pop()
  love.graphics.setColor(1,1,1,1)
end

-- Remove just this instance
function Bar:remove()
  for i,inst in ipairs(ActiveBars) do
    if inst == self then
      if self.physics and self.physics.body and not self.physics.body:isDestroyed() then
        self.physics.body:destroy()
      end
      table.remove(ActiveBars, i)
      break
    end
  end
end

-- Destroy all and clear registry
function Bar.removeAll()
  for _,inst in ipairs(ActiveBars) do
    if inst.physics and inst.physics.body and not inst.physics.body:isDestroyed() then
      inst.physics.body:destroy()
    end
  end
  ActiveBars = {}
end

-- Batch helpers
function Bar.updateAll(dt)
  for _,inst in ipairs(ActiveBars) do inst:update(dt) end
end

function Bar.drawAll()
  for _,inst in ipairs(ActiveBars) do inst:draw() end
end

-- Optional: world contact routing (only calls instance handlers if you add them)
function Bar.beginContact(a, b, collision)
  for _,inst in ipairs(ActiveBars) do
    local f = inst.physics and inst.physics.fixture
    if f and (a == f or b == f) then
      if inst.beginContact then inst:beginContact(a, b, collision) end
    end
  end
end

function Bar.endContact(a, b, collision)
  for _,inst in ipairs(ActiveBars) do
    local f = inst.physics and inst.physics.fixture
    if f and (a == f or b == f) then
      if inst.endContact then inst:endContact(a, b, collision) end
    end
  end
end

return Bar
