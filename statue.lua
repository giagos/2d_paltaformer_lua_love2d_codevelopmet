---@diagnostic disable: undefined-global
-- statue.lua
-- Singleton decorative statue/flame that reflects bell1 solve state.
-- - When bell1.isSolved is false (or missing): draw asets/sprites/statue.png
-- - When true:                              draw asets/sprites/statueL.png
-- Future: can swap to animations instead of static images.

local GameContext = require('game_context')
local anim8 = require('anim8')

local M = {}

-- Internal state (singleton)
local x, y = 0, 0
local imgOff, imgOn
local animOn -- anim8 animation for solved state (single-frame for now)
local originX, originY = 0, 0
local loaded = false

-- Public API
function M.load(px, py)
  -- Position is the center in pixels
  x, y = px or x, py or y
  if not loaded then
    -- Static image for unsolved state
    imgOff = love.graphics.newImage('asets/sprites/statue.png')
    -- Solved state prepared for future animation: currently a single-frame anim8 animation
    imgOn  = love.graphics.newImage('asets/sprites/statueL.png')

    -- Build a single-frame animation covering the whole image
    local fw, fh = imgOn:getWidth(), imgOn:getHeight()
    local grid = anim8.newGrid(fw, fh, fw, fh)
    animOn = anim8.newAnimation(grid('1-1', '1-1'), 0.2) -- placeholder frame time

    originX, originY = fw / 2, fh / 2
    loaded = true
  end
  return M
end

function M.setPosition(px, py)
  x, y = px or x, py or y
end

function M:update(dt)
  -- Advance solved-state animation (single frame today; future-proofed)
  -- NOTE on ':' vs '.' calls:
  --   Defining the method with ':' means it expects to be called like M:update(dt).
  --   If someone accidentally calls M.update(dt) (with a dot), 'dt' will actually be the table M,
  --   so 'dt' becomes a table instead of a number. The guard below resets it to 0 in that case
  --   to avoid anim8 math on a table (which would error).
  if type(dt) ~= 'number' then dt = 0 end
  if animOn then animOn:update(dt) end
end

local function getCurrentImage()
  local props = nil
  if GameContext and GameContext.getEntityObjectProperties then
    props = GameContext.getEntityObjectProperties('bell1')
  end
  local solved = props and props.isSolved or false
  return solved and imgOn or imgOff
end

function M:draw()
  if not loaded then return end
  local img = getCurrentImage()
  if not img then return end
  love.graphics.setColor(1,1,1,1)
  if img == imgOn and animOn then
    animOn:draw(imgOn, x, y, 0, 1, 1, originX, originY)
  else
    local ox, oy = (img:getWidth() / 2), (img:getHeight() / 2)
    love.graphics.draw(img, x, y, 0, 1, 1, ox, oy)
  end
  love.graphics.setColor(1,1,1,1)
end

-- FUTURE: Single spritesheet migration (one image for both states)
-- If later you only have ONE image (a spritesheet) for both unsolved+solved:
-- 1) Replace the two loads with a single sheet, e.g.:
--      local sheet = love.graphics.newImage('asets/sprites/statue_sheet.png')
-- 2) Decide frame size (fw, fh) and build the grid from the sheet dimensions:
--      local grid = anim8.newGrid(fw, fh, sheet:getWidth(), sheet:getHeight())
-- 3) Make both states animations using the SAME sheet:
--      -- Unsolved: single-frame animation (e.g., frame 1,1)
--      animOff = anim8.newAnimation(grid(1,1), 1)  -- or 0.1, any value; it won't change frames
--      -- Solved: multi-frame range (e.g., 1-6 on row 1)
--      animOn  = anim8.newAnimation(grid('1-6', 1), 0.1)
-- 4) Update draw() to always use animations instead of raw images:
--      if isSolved then animOn:draw(sheet, x, y, 0, 1, 1, originX, originY) else
--         animOff:draw(sheet, x, y, 0, 1, 1, originX, originY)
--      end
-- 5) You can drop imgOff/imgOn variables entirely and just keep 'sheet'.

return M
