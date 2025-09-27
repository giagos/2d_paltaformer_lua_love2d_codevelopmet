---@diagnostic disable: undefined-global
-- Player module
--
-- Responsibilities:
-- - Create a Box2D dynamic body and rectangle fixture for the player
-- - Keep a simple pixel-space position (self.x/self.y) in sync with the body
-- - Draw a centered rectangle as a placeholder sprite
--
-- Units:
-- - We set love.physics.setMeter(1) in main.lua, so 1 meter = 1 pixel.
-- - Code still queries love.physics.getMeter() so it’s robust if you change it later.
--
-- Notes:
-- - Fixture has density so the body has mass; friction/restitution for contact behavior;
--   sensor=false so it collides physically; userData tag helps debug overlay color it red.
local Player = {}

function Player:load(world, x, y)
    -- Spawn position in pixels
    self.x = x or 100
    self.y = y or 0
    self.width = 16
    self.height = 16
    -- Initial desired pixel velocity (converted to physics units each frame)
    self.xVel = 0
    self.yVel = 50
    self.maxSpeed = 200
    self.acceleration = 4000
    self.friction = 3000
    self.color = {0.9, 0.3, 0.3, 1}

    local meter = love.physics.getMeter() -- pixels per meter (set to 1 in main.lua)
    self.physics = {}
    -- Create body in meters so it matches STI colliders (pixels/meter)
    self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, "dynamic")
    self.physics.body:setFixedRotation(true)
    -- Shape dimensions in meters
    self.physics.shape = love.physics.newRectangleShape(self.width / meter, self.height / meter)
    self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
    self.physics.fixture:setDensity(1)
    self.physics.fixture:setFriction(0.8)
    self.physics.fixture:setRestitution(0)
    self.physics.fixture:setSensor(false)
    self.physics.fixture:setUserData({ tag = "player" })
    -- Recompute mass properties after density change
    self.physics.body:resetMassData()
end

function Player:update(dt)
    self:syncPhysics()
end

function Player:syncPhysics(dt)
    local meter = love.physics.getMeter()
    local bx, by = self.physics.body:getPosition()
    -- Convert body center (meters) to pixels for drawing
    self.x, self.y = bx * meter, by * meter
    -- If you set pixel velocities, convert to m/s for physics
    self.physics.body:setLinearVelocity(self.xVel / meter, self.yVel / meter)

end

function Player:draw()
    -- Draw centered rectangle as placeholder player sprite
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    love.graphics.setColor(1,1,1,1)
end

return Player