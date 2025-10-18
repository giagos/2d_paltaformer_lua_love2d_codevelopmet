---@diagnostic disable: undefined-global
-- Player module: platformer-style movement with Box2D body
-- - Uses pixel units (meter=1) to match STI colliders
-- - Handles left/right movement, friction, gravity, and jumping
-- - Detects grounding via world contact callbacks using collision normals
local Player = {}
local PlayerData = require('data.player_data')
local spritesheet, animation_idle, animation_walk, animation_jump, animation_fall
local drawscale = 1
local xdirection = "no"
local ydirection = "no"


local anim8 = require("anim8")

function Player:load(world, x, y)
   -- Dimensions and spawn (from data)
   self.x = PlayerData.spawn.x
   self.y = PlayerData.spawn.y
   self.width = PlayerData.size.width
   self.height = PlayerData.size.height

   -- Kinematics and tuning
   self.xVel = 0
   self.yVel = 0
   self.maxSpeed = PlayerData.movement.maxSpeed
   self.maxySpeed = PlayerData.movement.maxYSpeed
   self.acceleration = PlayerData.movement.acceleration
   self.friction = PlayerData.movement.friction
   self.gravity = PlayerData.movement.gravity
   self.jumpAmount = PlayerData.movement.jumpAmount
   self.grounded = false
   self.groundContacts = 0

   --Animations
   self:loadAssets()

   self.color = PlayerData.color

   local meter = love.physics.getMeter() -- (1 pixel per meter)
   self.physics = {}
   -- Body at center (Box2D origin at shape center)
   self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, PlayerData.physics.bodyType or 'dynamic')
   if PlayerData.physics.fixedRotation then self.physics.body:setFixedRotation(true) end
   -- World gravity is enabled for balls; keep player independent by disabling world gravity influence
   if self.physics.body.setGravityScale then
      self.physics.body:setGravityScale(PlayerData.physics.gravityScale or 0)
   end
   -- Rectangle shape (full width/height)
   self.physics.shape = love.physics.newRectangleShape(self.width / meter, self.height / meter)
   self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
   self.physics.fixture:setDensity(PlayerData.physics.density or 1)
   self.physics.fixture:setFriction(PlayerData.physics.friction or 0.8)
   self.physics.fixture:setRestitution(PlayerData.physics.restitution or 0)
   self.physics.fixture:setSensor(PlayerData.physics.sensor == true)
   self.physics.fixture:setUserData({ tag = "player" })
   self.physics.body:resetMassData()

   -- Foot sensor: a small sensor fixture at the feet that overlaps slightly into ground
   do
      local meter = love.physics.getMeter()
   local footWidth = self.width * (PlayerData.physics.foot.widthFactor or 0.8)
   local footHeight = PlayerData.physics.foot.height or 3
      -- Offset so it sits at the very bottom, extending ~1px into ground
   local oy = (self.height/2) - (footHeight/2) + (PlayerData.physics.foot.inset or 1)
      self.physics.footShape = love.physics.newRectangleShape(0, oy / meter, footWidth / meter, footHeight / meter)
      self.physics.footFixture = love.physics.newFixture(self.physics.body, self.physics.footShape)
      self.physics.footFixture:setSensor(true)
      self.physics.footFixture:setUserData({ tag = "player_foot" })
   end
end

function Player:loadAssets()
   spritesheet = love.graphics.newImage('asets/sprites/spritesheet_player_walk.png')
   local grid = anim8.newGrid(16, 16, spritesheet:getWidth(), spritesheet:getHeight())
   local A = PlayerData.animations or {}
   animation_idle = anim8.newAnimation(grid('1-2',1),  A.idleFrameTime or 0.5)
   animation_walk = anim8.newAnimation(grid('3-8',1),  A.walkFrameTime or 0.09)
   animation_jump = anim8.newAnimation(grid('9-10',1), A.jumpFrameTime or 0.1)
   animation_fall = anim8.newAnimation(grid('11-12',1),A.fallFrameTime or 0.1)

end

function Player:update(dt)
   -- Apply control + physics integration order:
   -- 1) movement/friction (horizontal), 2) gravity (vertical), 3) sync to body
   self:move(dt)
   -- Defensive: if door fixtures flipped to sensors mid-contact, our counters can desync.
   -- Recompute grounded based on live contacts so gravity isn't suppressed incorrectly.
   if self._sanityCheckGrounded then self:_sanityCheckGrounded() end
   self:applyGravity(dt)
   self:syncPhysics()
   self:setDirection()
   animation_idle:update(dt)
   animation_walk:update(dt)
   animation_jump:update(dt)
   animation_fall:update(dt)
end

function Player:syncPhysics(dt)
   local meter = love.physics.getMeter()
   -- Drive body velocity from our desired pixel velocities
   self.physics.body:setLinearVelocity(self.xVel / meter, self.yVel / meter)
   -- Read back body position for drawing
   local bx, by = self.physics.body:getPosition()
   self.x, self.y = bx * meter, by * meter
end

function Player:applyGravity(dt)
   if not self.grounded and self.yVel <= self.maxySpeed then
      self.yVel = self.yVel + self.gravity * dt
   end
end

function Player:move(dt)
   local right = love.keyboard.isDown("d", "right")
   local left  = love.keyboard.isDown("a", "left")

   -- If both directions are pressed, treat as no input (apply friction)
   if right and left then
      self:applyFriction(dt)
      return
   end

   if right then
      if self.xVel < self.maxSpeed then
         self.xVel = math.min(self.xVel + self.acceleration * dt, self.maxSpeed)
      end
   elseif left then
      if self.xVel > -self.maxSpeed then
         self.xVel = math.max(self.xVel - self.acceleration * dt, -self.maxSpeed)
      end
   else
      self:applyFriction(dt)
   end
end

function Player:applyFriction(dt)
   if self.xVel > 0 then
      self.xVel = math.max(self.xVel - self.friction * dt, 0)
   elseif self.xVel < 0 then
      self.xVel = math.min(self.xVel + self.friction * dt, 0)
   end
end

function Player:jump(key)
   if (key == "w" or key == "up" or key == "space") and self.grounded then
      self.yVel = self.jumpAmount
      self.grounded = false
   end
end

-- Optional input entry point: call from love.keypressed in main
function Player:keypressed(key)
   -- Currently only uses jump; expand here for more player-specific inputs
   self:jump(key)
end

-- Ground detection via contact normals
function Player:beginContact(a, b, collision)
   -- Foot sensor based grounding
   if self.physics and self.physics.footFixture and (a == self.physics.footFixture or b == self.physics.footFixture) then
      local other = (a == self.physics.footFixture) and b or a
      if other and not other:isSensor() then
         self.groundContacts = self.groundContacts + 1
         self.grounded = true
         self.yVel = 0
      end
      return
   end
   if self.grounded then return end
   local nx, ny = collision:getNormal()
   if a == self.physics.fixture then
      -- Ignore sensors (e.g., sensor1 triggers) for head/ground logic
      if b and b.isSensor and b:isSensor() then return end
      if ny > 0 then 
         self:land(collision) 
      elseif ny < 0 then
         self.yVel = 0
      end
   elseif b == self.physics.fixture then
      -- Ignore sensors (e.g., sensor1 triggers) for head/ground logic
      if a and a.isSensor and a:isSensor() then return end
      if ny < 0 then 
         self:land(collision)
      elseif ny > 0 then
         self.yVel = 0
      end
   end
end

function Player:endContact(a, b, collision)
   -- Foot sensor unground when all contacts end
   if self.physics and self.physics.footFixture and (a == self.physics.footFixture or b == self.physics.footFixture) then
      local other = (a == self.physics.footFixture) and b or a
      -- Always decrement on foot endContact. The other fixture may have become a sensor mid-contact
      -- (e.g., a door opening), which would otherwise skip this block and leave the player grounded.
      self.groundContacts = math.max(0, self.groundContacts - 1)
      if self.groundContacts == 0 then
         self.grounded = false
      end
      return
   end
   if a == self.physics.fixture or b == self.physics.fixture then
      if self.currentGroundCollision == collision then
         self.grounded = false
      end
   end
end

function Player:land(collision)
   self.currentGroundCollision = collision
   self.yVel = 0
   self.grounded = true
end

function Player:setDirection()
   if self.xVel == 0 and self.yVel == 0 then
      xdirection = "no"
      ydirection = "no"
   end
   if self.xVel > 0 then 
      xdirection = "right"
      drawscale = 1
   elseif self.xVel < 0 then
      xdirection = "left"
      drawscale = -1
   end
   if self.yVel < -50 and self.grounded == false then
      ydirection = "up"
   elseif self.yVel > 50 and self.grounded == false then
      ydirection = "down"
   else
      ydirection = "no"
   end
end

-- Recompute grounded state from active Box2D contacts on the player's body.
-- This guards against edge cases where fixtures change sensor state mid-contact (e.g., opening doors)
-- and the expected endContact event doesn't properly clear our counters.
function Player:_sanityCheckGrounded()
   if not (self.physics and self.physics.body and self.physics.footFixture) then return end
   local contacts = self.physics.body:getContactList()
   local hasSupport = false
   for i = 1, #contacts do
      local c = contacts[i]
      if c and c:isTouching() then
         local fa, fb = c:getFixtures()
         if fa == self.physics.footFixture or fb == self.physics.footFixture then
            local other = (fa == self.physics.footFixture) and fb or fa
            if other and (not other:isSensor()) then
               hasSupport = true
               break
            end
         end
      end
   end
   if hasSupport then
      -- Ensure grounded flag aligns; leave groundContacts as-is (it will self-correct via callbacks)
      self.grounded = true
   else
      -- No solid contact under foot: clear grounded to allow gravity
      self.grounded = false
      self.groundContacts = 0
   end
end

function Player:draw()
   -- Draw centered rectangle as placeholder player sprite
   --love.graphics.setColor(self.color)
   --love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
   --love.graphics.setColor(1,1,1,1)
   if xdirection=="no" and ydirection=="no" then
      animation_idle:draw(spritesheet, self.x, self.y, 0, drawscale, 1, self.width, self.height/2) 
   end
   if self.grounded == true then 
      if xdirection == "right" or xdirection == "left" then
         animation_walk:draw(spritesheet, self.x, self.y, 0, drawscale, 1, self.width, self.height/2)
      end
   end
   if ydirection == "up" and self.grounded == false then
      animation_jump:draw(spritesheet, self.x, self.y, 0, drawscale, 1, self.width, self.height/2)
   elseif ydirection == "down" and self.grounded == false then
      animation_fall:draw(spritesheet, self.x, self.y, 0, drawscale, 1, self.width, self.height/2)
   elseif ydirection == "no" and self.grounded == false then
      animation_idle:draw(spritesheet, self.x, self.y, 0, drawscale, 1, self.width, self.height/2)
   end
end

return Player