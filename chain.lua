---@diagnostic disable: undefined-global
-- Chain module: a hanging Box2D chain made of rectangular links connected with revolute joints
-- Usage:
--   local Chain = require('chain')
--   local chain = Chain.new(world, 220, 10, 8, 16, 6, { group = -1 })
--   -- In love.update: chain:update(dt)
--   -- In love.draw (after your visual scale): chain:draw()
--
-- Notes:
-- - Assumes love.physics.setMeter(1). If you change the meter, the code adapts using getMeter().
-- - Joints are created with collideConnected=false to avoid self-collision jitter.
-- - All link fixtures use the same collision group (default -1) so links don't collide each other.
-- - You can attach things to the last link via chain:getEndBody().

local Chain = {}
Chain.__index = Chain

function Chain.new(world, anchorX, anchorY, linkCount, linkLength, linkThickness, opts)
  local self = setmetatable({}, Chain)
  self:load(world, anchorX, anchorY, linkCount, linkLength, linkThickness, opts)
  return self
end

function Chain:load(world, anchorX, anchorY, linkCount, linkLength, linkThickness, opts)
  opts = opts or {}
  self.world = world
  self.x = anchorX or 200
  self.y = anchorY or 20
  self.linkCount = math.max(1, linkCount or 8)
  self.linkLength = linkLength or 16
  self.linkThickness = linkThickness or 6
  self.color = opts.color or {0.85, 0.85, 0.9, 1}
  self.group = opts.group or -1 -- same group to disable self-collisions
  self.friction = opts.friction or 0.6
  self.restitution = opts.restitution or 0.05
  self.density = opts.density or 1
  self.anchorHitRadius = opts.anchorHitRadius or 6
  self.dragTarget = opts.dragTarget or 'start' -- 'start' | 'end' | 'both'
  self.endAnchored = opts.endAnchored or false -- if true, last link is pinned to a movable static anchor
  self.dragging = false
  self.mouseJoint = nil
  self.activeDragTarget = nil -- which end is being dragged this gesture: 'start'|'end'

  local meter = love.physics.getMeter()

  -- Create a static anchor body at the top
  self.anchor = love.physics.newBody(world, self.x / meter, self.y / meter, 'static')

  self.links = {}
  self.joints = {}

  local prevBody = self.anchor
  local half = self.linkLength / 2

  for i = 1, self.linkCount do
    local cx = self.x
    local cy = self.y + (i * self.linkLength)

    local body = love.physics.newBody(world, cx / meter, cy / meter, 'dynamic')
    body:setLinearDamping(opts.linearDamping or 0)
    body:setAngularDamping(opts.angularDamping or 0)

    -- Rectangle link oriented vertically: width = thickness, height = length
    local shape = love.physics.newRectangleShape(self.linkThickness / meter, self.linkLength / meter)
    local fix = love.physics.newFixture(body, shape)
    fix:setDensity(self.density)
    fix:setFriction(self.friction)
    fix:setRestitution(self.restitution)
    fix:setSensor(false)
    fix:setUserData({ tag = 'chain_link', index = i })
    -- Prevent link-vs-link collisions via same group index
    fix:setFilterData(1, 65535, self.group)
    body:resetMassData()

    table.insert(self.links, { body = body, shape = shape, fixture = fix })

    -- Create revolute joint between prevBody and this link at their shared point
    local jx = self.x / meter
    local jy = (self.y + ((i - 1) * self.linkLength) + half) / meter
    local joint = love.physics.newRevoluteJoint(prevBody, body, jx, jy, false)
    -- Optionally limit the joint (disabled by default)
    if opts.limit then
      joint:setLimits(-opts.limit, opts.limit)
      joint:setLimitsEnabled(true)
    end

    table.insert(self.joints, joint)
    prevBody = body
  end

  -- Optional second anchor at the end (green pin behaves like the red one)
  if self.endAnchored and #self.links > 0 then
    local meter = love.physics.getMeter()
    local half = self.linkLength / 2
    local jx = self.x / meter
    local jy = (self.y + (self.linkCount * self.linkLength) + half) / meter
    -- Create static end anchor body located at the bottom pivot of the last link
    self.endAnchor = love.physics.newBody(world, jx, jy, 'static')
    -- Join last link to end anchor
    local lastLinkBody = self.links[#self.links].body
    self.endJoint = love.physics.newRevoluteJoint(lastLinkBody, self.endAnchor, jx, jy, false)
  end
end

function Chain:getEndBody()
  if #self.links > 0 then
    return self.links[#self.links].body
  end
  return nil
end

local function toPixels(x)
  local meter = love.physics.getMeter()
  return x * meter
end

function Chain:getEndPosition()
  if self.endAnchored and self.endAnchor and not self.endAnchor:isDestroyed() then
    local ex, ey = self.endAnchor:getPosition()
    return toPixels(ex), toPixels(ey)
  else
    local endBody = self:getEndBody()
    if not endBody then return self.x, self.y end
    local ex, ey = endBody:getPosition()
    return toPixels(ex), toPixels(ey)
  end
end

-- Wake up all link bodies to ensure physics responds after anchor moves
function Chain:wakeAllLinks()
  for _, l in ipairs(self.links or {}) do
    if l.body and not l.body:isDestroyed() then
      l.body:setAwake(true)
    end
  end
end

-- Decide which end is being targeted by the mouse, respecting dragTarget mode
function Chain:pickDragTarget(mx, my)
  -- Modes: 'start', 'end', 'both'
  local mode = self.dragTarget
  if mode == 'start' then
    local dx, dy = mx - self.x, my - self.y
    if (dx*dx + dy*dy) <= (self.anchorHitRadius * self.anchorHitRadius) then
      return 'start'
    end
    return nil
  elseif mode == 'end' then
    local ex, ey = self:getEndPosition()
    local dx, dy = mx - ex, my - ey
    if (dx*dx + dy*dy) <= (self.anchorHitRadius * self.anchorHitRadius) then
      return 'end'
    end
    return nil
  else -- 'both'
    local ex, ey = self:getEndPosition()
    local dsx, dsy = mx - self.x, my - self.y
    local dex, dey = mx - ex, my - ey
    local r2 = self.anchorHitRadius * self.anchorHitRadius
    local overStart = (dsx*dsx + dsy*dsy) <= r2
    local overEnd = (dex*dex + dey*dey) <= r2
    if overStart and overEnd then
      -- choose the closer end
      if (dsx*dsx + dsy*dsy) <= (dex*dex + dey*dey) then return 'start' else return 'end' end
    elseif overStart then
      return 'start'
    elseif overEnd then
      return 'end'
    else
      return nil
    end
  end
end

function Chain:update(dt)
  -- No explicit integration needed; sync optional per-link pixel positions if desired later
end

function Chain:draw()
  love.graphics.setColor(self.color)
  for i, link in ipairs(self.links) do
    local body = link.body
    local x, y = body:getPosition()
    local a = body:getAngle()
    local meter = love.physics.getMeter()
    x, y = x * meter, y * meter

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(a)
    love.graphics.rectangle('fill', -self.linkThickness/2, -self.linkLength/2, self.linkThickness, self.linkLength)
    love.graphics.setColor(0,0,0,0.9)
    love.graphics.rectangle('line', -self.linkThickness/2, -self.linkLength/2, self.linkThickness, self.linkLength)
    love.graphics.pop()

    love.graphics.setColor(self.color)
  end

  -- Draw small pin at anchor
  love.graphics.setColor(0.9, 0.2, 0.2, 1)
  love.graphics.circle('fill', self.x, self.y, 2)
  -- Draw small pin at end if that's the draggable target (green)
  if self.dragTarget == 'end' or self.dragTarget == 'both' then
    local ex, ey = self:getEndPosition()
    love.graphics.setColor(0.2, 0.9, 0.2, 1)
    love.graphics.circle('fill', ex, ey, 2)
  end
  -- Optional larger hit area outline when hovering/dragging (simple visual cue)
  -- love.graphics.setColor(0.9, 0.2, 0.2, 0.25)
  -- love.graphics.circle('line', self.x, self.y, self.anchorHitRadius)
  love.graphics.setColor(1,1,1,1)
end

function Chain:destroy()
  for _, j in ipairs(self.joints) do
    if not j:isDestroyed() then j:destroy() end
  end
  for _, l in ipairs(self.links) do
    if l.fixture and not l.fixture:isDestroyed() then l.fixture:destroy() end
    if l.body and not l.body:isDestroyed() then l.body:destroy() end
  end
  if self.anchor and not self.anchor:isDestroyed() then self.anchor:destroy() end
  if self.endJoint and not self.endJoint:isDestroyed() then self.endJoint:destroy() end
  if self.endAnchor and not self.endAnchor:isDestroyed() then self.endAnchor:destroy() end
  self.joints = {}
  self.links = {}
end

-- Input helpers for clickable/dragging anchor
function Chain:isMouseOver(mx, my)
  if self.dragTarget == 'both' then
    local r2 = self.anchorHitRadius * self.anchorHitRadius
    local dx1, dy1 = mx - self.x, my - self.y
    if (dx1*dx1 + dy1*dy1) <= r2 then return true end
    local ex, ey = self:getEndPosition()
    local dx2, dy2 = mx - ex, my - ey
    return (dx2*dx2 + dy2*dy2) <= r2
  else
    local tx, ty = self.x, self.y
    if self.dragTarget == 'end' then
      tx, ty = self:getEndPosition()
    end
    local dx = mx - tx
    local dy = my - ty
    return (dx*dx + dy*dy) <= (self.anchorHitRadius * self.anchorHitRadius)
  end
end

function Chain:setAnchor(x, y)
  self.x, self.y = x, y
  local meter = love.physics.getMeter()
  if self.anchor and not self.anchor:isDestroyed() then
    self.anchor:setPosition(x / meter, y / meter)
  end
  -- Wake up the chain so it responds immediately after moving the static anchor
  self:wakeAllLinks()
end

function Chain:mousepressed(mx, my, button)
  if button ~= 1 then return end
  local target = self:pickDragTarget(mx, my)
  if target then
    self.dragging = true
    self.activeDragTarget = target
    if target == 'end' and not self.endAnchored then
      local endBody = self:getEndBody()
      if endBody then
        local meter = love.physics.getMeter()
        self.mouseJoint = love.physics.newMouseJoint(endBody, mx / meter, my / meter)
        local mass = endBody:getMass()
        self.mouseJoint:setMaxForce(2000 * mass)
      end
    end
  end
end

function Chain:mousereleased(mx, my, button)
  if button ~= 1 then return end
  self.dragging = false
  self.activeDragTarget = nil
  if self.mouseJoint then
    if not self.mouseJoint:isDestroyed() then self.mouseJoint:destroy() end
    self.mouseJoint = nil
  end
end

function Chain:mousemoved(mx, my, dx, dy)
  if self.dragging then
    if self.activeDragTarget == 'start' then
      self:setAnchor(mx, my)
    else
      if self.endAnchored and self.endAnchor and not self.endAnchor:isDestroyed() then
        -- Move the static end anchor directly like a handle
        local meter = love.physics.getMeter()
        self.endAnchor:setPosition(mx / meter, my / meter)
        -- Wake the chain so it reacts to the moved anchor
        self:wakeAllLinks()
      else
        if self.mouseJoint and not self.mouseJoint:isDestroyed() then
          local meter = love.physics.getMeter()
          self.mouseJoint:setTarget(mx / meter, my / meter)
        end
      end
    end
  end
end

function Chain:setEndAnchor(x, y)
  if self.endAnchored and self.endAnchor and not self.endAnchor:isDestroyed() then
    local meter = love.physics.getMeter()
    self.endAnchor:setPosition(x / meter, y / meter)
  end
end

return Chain
