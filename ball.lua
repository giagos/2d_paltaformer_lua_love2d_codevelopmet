---@diagnostic disable: undefined-global
-- Ball module: a Box2D circle body the player can collide with
-- Usage examples:
--   local Ball = require('ball')
--   local ball = Ball.new(world, 200, 100, 12, { type = 'dynamic', restitution = 0.6 })
--   -- In love.update: ball:update(dt)
--   -- In love.draw (after your visual scale): ball:draw()
--
-- Notes:
-- - Assumes love.physics.setMeter(1) (1 pixel = 1 meter). If you use a different meter,
--   the code will adapt by querying love.physics.getMeter().
-- - The fixture is non-sensor and tagged with userData { tag = 'ball' } so your debug
--   overlay can render it distinctly if desired.

local Ball = {}
Ball.__index = Ball

-- Construct and return a new Ball instance
function Ball.new(world, x, y, radius, opts)
  local self = setmetatable({}, Ball)
  self:load(world, x, y, radius, opts)
  return self
end

-- Initialize or reinitialize the ball
function Ball:load(world, x, y, radius, opts)
  opts = opts or {}
  self.x = x or 100
  self.y = y or 100
  self.radius = radius or 12
  self.color = opts.color or { 0.2, 0.6, 1.0, 1 }

  local meter = love.physics.getMeter()
  local bodyType = opts.type or 'dynamic' -- 'dynamic' | 'static' | 'kinematic'

  -- Create physics structures
  self.physics = self.physics or {}
  self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, bodyType)
  self.physics.shape = love.physics.newCircleShape(self.radius / meter)
  self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)

  -- Physics tuning
  self.physics.fixture:setDensity(opts.density or 1)
  self.physics.fixture:setFriction(opts.friction or 0.6)
  self.physics.fixture:setRestitution(opts.restitution or 0.6) -- bounciness
  self.physics.fixture:setSensor(false)
  self.physics.fixture:setUserData({ tag = 'ball' })
  self.physics.body:resetMassData()

  -- Optional initial velocity
  if opts.vx or opts.vy then
    self.physics.body:setLinearVelocity((opts.vx or 0) / meter, (opts.vy or 0) / meter)
  end
end

function Ball:update(dt)
  -- Sync pixel-space position from physics body for draw/debug
  local meter = love.physics.getMeter()
  local bx, by = self.physics.body:getPosition()
  self.x, self.y = bx * meter, by * meter
end

function Ball:applyImpulse(ix, iy)
  -- Apply an impulse in pixel-units; converts to N*s in meters
  local meter = love.physics.getMeter()
  self.physics.body:applyLinearImpulse((ix or 0) / meter, (iy or 0) / meter)
end

function Ball:setVelocity(vx, vy)
  local meter = love.physics.getMeter()
  self.physics.body:setLinearVelocity((vx or 0) / meter, (vy or 0) / meter)
end

function Ball:draw()
  love.graphics.setColor(self.color)
  love.graphics.circle('fill', self.x, self.y, self.radius)
  love.graphics.setColor(1, 1, 1, 1)
end

return Ball
