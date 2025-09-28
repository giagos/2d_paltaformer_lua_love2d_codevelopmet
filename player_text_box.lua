---@diagnostic disable: undefined-global
-- PlayerTextBox: shows a black opaque text box with white text above the player
-- Usage:
--   local PlayerTextBox = require('player_text_box')
--   local ptb = PlayerTextBox.new(player)
--   ptb:show("Hello there!", 3) -- show for 3 seconds
--   In love.update: ptb:update(dt)
--   In love.draw (after scaling): ptb:draw()

local PlayerTextBox = {}
PlayerTextBox.__index = PlayerTextBox

function PlayerTextBox.new(player)
  local self = setmetatable({}, PlayerTextBox)
  self.player = player
  self.active = false
  self.text = ""
  self.timeLeft = 0
  self.paddingX = 6
  self.paddingY = 4
  self.backgroundColor = {0, 0, 0, 0.9}
  self.textColor = {1, 1, 1, 1}
  self.bobAmplitude = 4   -- pixels
  self.bobSpeed = 6       -- radians per second
  self.bobT = 0
  self.offsetY = 18       -- base vertical offset above player top
  self.maxWidth = 160     -- wrap width in pixels (scaled space)
  return self
end

function PlayerTextBox:isActive()
  return self.active and self.timeLeft > 0
end

-- Show a text box for `duration` seconds. If duration is nil, defaults to 2.
function PlayerTextBox:show(text, duration)
  if not text or text == "" then return end
  self.text = tostring(text)
  self.timeLeft = (duration and duration > 0) and duration or 2
  self.active = true
  self.bobT = 0
end

function PlayerTextBox:update(dt)
  if not self.active then return end
  self.timeLeft = self.timeLeft - dt
  if self.timeLeft <= 0 then
    self.active = false
    return
  end
  self.bobT = self.bobT + dt * self.bobSpeed
end

local function measureWrappedText(font, text, wrapLimit)
  -- Returns width, height and the wrapped text (as a single string with '\n')
  local a, b = font:getWrap(text, wrapLimit)
  local linesTbl = nil
  if type(a) == 'table' then
    linesTbl = a
  elseif type(b) == 'table' then
    linesTbl = b
  else
    linesTbl = { text }
  end
  local maxW = 0
  for _, line in ipairs(linesTbl) do
    local w = font:getWidth(line)
    if w > maxW then maxW = w end
  end
  local h = #linesTbl * font:getHeight()
  return maxW, h, table.concat(linesTbl, "\n")
end

function PlayerTextBox:draw()
  if not self:isActive() or not self.player then return end
  local px = self.player.x or 0
  local py = self.player.y or 0
  local pHalfH = (self.player.height or 16) / 2

  -- Compute base position above player
  local baseX = px
  local baseY = py - pHalfH - self.offsetY

  -- Bobbing offset
  local bob = math.sin(self.bobT) * self.bobAmplitude
  local x = baseX
  local y = baseY + bob

  local font = love.graphics.getFont()
  local wrapW = self.maxWidth
  local textW, textH, wrapped = measureWrappedText(font, self.text, wrapW)

  local boxW = textW + self.paddingX * 2
  local boxH = textH + self.paddingY * 2
  local boxX = math.floor(x - boxW / 2)
  local boxY = math.floor(y - boxH)

  -- Draw opaque black box (square corners)
  love.graphics.setColor(self.backgroundColor)
  love.graphics.rectangle('fill', boxX, boxY, boxW, boxH)

  -- High-contrast border for clarity (square corners)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle('line', boxX, boxY, boxW, boxH)

  -- Small pointer triangle under the box (does not touch the player)
  local boxCenterX = boxX + boxW/2
  local by = boxY + boxH
  local triHalf = 3  -- half width of triangle base (smaller = slimmer)
  local triH = 4     -- triangle height
  local gap = 4      -- visual gap between triangle tip and player head (indirectly, since triangle is fixed under box)
  love.graphics.setColor(self.backgroundColor)
  love.graphics.polygon('fill',
    boxCenterX - triHalf, by,
    boxCenterX + triHalf, by,
    boxCenterX, by + triH
  )
  love.graphics.setColor(1,1,1,1)
  love.graphics.polygon('line',
    boxCenterX - triHalf, by,
    boxCenterX + triHalf, by,
    boxCenterX, by + triH
  )

  -- Draw white text
  love.graphics.setColor(self.textColor)
  love.graphics.printf(wrapped, boxX + self.paddingX, boxY + self.paddingY, wrapW, 'left')

  love.graphics.setColor(1,1,1,1)
end

return PlayerTextBox
