---@diagnostic disable: undefined-global
-- Player module: platformer-style movement with Box2D body
-- - Uses pixel units (meter=1) to match STI colliders
-- - Handles left/right movement, friction, gravity, and jumping
-- - Detects grounding via world contact callbacks using collision normals
local Player = {}

function Player:load(world, x, y)
   -- Dimensions and spawn
   self.x = 100
   self.y = 0
   self.width = 16
   self.height = 16

   -- Kinematics and tuning
   self.xVel = 0
   self.yVel = 0
   self.maxSpeed = 200
   self.acceleration = 4000
<<<<<<< Updated upstream
   self.friction = 300
=======
   self.friction = 3400
>>>>>>> Stashed changes
   self.gravity = 1500
   self.jumpAmount = -350
   self.grounded = false

   self.color = {0.9, 0.3, 0.3, 1}

   local meter = love.physics.getMeter() -- (1 pixel per meter)
   self.physics = {}
   -- Body at center (Box2D origin at shape center)
   self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, "dynamic")
   self.physics.body:setFixedRotation(true)
   -- World gravity is enabled for balls; keep player independent by disabling world gravity influence
   if self.physics.body.setGravityScale then
      self.physics.body:setGravityScale(0)
   end
   -- Rectangle shape (full width/height)
   self.physics.shape = love.physics.newRectangleShape(self.width / meter, self.height / meter)
   self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
   self.physics.fixture:setDensity(1)
   self.physics.fixture:setFriction(0.8)
   self.physics.fixture:setRestitution(0)
   self.physics.fixture:setSensor(false)
   self.physics.fixture:setUserData({ tag = "player" })
   self.physics.body:resetMassData()
end

function Player:update(dt)
   -- Apply control + physics integration order:
   -- 1) movement/friction (horizontal), 2) gravity (vertical), 3) sync to body
   self:move(dt)
   self:applyGravity(dt)
   self:syncPhysics()
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
   if not self.grounded then
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

-- Ground detection via contact normals
function Player:beginContact(a, b, collision)
   if self.grounded then return end
   local nx, ny = collision:getNormal()
   if a == self.physics.fixture then
      if ny > 0 then self:land(collision) end
   elseif b == self.physics.fixture then
      if ny < 0 then self:land(collision) end
   end
end

function Player:endContact(a, b, collision)
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

function Player:draw()
   -- Draw centered rectangle as placeholder player sprite
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    love.graphics.setColor(1,1,1,1)
end

return Player