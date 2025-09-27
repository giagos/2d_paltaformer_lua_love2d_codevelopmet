---@diagnostic disable: undefined-global
-- minimal STI map loader
 
-- STI + Box2D (no Bump)
local sti = require("sti")
local Player = require("player")
local DebugDraw = require("debugdraw")

local map
local scale = 2
local player
local showColliders = true

function love.load()
	love.physics.setMeter(1) -- Use pixels as physics units to match STI plugin
	map = sti("tiled/map/1.lua",{"box2d"})
	world = love.physics.newWorld(0,0)
	map:box2d_init(world)
	-- Ensure STI-created fixtures are solid (not sensors)
	if map.box2d_collision then
		for _, entry in ipairs(map.box2d_collision) do
			if entry.fixture then
				if entry.fixture:isSensor() then entry.fixture:setSensor(false) end
				entry.fixture:setFriction(0.9)
			end
		end
	end
	-- Log how many Box2D fixtures STI created so we can verify colliders exist
	if map.box2d_collision then
		local count = 0
		for _, entry in ipairs(map.box2d_collision) do if entry.fixture then count = count + 1 end end
		print("[STI/Box2D] fixtures:", count)
	else
		print("[STI/Box2D] No collision table created (check collidable properties in Tiled)")
	end
	map.layers.solid.visible = false
	background = love.graphics.newImage("asets/sprites/background.png")

	-- create and load player
	player = Player
	player:load(world, 64, 64)
	if player.physics and player.physics.fixture then
		print("[Player] collider created:", true)
	else
		print("[Player] collider created:", false)
	end
end

function love.update(dt)
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
	love.graphics.draw(background)
	love.graphics.push()
	if map and map.draw then
		map:draw(0, 0, scale, scale)
	end
	-- draw colliders and player in same visual scale
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

