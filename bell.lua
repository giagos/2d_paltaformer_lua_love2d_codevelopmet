---@diagnostic disable: undefined-global
local sensors = require("sensor_handler")
local game_context = require("game_context")

local anim8 = require("anim8")
local Audio = require("audio")
local SaveState = require("save_state")
local spritesheet, animation_idle, animation_ring_short, animation_ring_long

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

    -- Code sequence logic (L/S) and progress pointer
    self.codeSeq = {}
    self.seqIndex = 1
    self.solved = false

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

    -- Load code and initial solved state from bell1 custom properties
    self:_loadCodeFromProps()
end

-- Read bell1 properties 'code' (string of L/S) and 'isSolved' (boolean)
function bell:_loadCodeFromProps()
    local props = game_context.getEntityObjectProperties("bell1")
    local codeStr = props and props.code
    self.codeSeq = {}
    if type(codeStr) == 'string' then
        for ch in codeStr:gmatch('.') do
            local c = ch:upper()
            if c == 'L' or c == 'S' then table.insert(self.codeSeq, c) end
        end
    end
    -- If no code provided, consider solved (or keep false if you prefer requiring at least one input)
    self.solved = (props and props.isSolved == true) or (#self.codeSeq == 0)
    self.seqIndex = 1
end
-- Trigger ring once and lock interaction until animation completes
function bell:_triggerRing(kind)
    if self.isRinging then return end
    if self.solved then return end
    self.isRinging = true
    self.state = (kind == 'long') and 'ringing_long' or 'ringing_short'

    -- Check sequence progress (L/S) and update pointer/solved
    self:_checkSequence(kind)
    -- restart appropriate ring animation from first frame
    if kind == 'long' then
        if animation_ring_long then
            animation_ring_long:gotoFrame(1)
            animation_ring_long:resume()
        end
    else
        if animation_ring_short then
            animation_ring_short:gotoFrame(1)
            animation_ring_short:resume()
        end
    end
    -- Play sound once at trigger time via centralized audio
    if Audio and Audio.play then
        if kind == 'long' then
            Audio.play('bell_ring_long', { restart = true })
        else
            Audio.play('bell_ring', { restart = true })
        end
    end
end

-- Compare the pressed kind ('long'|'short') against expected step and advance/reset pointer
function bell:_checkSequence(kind)
    local expected = self.codeSeq[self.seqIndex]
    if not expected then return end
    local actual = (kind == 'long') and 'L' or 'S'
    if actual == expected then
        self.seqIndex = self.seqIndex + 1
        if self.seqIndex > #self.codeSeq then
            -- Completed the sequence
            self.solved = true
            game_context.setEntityProp("bell1", "isSolved", true, { caseInsensitive = true })
            -- Persist to save overlay so original map files remain untouched
            SaveState.setEntityPropCurrent("bell1", "isSolved", true)
            -- Session-only by default; call SaveState.save() only when persistence is enabled
            if SaveState.persistent then SaveState.save() end
        end
    else
        -- Wrong input: reset pointer
        self.seqIndex = 1
    end
end

function bell:update(dt)
    -- Update input edge detection for 'E' while inside sensor3 zone
    local down = love.keyboard.isDown('e')
    if self.inZone and (not self.isRinging) and (not self.solved) then
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

    -- Advance only the active animation to avoid unnecessary ticking
    if self.isRinging or self.state == 'ringing_short' or self.state == 'ringing_long' then
        if self.state == 'ringing_long' then
            if animation_ring_long then animation_ring_long:update(dt) end
            if animation_idle then animation_idle:pause() end
            if animation_ring_short then animation_ring_short:pause() end
        else -- ringing short
            if animation_ring_short then animation_ring_short:update(dt) end
            if animation_idle then animation_idle:pause() end
            if animation_ring_long then animation_ring_long:pause() end
        end
    else
        if animation_idle then animation_idle:resume(); animation_idle:update(dt) end
        if animation_ring_short then animation_ring_short:pause() end
        if animation_ring_long then animation_ring_long:pause() end
    end
end

function bell:loadAssets()
   spritesheet = love.graphics.newImage('asets/sprites/bell_spritesheet.png')
   local grid = anim8.newGrid(16, 32, spritesheet:getWidth(), spritesheet:getHeight())
   animation_idle = anim8.newAnimation(grid('1-5',1), 0.3)
   -- Short ring: frames 6-9
   animation_ring_short = anim8.newAnimation(grid('6-9',1), 0.1, function(anim)
       anim:pauseAtEnd()
       for _, b in ipairs(bell._active) do
           if b.isRinging then
               b.isRinging = false
               b.state = 'idle'
               break
           end
       end
   end)
   -- Long ring: frames 6-11
   animation_ring_long = anim8.newAnimation(grid('6-11',1), 0.1, function(anim)
       anim:pauseAtEnd()
       for _, b in ipairs(bell._active) do
           if b.isRinging then
               b.isRinging = false
               b.state = 'idle'
               break
           end
       end
   end)
   -- Bell sound is managed by audio.lua; nothing to load here

end

function bell:draw()
    if self.state == 'ringing_long' then
        if animation_ring_long then
            animation_ring_long:draw(spritesheet, self.x, self.y, 0, 1, 1, self.w, self.h/2)
        end
    elseif self.state == 'ringing_short' or self.isRinging then
        if animation_ring_short then
            animation_ring_short:draw(spritesheet, self.x, self.y, 0, 1, 1, self.w, self.h/2)
        end
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