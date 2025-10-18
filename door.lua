---@diagnostic disable: undefined-global
-- door.lua
-- Solid door (16x32 by default) with two orthogonal states:
--   - isOpen:   when true -> non-collidable (sensor)
--                when false -> collidable (solid)
--   - isLocked: when true -> won't open; can be changed at runtime and is saved.
--
-- Integration
-- - Listens to Interactable sensors just like button.lua.
-- - Properties (passed via spawner cfg/obj.properties):
--     name     : entity name in Tiled entity layer (required for SaveState overlay)
--     sensor   : number or string (e.g., 1 or "interactableSensor1")
--     key      : key to toggle isOpen (default 'e')
--     unlockKey: optional key to toggle isLocked off/on (default nil)
--     locked   : initial locked state (default false)
--     isOpen   : initial open state (default false)
--     w, h     : size (defaults: 16 x 32)
-- - Persistence:
--     SaveState persists both isOpen and isLocked per map+name.
-- - Rendering:
--     Placeholder rectangles for now; animation/sprite scaffolding left as comments.

local Interact = require('interactable_sensor_handler')
local PlayerData = require('data.player_data')
local SaveState = require('save_state')
local GameContext = require('game_context')

local Door = {}
Door.__index = Door
Door._active = {}

local function toPixels(x)
  local m = love.physics.getMeter()
  return x * m
end

local function toMeters(x)
  local m = love.physics.getMeter()
  return x / m
end

function Door.new(world, x, y, w, h, opts)
  local self = setmetatable({}, Door)
  self:load(world, x, y, w, h, opts)
  table.insert(Door._active, self)
  return self
end

function Door:load(world, x, y, w, h, opts)
  opts = opts or {}
  self.name = opts.name or 'door'
  self.kind = 'door'
  self.type = 'door'
  self.x = x or 0
  self.y = y or 0
  self.w = w or 16
  self.h = h or 32
  self.colorClosed = {0.55, 0.55, 0.8, 1}
  self.colorOpen   = {0.25, 0.85, 0.35, 0.7}
  self.colorLocked = {0.85, 0.3, 0.3, 1}

  -- Sensor linkage (like button): accept number or name, normalize to 'interactableSensorN'
  local sn = opts.sensor
  if type(sn) == 'number' then
    self.sensorName = 'interactableSensor' .. tostring(sn)
  elseif type(sn) == 'string' and sn ~= '' then
    self.sensorName = sn:match('^interactableSensor') and sn or ('interactableSensor' .. sn)
  else
    self.sensorName = nil
  end

  self.key = opts.key or 'e'
  self.unlockKey = opts.unlockKey -- optional

  -- Initial states from opts/properties; SaveState.applyToMapCurrent() already merged into Tiled props.
  self.isLocked = opts.locked == true
  self.isOpen   = opts.isOpen == true

  -- Physics: create a static rectangle; we toggle sensor flag to simulate open/non-collide
  self.physics = {}
  self.physics.body = love.physics.newBody(world, toMeters(self.x), toMeters(self.y), 'static')
  self.physics.shape = love.physics.newRectangleShape(self.w, self.h)
  self.physics.fixture = love.physics.newFixture(self.physics.body, self.physics.shape)
  self.physics.fixture:setUserData({ kind = 'door', name = self.name, properties = opts })

  -- Apply current open/closed state to fixture collision
  self:_applyCollisionMode()

  -- FUTURE: animation setup
  -- self:_loadAssetsIfAny()
end

function Door:_applyCollisionMode()
  if not (self.physics and self.physics.fixture) then return end
  -- Closed => collidable (non-sensor). Open => sensor (non-solid)
  local makeSensor = self.isOpen == true
  self.physics.fixture:setSensor(makeSensor)
end

-- External helpers
function Door:getOpen() return self.isOpen end
function Door:getLocked() return self.isLocked end

function Door:setOpen(flag)
  local v = flag and true or false
  if self.isOpen ~= v then
    self.isOpen = v
    self:_applyCollisionMode()
    -- Persist
    SaveState.setEntityPropCurrent(self.name, 'isOpen', self.isOpen)
    -- Keep live Tiled props in sync so update() doesn't immediately overwrite
    if GameContext and GameContext.setEntityProp then
      GameContext.setEntityProp(self.name, 'isOpen', self.isOpen)
    end
  end
  return self.isOpen
end

function Door:setLocked(flag)
  local v = flag and true or false
  if self.isLocked ~= v then
    self.isLocked = v
    -- Persist
    SaveState.setEntityPropCurrent(self.name, 'locked', self.isLocked)
    -- Keep live Tiled props in sync so update() doesn't immediately overwrite
    if GameContext and GameContext.setEntityProp then
      GameContext.setEntityProp(self.name, 'locked', self.isLocked)
    end
  end
  return self.isLocked
end

function Door:toggleOpen()
  return self:setOpen(not self.isOpen)
end

function Door:unlock()
  return self:setLocked(false)
end

function Door:update(dt)
  -- Placeholder: no per-frame logic besides possible animations later
  -- Sync from live Tiled entity properties so external systems (e.g., buttons)
  -- can update lock/open state instantly via GameContext/SaveState overlays.
  if GameContext and GameContext.getEntityObjectProperties then
    local props = GameContext.getEntityObjectProperties(self.name)
    if props then
      local pLocked = props.locked
      if type(pLocked) == 'string' then pLocked = (pLocked:lower() == 'true') end
      if type(pLocked) == 'boolean' and pLocked ~= self.isLocked then
        self:setLocked(pLocked)
      end
      local pOpen = props.isOpen
      if type(pOpen) == 'string' then pOpen = (pOpen:lower() == 'true') end
      if type(pOpen) == 'boolean' and pOpen ~= self.isOpen then
        self:setOpen(pOpen)
      end
    end
  end
  -- FUTURE: update animations here
end

-- Interact via key press while inside the linked interactable sensor
function Door:keypressed(key)
  if not self.sensorName then return false end
  -- Block interaction if the player is currently overlapping the door's rectangle
  if self:_isPlayerInsideDoor() then
    return false
  end
  if not Interact or not Interact.onPress then return false end
  if Interact.onPress(self.sensorName, key) then
    -- First: handle lock/unlock if unlockKey is configured
    if self.unlockKey and key == self.unlockKey then
      self:setLocked(not self.isLocked)
      return true
    end
    -- Toggle open/close only when unlocked
    if self.isLocked then
      -- Locked: do nothing (optional: feedback)
      print(string.format('[Door:%s] Locked', self.name))
      return true
    end
    self:toggleOpen()
    return true
  end
  return false
end

-- Returns true if the player's AABB intersects this door's rectangle (in pixels)
function Door:_isPlayerInsideDoor()
  local fix = Interact and Interact.getPlayerFixture and Interact.getPlayerFixture() or nil
  if not (fix and fix.getBody) then return false end
  local body = fix:getBody()
  if not body then return false end
  local px_m, py_m = body:getPosition()
  local px, py = toPixels(px_m), toPixels(py_m)
  local pw = (PlayerData and PlayerData.size and PlayerData.size.width) or 8
  local ph = (PlayerData and PlayerData.size and PlayerData.size.height) or 16

  local dx, dy, dw, dh = self.x - self.w/2, self.y - self.h/2, self.w, self.h
  local px0, py0 = px - pw/2, py - ph/2

  local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
  end
  return rectsOverlap(dx, dy, dw, dh, px0, py0, pw, ph)
end

function Door:draw()
  if not self.physics or not self.physics.body then return end
  local bx, by = self.physics.body:getPosition()
  local x, y = toPixels(bx), toPixels(by)
  local w, h = self.w, self.h

  -- Pick color based on state
  local col
  if self.isLocked then col = self.colorLocked
  elseif self.isOpen then col = self.colorOpen
  else col = self.colorClosed end

  love.graphics.setColor(col)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rectangle('fill', -w/2, -h/2, w, h, 2, 2)
  -- Simple outline
  love.graphics.setColor(0,0,0,0.8)
  love.graphics.rectangle('line', -w/2, -h/2, w, h, 2, 2)
  love.graphics.pop()
  love.graphics.setColor(1,1,1,1)

  -- FUTURE: draw animated sprite instead of rectangles
end

function Door:remove()
  if self.physics then
    if self.physics.fixture and not self.physics.fixture:isDestroyed() then
      pcall(function() self.physics.fixture:destroy() end)
    end
    if self.physics.body and not self.physics.body:isDestroyed() then
      pcall(function() self.physics.body:destroy() end)
    end
  end
end

function Door.removeAll()
  for i = #Door._active, 1, -1 do
    local d = Door._active[i]
    if d and d.remove then pcall(function() d:remove() end) end
    Door._active[i] = nil
  end
  Door._active = {}
end

return Door
