local sensors = require("sensor_handler")
local bell = {}
bell.__index = bell

bell._active = {}
function bell.new(world,x,y,w,h,opts)
    local self = setmetatable({},bell)
    self:load(world,x,y,w,h,opts)
    table.insert(bell._active,self)
    return self
end

function bell:load(world,x,y,w,h,opts)
    opts = opts or {}
    self.x = x or 100
    self.y = y or 100
    self.w = w or 16
    self.h = h or 32
    --gia to interaction
    local meter = love.physics.getMeter()
    local bodyType = opts.type or 'static'

    self.physics = self.physics or {}
    self.physics.body = love.physics.newBody(world, self.x / meter, self.y / meter, bodyType)
    self.physics.shape = love.physics.newRectangleShape(self.w / meter, self.h / meter)
    self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)

    self.physics.fixture:setSensor(true)
    self.physics.fixture:setUserData({tag='bell'})
end

function bell:update(dt)
    self:syncPhysics()
end

function bell:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.setColor(1,1,1,1)
    love.graphics.rectangle('fill', -self.w/2, -self.h/2, self.w, self.h)
    love.graphics.setColor(0,0,0,0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', -self.w/2, -self.h/2, self.w, self.h)

    love.graphics.pop()
    love.graphics.setColor(1,1,1,1)
    --love.graphics.rectangle('fill',self.x-self.w/2,self.y-self.h/2,self.w, self.h)
end

function bell:remove()
    for i, instance in ipairs(bell._active) do
        if instance == self then
            if self.physics and self.physics.body and (not self.physics.body:isDestroyed()) then
                self.physics.body:destroy()
            end
            bell._active[i] = bell._active[#bell._active]
            bell._active[#bell._active] = nil
        end
    end
end

function bell:removeAll()
    for _, v in ipairs(bell._active) do
        if self.physics and self.physics.body and (not self.physics.body:isDestroyed()) then
            self.physics.body:destroy()
        end
    end
    bell._active = {}
end

return bell