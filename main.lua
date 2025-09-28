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
local Ball = require("ball")
local Box = require("box")
local DebugDraw = require("debugdraw")

local map
local scale = 2
local player
local ball
local boxes = {}
local showColliders = false

function love.load()
	-- Physics setup: 1 meter = 1 pixel so STI's pixel-based colliders match Box2D bodies
	love.physics.setMeter(1)

	-- Load the Tiled map via STI, enabling its Box2D plugin
	map = sti("tiled/map/1.lua", { "box2d" })

	-- Create the Box2D world with gravity so dynamic balls fall and bounce
	world = love.physics.newWorld(0, 1200)
	-- Forward Box2D contacts to our handlers
	world:setCallbacks(beginContact, endContact)

	-- Ask STI to create Box2D fixtures from collidable layers/objects in the map
	map:box2d_init(world)

	-- If the map has a visible "solid" layer, hide it so we only draw tiles, not debug
	if map.layers.solid then map.layers.solid.visible = false end

	-- Simple background image
	background = love.graphics.newImage("asets/sprites/background.png")

	-- Create and load player physics body/fixture at (64,64) in pixels
	player = Player
	player:load(world, 64, 64)

	-- Create a ball so you can see it collide with the player
	ball = Ball.new(world, 140, 40, 10, { restitution = 0.6, friction = 0.4 })

	-- Create a few boxes beside the ball
	boxes[1] = Box.new(world, 180, 40, 24, 24, { type = 'dynamic', restitution = 0.2 })
	boxes[2] = Box.new(world, 210, 40, 24, 24, { type = 'dynamic', restitution = 0.2 })
	-- A static ground block (if your map lacks solid at that height)
	-- boxes[3] = Box.new(world, 160, 120, 120, 16, { type = 'static' })
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
	if ball and ball.update then
		ball:update(dt)
	end
	for _, b in ipairs(boxes) do if b.update then b:update(dt) end end
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
	if ball and ball.draw then
		ball:draw()
	end
	for _, b in ipairs(boxes) do if b.draw then b:draw() end end
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
	-- Jump input (W/Up) handled inside player
	if player and player.jump then
		player:jump(key)
	end
end

-- Box2D world contact callbacks
function beginContact(a, b, collision)
	if player and player.beginContact then
		player:beginContact(a, b, collision)
	end
end

function endContact(a, b, collision)
	if player and player.endContact then
		player:endContact(a, b, collision)
	end
end

