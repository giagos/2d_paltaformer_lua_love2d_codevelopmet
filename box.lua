---@diagnostic disable: undefined-global
-- Box module: a Box2D rectangle body/fixture you can place as blocks
-- Usage:
--   local Box = require('box')
--   local block = Box.new(world, 200, 80, 40, 20, { type = 'static' })
--   local crate = Box.new(world, 260, 60, 24, 24, { type = 'dynamic', restitution = 0.2 })
--   -- In love.update: block:update(dt); crate:update(dt)
--   -- In love.draw (after your visual scale): block:draw(); crate:draw()

local Box = {}
Box.__index = Box

function Box.new(world, x, y, w, h, opts)
  local self = setmetatable({}, Box)
  self:load(world, x, y, w, h, opts)
  return self
end

function Box:load(world, x, y, w, h, opts)
  opts = opts or {}
  self.x = x or 100
  self.y = y or 100
  self.w = w or 16
  self.h = h or 16
  self.color = opts.color or { 0.3, 0.9, 0.4, 1 }

  local meter = love.physics.getMeter()
  local bodyType = opts.type or 'static' -- 'static' | 'dynamic' | 'kinematic'

  self.physics = self.physics or {}
  self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, bodyType)
  self.physics.shape = love.physics.newRectangleShape(self.w / meter, self.h / meter)
  self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)

  -- Physics tuning
  self.physics.fixture:setDensity(opts.density or 1)
  self.physics.fixture:setFriction(opts.friction or 0.8)
  self.physics.fixture:setRestitution(opts.restitution or 0.1)
  self.physics.fixture:setSensor(false)
  self.physics.fixture:setUserData({ tag = 'box' })
  if bodyType ~= 'static' then
    self.physics.body:resetMassData()
  end
  if opts.angularDamping then self.physics.body:setAngularDamping(opts.angularDamping) end
end

function Box:update(dt)
  local meter = love.physics.getMeter()
  local bx, by = self.physics.body:getPosition()
  self.x, self.y = bx * meter, by * meter
end

function Box:draw()
  love.graphics.push()
  love.graphics.translate(self.x, self.y)
  if self.physics and self.physics.body then
    love.graphics.rotate(self.physics.body:getAngle())
  end

  love.graphics.setColor(self.color)
  love.graphics.rectangle('fill', -self.w/2, -self.h/2, self.w, self.h)
  love.graphics.setColor(0,0,0,0.9)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', -self.w/2, -self.h/2, self.w, self.h)

  love.graphics.pop()
  love.graphics.setColor(1,1,1,1)
end

return Box
