---@diagnostic disable: undefined-global
local Player = {}

function Player:load(world, x, y)
    -- Spawn position in pixels
    self.x = x or 100
    self.y = y or 0
    self.width = 16
    self.height = 16
    self.xVel = 0
    self.yVel = 100
    self.maxSpeed = 200
    self.acceleration = 4000
    self.friction = 3000
    self.color = {0.9, 0.3, 0.3, 1}

    local meter = love.physics.getMeter() -- pixels per meter (we set to 1 in love.load)
    self.physics = {}
    -- Create body in meters so it matches STI colliders
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
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    love.graphics.setColor(1,1,1,1)
end

return Player