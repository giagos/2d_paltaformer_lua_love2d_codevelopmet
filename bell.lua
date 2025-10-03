---@diagnostic disable: undefined-global
local sensors = require("sensor_handler")
local game_context = require("game_context")

local anim8 = require("anim8")
local spritesheet, animation_idle, animation_ring

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

    --Animations
    self:loadAssets()

    -- When sensor3 is hit (player enters), increment bell1.state by 1
    -- Register safely even before Sensors.init by writing to _onEnter (preserved by Sensors.init)
    sensors._onEnter = sensors._onEnter or {}
    local prev = sensors._onEnter.sensor3
    sensors._onEnter.sensor3 = function(name)
        if prev then prev(name) end
        local v = game_context.incrEntityProp("bell1", "state", 1, { caseInsensitive = true })
        if v ~= nil then
            print(string.format("[bell] sensor3 ENTER -> bell1.state=%s", tostring(v)))
        end
    end
end

function bell:update(dt)
    self:syncPhysics()
end

function bell:loadAssets()
   spritesheet = love.graphics.newImage('asets/sprites/bell_spritesheet.png')
   local grid = anim8.newGrid(16, 32, spritesheet:getWidth(), spritesheet:getHeight())
   animation_idle = anim8.newAnimation(grid('1-5',1), 0.09)
   animation_ring = anim8.newAnimation(grid('6-11',1), 0.1)

end

function bell:draw()
   animation_idle:draw(spritesheet, self.x, self.y, 0, 1, 1, self.w, self.h/2)
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