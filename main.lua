---@diagnostic disable: undefined-global
-- Entry point for the game. Loads an STI map, sets up Box2D physics, spawns the player,
-- and draws everything. This project uses ONLY Box2D (no Bump).
--
-- Key ideas:
-- - We set love.physics.setMeter(1) so 1 meter = 1 pixel. That way, STI colliders
--   (which are created in map pixel coordinates) match the player body exactly.
-- - We draw the map with a visual scale (scale=2) for a chunky pixel look.
--   Physics itself stays in pixels because meter=1.
-- - F2 toggles a transparent collider overlay. It never changes global scale.
-- - R resets the player to a known position for quick testing.
-- - ESC quits.
 
-- Game systems centralized in Map module
local Map = require("map")
local Camera = require("camera")
local DebugMenu = require("debugmenu")
local Audio = require("audio")
local SaveState = require("save_state")

-- No per-entity globals here; Map manages world/map/entities


love.graphics.setDefaultFilter("nearest","nearest")

function love.load()
	-- Physics setup: 1 meter = 1 pixel so STI's pixel-based colliders match Box2D bodies
	love.physics.setMeter(1)

	-- Initialize audio registry
	if Audio and Audio.init then Audio.init() end

	-- Initialize save system (separate from content). One slot for now.
	SaveState.setPersistent(false) -- one-shot session: no disk writes
	SaveState.init('save/slot1.lua') -- path kept for future; currently unused in session-only

	-- Delegate all map/world/entity setup to Map
	Map:load(2)

	-- After Map loads, set current map id and apply any saved overrides.
	-- We use the current level base path as the id (e.g., 'tiled/map/1').
	local currentId = Map:getCurrentLevel()
	SaveState.setCurrentMapId(currentId)
	SaveState.applyToMapCurrent()

	-- Initialize DebugMenu and hook into Map draw for world overlays
	DebugMenu.init(Map:getWorld(), Map:getLevel(), Map:getPlayer())
	if DebugMenu.setMapOwner then DebugMenu.setMapOwner(Map) end
	if Map.setWorldOverlayDrawFn then
		Map:setWorldOverlayDrawFn(function()
			DebugMenu.drawWorld()
		end)
	end
end

function love.update(dt)
	Map:update(dt)
	-- Smoothly follow the player with the camera rect
	Camera.update(dt, Map:getPlayer())
end

function love.draw()
	Map:draw()
	-- Draw the non-filled camera rectangle in world space above entities
	love.graphics.push()
	love.graphics.scale(Map:getScale(), Map:getScale())
	Camera.draw(Map:getPlayer())
	love.graphics.pop()
	-- Screen-space debug overlays after world draw
	DebugMenu.drawScreen()
end

function love.keypressed(key, scancode, isrepeat)
	-- Debug toggles
	DebugMenu.keypressed(key)
	-- Game logic
	Map:keypressed(key)
end

function love.keyreleased(key, scancode)
	if DebugMenu.keyreleased then DebugMenu.keyreleased(key) end
	if Map.keyreleased then Map:keyreleased(key) end
end

-- Forward mouse input to chain for dragging the red anchor
function love.mousepressed(x, y, button)
    if DebugMenu.mousepressed then DebugMenu.mousepressed(x, y, button) end
	Map:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
	if DebugMenu.mousereleased then DebugMenu.mousereleased(x, y, button) end
	Map:mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy, istouch)
	if DebugMenu.mousemoved then DebugMenu.mousemoved(x, y, dx, dy) end
	Map:mousemoved(x, y, dx, dy)
end

-- World contact callbacks are set inside Map when creating the world

