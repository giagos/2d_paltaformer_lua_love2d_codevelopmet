---@diagnostic disable: undefined-global
--- Foo: a generic, well-documented object template for Love2D + Box2D (love.physics)
---
--- Overview
--- - Copy this file to quickly create new object types (Stone, Spike, Coin variants, etc.).
--- - Mirrors the structure used in this repo (see `box.lua` and `ball.lua`), but adds a small
---   registry so you can batch-update/draw/remove instances like in the examples.
--- - Uses pixel units consistently. We rely on `love.physics.setMeter(1)` so 1 pixel = 1 meter.
---   If you change the meter, Foo converts appropriately using `love.physics.getMeter()`.
---
--- Key ideas
--- - Rendering: image-centered draw if `opts.image` is provided; otherwise a primitive (rect/circle).
--- - Physics: fixture userData includes `{ kind = 'foo', name = opts.name }` for debug/contact logic and spawner integration.
--- - Lifecycle: `Foo.updateAll`, `Foo.drawAll`, `Foo.removeAll`, plus `instance:remove()`.
--- - Contacts: module-level dispatchers call per-instance `beginContact`/`endContact` if present.
---
--- Usage snippets
---   local Foo = require('foo')
---   -- Static trigger rectangle (like a pickup):
---   local coin = Foo.new(world, { x=200, y=80, shape='rect', w=12, h=12, type='static', sensor=true, image='assets/coin.png', tag='coin' })
---
---   -- Dynamic circle (like a small bouncy ball):
---   local ball = Foo.new(world, { x=140, y=60, shape='circle', r=8, type='dynamic', restitution=0.7, color={0.3,0.7,1,1}, tag='ball' })
---
---   -- In love.update: Foo.updateAll(dt)
---   -- In love.draw (inside your scaled world draw): Foo.drawAll()
---   -- In world callbacks: Foo.beginContact(a,b,c); Foo.endContact(a,b,c)
---
--- Options (opts table)
---   x, y            number : position in pixels (default 100,100)
---   shape           string : 'rect' | 'circle' (default 'rect')
---   w, h            number : rectangle size in pixels (default 16,16)
---   r               number : circle radius in pixels (default 8)
---   type            string : 'static' | 'dynamic' | 'kinematic' (default 'static')
---   sensor          boolean: fixture is sensor (no collision) (default false)
---   density         number : fixture density (default 1)
---   friction        number : fixture friction (default 0.6)
---   restitution     number : fixture bounciness (default 0)
---   angularDamping  number : optional body angular damping
---   linearDamping   number : optional body linear damping
---   vx, vy          number : initial linear velocity in px/s (optional)
---   tag             string : stored in fixture userData for identification (default 'foo')
---   image           string : path to image to draw centered; if nil, draws primitives
---   color           table  : {r,g,b,a} used for primitive draw (default {0.8,0.85,0.9,1})
---
--- Extending behavior
--- - When you copy this template, you can add per-instance methods like `spin(dt)` or
---   `beginContact(a,b,c)` and they will be honored (contact dispatchers call them automatically).

local Foo = {}
Foo.__index = Foo

-- Registry of live Foo instances
local ActiveFoos = {}

-- Helper: shallow copy of a table (for options)
local function shcopy(t)
  local r = {}
  if t then for k,v in pairs(t) do r[k] = v end end
  return r
end

-- Constructor (factory)
-- Supports two call styles for convenience:
--   Foo.new(world, { x=..., y=..., ... })
--   Foo.new(world, x, y, { ...opts })
function Foo.new(world, a, b, c)
  local self = setmetatable({}, Foo)
  local opts
  if type(a) == 'table' then
    opts = a
  else
    opts = c or {}
    opts.x = a or opts.x
    opts.y = b or opts.y
  end
  self:load(world, opts)
  table.insert(ActiveFoos, self)
  return self
end

--- Initialize (or reinitialize) fields and physics
function Foo:load(world, opts)
  opts = shcopy(opts)
  self.x = opts.x or 100
  self.y = opts.y or 100
  self.shape = opts.shape or 'rect'
  self.w = opts.w or 16
  self.h = opts.h or 16
  self.radius = opts.r or 8
  self.kind = opts.kind or 'foo'
  self.name = opts.name
  self.properties = opts.properties or {}
  self.color = opts.color or {0.8, 0.85, 0.9, 1}

  -- Optional image; if provided and shape is 'rect', width/height default to image size
  if opts.image then
    self.img = love.graphics.newImage(opts.image)
    -- If no explicit size for rect, derive from image
    if self.shape == 'rect' then
      self.w = opts.w or self.img:getWidth()
      self.h = opts.h or self.img:getHeight()
    elseif self.shape == 'circle' then
      -- if circle with image, keep radius from opts or default; image is decorative
    end
  end

  local meter = love.physics.getMeter()
  local bodyType = opts.type or 'static'

  self.physics = self.physics or {}
  self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, bodyType)

  if self.shape == 'circle' then
    self.physics.shape = love.physics.newCircleShape((opts.r or self.radius) / meter)
  else -- 'rect'
    self.physics.shape = love.physics.newRectangleShape((opts.w or self.w) / meter, (opts.h or self.h) / meter)
  end

  self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
  self.physics.fixture:setDensity(opts.density or 1)
  self.physics.fixture:setFriction(opts.friction or 0.6)
  self.physics.fixture:setRestitution(opts.restitution or 0)
  self.physics.fixture:setSensor(opts.sensor == true)
  self.physics.fixture:setUserData({ kind = self.kind, name = self.name, properties = self.properties })
  if bodyType ~= 'static' then
    self.physics.body:resetMassData()
  end
  if opts.angularDamping then self.physics.body:setAngularDamping(opts.angularDamping) end
  if opts.linearDamping then self.physics.body:setLinearDamping(opts.linearDamping) end

  -- Allow override of initial velocity in pixels/sec (converted to m/s under the hood)
  if opts.vx or opts.vy then
    self.physics.body:setLinearVelocity((opts.vx or 0) / meter, (opts.vy or 0) / meter)
  end
end

--- Instance removal: destroys the Box2D body and removes from registry
function Foo:remove()
  for i,inst in ipairs(ActiveFoos) do
    if inst == self then
      if self.physics and self.physics.body and not self.physics.body:isDestroyed() then
        self.physics.body:destroy()
      end
      table.remove(ActiveFoos, i)
      break
    end
  end
end

--- Remove all instances (destroys physics bodies and clears registry)
function Foo.removeAll()
  for _,inst in ipairs(ActiveFoos) do
    if inst.physics and inst.physics.body and not inst.physics.body:isDestroyed() then
      inst.physics.body:destroy()
    end
  end
  ActiveFoos = {}
end

--- Per-frame update (sync pos/angle from physics) and a hook area for behaviors
function Foo:update(dt)
  local meter = love.physics.getMeter()
  local bx, by = self.physics.body:getPosition()
  self.x, self.y = bx * meter, by * meter
  self.angle = self.physics.body:getAngle()
  -- Optional custom behavior per class copy can be added below
  -- e.g., self:spin(dt) or self:animate(dt)
end

--- Draw this instance (image if available, else primitive). Image is drawn centered.
function Foo:draw()
  if self.img then
    love.graphics.draw(self.img, self.x, self.y, self.angle or 0, 1, 1,
      (self.img:getWidth() / 2), (self.img:getHeight() / 2))
  else
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle or 0)
    love.graphics.setColor(self.color)
    if self.shape == 'circle' then
      love.graphics.circle('fill', 0, 0, self.radius)
      love.graphics.setColor(0,0,0,0.9)
      love.graphics.circle('line', 0, 0, self.radius)
    else
      love.graphics.rectangle('fill', -self.w/2, -self.h/2, self.w, self.h)
      love.graphics.setColor(0,0,0,0.9)
      love.graphics.rectangle('line', -self.w/2, -self.h/2, self.w, self.h)
    end
    love.graphics.pop()
    love.graphics.setColor(1,1,1,1)
  end
end

--- Batch helpers: update and draw every active instance
function Foo.updateAll(dt)
  for _,inst in ipairs(ActiveFoos) do inst:update(dt) end
end

function Foo.drawAll()
  for _,inst in ipairs(ActiveFoos) do inst:draw() end
end

--- Optional: contact dispatchers
--- Call these from love.physics world callbacks so individual Foo instances can react.
--- Each instance may optionally implement:
---   function FooInstance:beginContact(a, b, collision) ... end
---   function FooInstance:endContact(a, b, collision) ... end
function Foo.beginContact(a, b, collision)
  for _,inst in ipairs(ActiveFoos) do
    if inst.physics and inst.physics.fixture then
      if a == inst.physics.fixture or b == inst.physics.fixture then
        if inst.beginContact then inst:beginContact(a, b, collision) end
      end
    end
  end
end

function Foo.endContact(a, b, collision)
  for _,inst in ipairs(ActiveFoos) do
    if inst.physics and inst.physics.fixture then
      if a == inst.physics.fixture or b == inst.physics.fixture then
        if inst.endContact then inst:endContact(a, b, collision) end
      end
    end
  end
end

return Foo
