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
 
-- STI + Box2D (no Bump)
local sti = require("sti")
local Player = require("player")
local DebugDraw = require("debugdraw")

local map
local scale = 2
local player
local showColliders = false

function love.load()
	-- Physics setup: 1 meter = 1 pixel so STI's pixel-based colliders match Box2D bodies
	love.physics.setMeter(1)

	-- Load the Tiled map via STI, enabling its Box2D plugin
	map = sti("tiled/map/1.lua", { "box2d" })

	-- Create the Box2D world (no gravity per your preference)
	world = love.physics.newWorld(0, 0)

	-- Ask STI to create Box2D fixtures from collidable layers/objects in the map
	map:box2d_init(world)

	-- If the map has a visible "solid" layer, hide it so we only draw tiles, not debug
	if map.layers.solid then map.layers.solid.visible = false end

	-- Simple background image
	background = love.graphics.newImage("asets/sprites/background.png")

	-- Create and load player physics body/fixture at (64,64) in pixels
	player = Player
	player:load(world, 64, 64)
end

function love.update(dt)
	-- Update STI (animations/parallax), update its Box2D plugin (if used), and step the world
	if map and map.update then
		map:update(dt)
	end
	if map and map.box2d_update then
		map:box2d_update(dt)
	end
	if world then
		world:update(dt)
	end
	if player and player.update then
		player:update(dt)
	end
end

function love.draw()
	-- Draw background, then the map (scaled visually), then player and debug overlay.
	love.graphics.draw(background)
	love.graphics.push()
	if map and map.draw then
		map:draw(0, 0, scale, scale)
	end
	-- Draw player and debug overlay in the same visual scale as the map
	love.graphics.scale(scale, scale)
	if player and player.draw then
		player:draw()
	end
	if showColliders then
		DebugDraw.drawWorldTransparent(world)
	end
	love.graphics.pop()
end

function love.keypressed(key)
	if key == "f2" then
		-- Toggle transparent collider overlay (player in red, map in green)
		showColliders = not showColliders
		print("Colliders visible:", showColliders)
	elseif key == "r" then
		-- Reset player position for testing
		local meter = love.physics.getMeter()
		if player and player.physics and player.physics.body then
			player.physics.body:setLinearVelocity(0,0)
			player.physics.body:setPosition(64 / meter, 64 / meter)
		end
	elseif key == "escape" then
		love.event.quit()
	end
end

