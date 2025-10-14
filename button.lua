---@diagnostic disable: undefined-global
-- button.lua
-- Generic press-to-toggle button that listens to an InteractableSensor.
-- Usage (via spawner): place an entity named 'button1' and set properties:
--   sensor = 1           -- number or 'interactableSensor1'
--   key    = 'e'         -- optional, defaults to accept any key
--   toggle = true        -- optional; when false, momentary (on only while key held)
-- The button will turn green when active, red otherwise.

local Interact = require('interactable_sensor_handler')
-- FUTURE animation groundwork:
-- local anim8 = require('anim8')
-- local spriteSheet, spriteGrid
-- local animIdle, animPressed

local Button = {}
Button.__index = Button

function Button.new(world, x, y, w, h, opts)
  local self = setmetatable({}, Button)
  self:load(world, x, y, w, h, opts)
  return self
end

function Button:load(world, x, y, w, h, opts)
  opts = opts or {}
  self.x = x or 0
  self.y = y or 0
  self.w = w or 16
  self.h = h or 16
  self.kind = 'button'
  self.name = opts.name
  self.properties = opts.properties or {}
  self.requiredKey = (opts.key or self.properties.key)
  if type(self.requiredKey) == 'string' then self.requiredKey = self.requiredKey:lower() end
  -- Toggle vs momentary: default true (toggle). When false, only on while key held.
  local toggleProp = opts.toggle
  if toggleProp == nil then toggleProp = self.properties.toggle end
  if type(toggleProp) == 'string' then toggleProp = (toggleProp:lower() == 'true') end
  if type(toggleProp) ~= 'boolean' then toggleProp = true end
  self.toggle = toggleProp
  -- Link to an interactable sensor by number or full name
  local sensorProp = opts.sensor or self.properties.sensor
  if type(sensorProp) == 'number' then
    self.sensorName = ('interactableSensor%d'):format(sensorProp)
  elseif type(sensorProp) == 'string' then
    -- Accept either 'interactableSensorN' or just 'N'
    local n = sensorProp:match('^%d+$') and tonumber(sensorProp)
    if n then
      self.sensorName = ('interactableSensor%d'):format(n)
    else
      self.sensorName = sensorProp
    end
  else
    self.sensorName = nil
  end

  -- State
  self.isPressed = false -- toggled or momentary active state
  self._justConsumed = false

  -- When momentary and player exits the sensor, force off
  if self.sensorName then
    local onExitTable = Interact.onExit
    if type(onExitTable) == 'table' then
      local prevExit = onExitTable[self.sensorName]
      onExitTable[self.sensorName] = function(name)
        if not self.toggle then
          self.isPressed = false
        end
        if type(prevExit) == 'function' then prevExit(name) end
      end
    end
  end
  -- FUTURE: self:_loadAssetsIfAny()
end

-- Toggle logic on key press while inside the linked sensor
function Button:update(dt)
  if not self.sensorName then return end
  -- If a specific key is configured, only that key activates; otherwise any key
  -- Note: we can't read keys here directly; call Button:keypressed from love.keypressed
  -- or use the helper below if you prefer polling Interact.any.
  -- FUTURE: if anims exist -> (self.isPressed and animPressed or animIdle):update(dt)
end

-- Call from love.keypressed(key) or your input pipeline
function Button:keypressed(key)
  if not self.sensorName then return false end
  if type(key) ~= 'string' then return false end
  local lower = key:lower()
  -- Only activate if player is inside and key matches allowance
  local required = self.requiredKey or Interact.getRequiredKey(self.sensorName)
  local allowAny = (required == nil)
  if Interact.isInside(self.sensorName) and (allowAny or lower == required) then
    if self.toggle then
      self.isPressed = not self.isPressed
    else
      self.isPressed = true -- momentary
    end
    return true
  end
  return false
end

-- Handle release for momentary behavior
function Button:keyreleased(key)
  if not self.sensorName then return false end
  if type(key) ~= 'string' then return false end
  if self.toggle then return false end
  local lower = key:lower()
  local required = self.requiredKey or Interact.getRequiredKey(self.sensorName)
  if required == nil or lower == required then
    self.isPressed = false
    return true
  end
  return false
end

function Button:getState()
  return self.isPressed == true
end

function Button:draw()
  local r,g,b = 0.9,0.2,0.2 -- red by default
  if self.isPressed then r,g,b = 0.2,0.8,0.3 end -- green when pressed
  -- FUTURE: if sprites are available, draw animation instead of rectangles
  -- local anim = self.isPressed and animPressed or animIdle
  -- if anim and spriteSheet then
  --   anim:draw(spriteSheet, self.x, self.y, 0, 1, 1, self.w/2, self.h/2)
  --   return
  -- end
  love.graphics.setColor(r,g,b,1)
  love.graphics.rectangle('fill', self.x - self.w/2, self.y - self.h/2, self.w, self.h)
  love.graphics.setColor(0,0,0,0.9)
  love.graphics.rectangle('line', self.x - self.w/2, self.y - self.h/2, self.w, self.h)
  love.graphics.setColor(1,1,1,1)
end

return Button
