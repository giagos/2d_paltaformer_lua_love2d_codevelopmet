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
local Chain = require("chain")
local PlayerTextBox = require("player_text_box")
local DebugDraw = require("debugdraw")

local map
local scale = 2
local player
local balls = {}
local boxes = {}
local chain
local playerTextBox
local showColliders = false

love.graphics.setDefaultFilter("nearest","nearest")

function love.load()
	-- Physics setup: 1 meter = 1 pixel so STI's pixel-based colliders match Box2D bodies
	love.physics.setMeter(1)

	-- Optional: set a custom font here (graphics is available now)
	--pcall(function()
		--local f = love.graphics.newFont("OneTimeNbpRegular-YJyO.ttf", 12)
		--love.graphics.setFont(f)
	--end)

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

	-- Text box bound to player
	playerTextBox = PlayerTextBox.new(player)

	-- Create balls so you can see them collide with the player/boxes
	table.insert(balls, Ball.new(world, 140, 40, 10, { restitution = 0.6, friction = 0.4 }))
	table.insert(balls, Ball.new(world, 160, 32, 6,  { restitution = 0.8, friction = 0.5, color = {0.9, 0.6, 0.2, 1} }))
	table.insert(balls, Ball.new(world, 120, 28, 8,  { restitution = 0.7, friction = 0.5, color = {0.4, 0.8, 1.0, 1} }))

	-- Create a few boxes beside the ball
	boxes[1] = Box.new(world, 180, 40, 24, 24, { type = 'dynamic', restitution = 0.2 })
	boxes[2] = Box.new(world, 210, 40, 24, 24, { type = 'dynamic', restitution = 0.2 })
	-- A static ground block (if your map lacks solid at that height)
	-- boxes[3] = Box.new(world, 160, 120, 120, 16, { type = 'static' })

	-- Create a hanging chain (links connected by revolute joints) anchored near the top
	-- args: world, anchorX, anchorY, linkCount, linkLength, linkThickness, opts
	chain = Chain.new(world, 220, 1, 8, 16, 6, { group = -1 })
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
	for _, b in ipairs(balls) do if b.update then b:update(dt) end end
	for _, b in ipairs(boxes) do if b.update then b:update(dt) end end
	if chain and chain.update then chain:update(dt) end
	if playerTextBox and playerTextBox.update then playerTextBox:update(dt) end
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
	if chain and chain.draw then chain:draw() end
	for _, b in ipairs(balls) do if b.draw then b:draw() end end
	for _, b in ipairs(boxes) do if b.draw then b:draw() end end
	if player and player.draw then
		player:draw()
	end
	if showColliders then
		DebugDraw.drawWorldTransparent(world)
	end
	if playerTextBox and playerTextBox.draw then playerTextBox:draw() end
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

	-- Demo: Press T to show a text box over the player 
	if key == 't' and playerTextBox and playerTextBox.show then
		playerTextBox:show("TEST 123 hi !", 30)
	end
end

-- Forward mouse input to chain for dragging the red anchor
function love.mousepressed(x, y, button)
	if chain and chain.mousepressed then
		-- account for visual scale (map + entities drawn at "scale")
		local sx, sy = x / scale, y / scale
		chain:mousepressed(sx, sy, button)
	end
end

function love.mousereleased(x, y, button)
	if chain and chain.mousereleased then
		local sx, sy = x / scale, y / scale
		chain:mousereleased(sx, sy, button)
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if chain and chain.mousemoved then
		local sx, sy = x / scale, y / scale
		chain:mousemoved(sx, sy, dx / scale, dy / scale)
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

