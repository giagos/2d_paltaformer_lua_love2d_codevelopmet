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
    -- Interaction / state machine
    self.state = 'idle'                -- 'idle' | 'ringing_short' | 'ringing_long'
    self.isRinging = false             -- lock while animation plays
    self.inZone = false                -- set by sensor3 enter/exit
    self.inputDown = false             -- is 'E' currently held
    self.inputDownTime = 0             -- how long E has been held
    self.inputTriggeredLong = false    -- has long action fired while held
    self.longPressThreshold = 1.0      -- seconds to consider a long press

    -- When sensor3 is hit (player enters), increment bell1.state by 1
    -- Register safely even before Sensors.init by writing to _onEnter (preserved by Sensors.init)
    sensors._onEnter = sensors._onEnter or {}
    sensors._onExit = sensors._onExit or {}
    local this = self
    sensors._onEnter.sensor3 = function(name)
        this.inZone = true
    end
    sensors._onExit.sensor3 = function(name)
        this.inZone = false
        -- cancel any pending press tracking when leaving zone
        this.inputDown = false
        this.inputDownTime = 0
        this.inputTriggeredLong = false
    end
end
-- Trigger ring once and lock interaction until animation completes
function bell:_triggerRing(kind)
    if self.isRinging then return end
    self.isRinging = true
    self.state = (kind == 'long') and 'ringing_long' or 'ringing_short'
    -- reflect state in map properties (0=idle,1=short,2=long)
    local propVal = (kind == 'long') and 2 or 1
    game_context.setEntityProp("bell1", "state", propVal, { caseInsensitive = true })
    -- restart ring animation from first frame
    if animation_ring then
        animation_ring:gotoFrame(1)
        animation_ring:resume()
    end
end

function bell:update(dt)
    -- Update input edge detection for 'E' while inside sensor3 zone
    local down = love.keyboard.isDown('e')
    if self.inZone and (not self.isRinging) then
        -- key down edge
        if down and not self.inputDown then
            self.inputDown = true
            self.inputDownTime = 0
            self.inputTriggeredLong = false
        end
        -- while held: accumulate and trigger long once when threshold passed
        if self.inputDown and down then
            self.inputDownTime = self.inputDownTime + dt
            if (not self.inputTriggeredLong) and self.inputDownTime >= self.longPressThreshold then
                self.inputTriggeredLong = true
                self:_triggerRing('long')
            end
        end
        -- key release edge
        if self.inputDown and (not down) then
            if not self.inputTriggeredLong then
                -- short press
                self:_triggerRing('short')
            end
            self.inputDown = false
            self.inputDownTime = 0
            self.inputTriggeredLong = false
        end
    else
        -- Not in zone or currently ringing: ignore & reset edge tracking on release
        if not down then
            self.inputDown = false
            self.inputDownTime = 0
            self.inputTriggeredLong = false
        end
    end

    -- Advance animations
    if animation_idle then animation_idle:update(dt) end
    if animation_ring then animation_ring:update(dt) end
end

function bell:loadAssets()
   spritesheet = love.graphics.newImage('asets/sprites/bell_spritesheet.png')
   local grid = anim8.newGrid(16, 32, spritesheet:getWidth(), spritesheet:getHeight())
   animation_idle = anim8.newAnimation(grid('1-5',1), 0.3)
   -- ring plays once; when it loops, pause at end and unlock interaction
   animation_ring = anim8.newAnimation(grid('6-11',1), 0.1, function(anim)
       -- when ring completes first loop, stop at last frame and reset bell to idle
       anim:pauseAtEnd()
       -- find active instance (single-bell assumption); unlock and reset
       -- If multiple bells are added in the future, make animations instance-scoped
       for _, b in ipairs(bell._active) do
           if b.isRinging then
               b.isRinging = false
               b.state = 'idle'
               game_context.setEntityProp("bell1", "state", 0, { caseInsensitive = true })
               break
           end
       end
   end)

end

function bell:draw()
    if self.state == 'ringing_short' or self.state == 'ringing_long' or self.isRinging then
        animation_ring:draw(spritesheet, self.x, self.y, 0, 1, 1, self.w, self.h/2)
    else
        animation_idle:draw(spritesheet, self.x, self.y, 0, 1, 1, self.w, self.h/2)
    end
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