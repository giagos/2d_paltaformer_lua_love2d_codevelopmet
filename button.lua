---@diagnostic disable: undefined-global
-- button.lua
-- Generic press-to-toggle button that listens to an InteractableSensor.
-- Usage (via spawner): place an entity named 'button1' and set properties:
--   sensor = 1           -- number or 'interactableSensor1'
--   key    = 'e'         -- optional, defaults to accept any key
-- The button will turn green when pressed (toggled on), red otherwise.

local Interact = require('interactable_sensor_handler')

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
  self.isPressed = false -- toggled state
  self._justConsumed = false
end

-- Toggle logic on key press while inside the linked sensor
function Button:update(dt)
  if not self.sensorName then return end
  -- If a specific key is configured, only that key activates; otherwise any key
  -- Note: we can't read keys here directly; call Button:keypressed from love.keypressed
  -- or use the helper below if you prefer polling Interact.any.
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
    self.isPressed = not self.isPressed
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
  love.graphics.setColor(r,g,b,1)
  love.graphics.rectangle('fill', self.x - self.w/2, self.y - self.h/2, self.w, self.h)
  love.graphics.setColor(0,0,0,0.9)
  love.graphics.rectangle('line', self.x - self.w/2, self.y - self.h/2, self.w, self.h)
  love.graphics.setColor(1,1,1,1)
end

return Button
