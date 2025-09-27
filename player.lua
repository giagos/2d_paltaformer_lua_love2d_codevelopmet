---@diagnostic disable: undefined-global
local Player = {}

function Player:load(world, x, y)
    self.x = 100
    self.y = 0
    self.width = 16
    self.height = 16
    self.xVel = 0
    self.yVel = 100
    self.maxSpeed = 200
    self.acceleration = 4000
    self.friction = 3000
    self.color = {0.9, 0.3, 0.3, 1}

    self.physics = {}
    self.physics.body = love.physics.newBody(world, self.x, self.y, "dynamic")
    self.physics.body:setFixedRotation(true)
    self.physics.shape = love.physics.newRectangleShape(self.width, self.height)
    self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
end

function Player:update(dt)
    self:syncPhysics()
end

function Player:syncPhysics(dt)
    self.x, self.y = self.physics.body:getPosition()
    self.physics.body:setLinearVelocity(self.xVel, self.yVel)

end

function Player:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
    love.graphics.setColor(1,1,1,1)
end

return Player