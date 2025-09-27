--- Minimal LÖVE entry point
---@diagnostic disable: undefined-global

local TITLE = "2D Platformer (Empty)"

function love.load()
  love.window.setTitle(TITLE)
  -- Background color (LÖVE 11.x uses 0..1 values)
  if love.graphics.setBackgroundColor then
    love.graphics.setBackgroundColor(0.10, 0.10, 0.12, 1.0)
  end
end

function love.update(dt)
  -- No game logic yet
end

function love.draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf("It works! Press ESC to quit.", 0, h/2 - 8, w, "center")
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "f11" then
    local isFull = love.window.getFullscreen()
    love.window.setFullscreen(not isFull)
  end
end
