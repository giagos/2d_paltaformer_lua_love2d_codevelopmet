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
local DebugMenu = require("debugmenu")
local Sensors = require("sensor_handler")

local map
local scale = 2
local player
local balls = {}
local boxes = {}
local chain
local chain2
local playerTextBox


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

	-- Ensure the 'sensor' or 'sensors' object layer generates Box2D fixtures even if Tiled lacked collidable=true
	if map and map.layers then
		for _, layer in ipairs(map.layers) do
			if layer.type == 'objectgroup' and (layer.name == 'sensor' or layer.name == 'sensors') then
				layer.properties = layer.properties or {}
				if layer.properties.collidable ~= true then
					layer.properties.collidable = true
					print("[STI] Enabled collidable=true for '" .. layer.name .. "' layer at runtime")
				end
				-- Ensure every object in this layer is flagged collidable so STI will create fixtures
				if layer.objects then
					for _, obj in ipairs(layer.objects) do
						obj.properties = obj.properties or {}
						if obj.properties.collidable ~= true then
							obj.properties.collidable = true
						end
					end
				end
			end
		end
	end

	-- Ask STI to create Box2D fixtures from collidable layers/objects in the map
	map:box2d_init(world)

	-- Merge layer-level properties into each STI fixture's userData so layer properties like
	-- sensor1=true are visible during contact callbacks. Also, ONLY inherit sensor=true
	-- from a layer when the fixture is part of a sensor trigger (sensor1=true) to avoid
	-- accidentally turning solid ground into sensors.
	if map and map.box2d_collision then
		local merged = 0
		local sensors = 0
		for _, c in ipairs(map.box2d_collision) do
			if c and c.fixture then
				local ud = c.fixture:getUserData() or {}
				local props = {}
				if type(ud.properties) == 'table' then
					for k,v in pairs(ud.properties) do props[k] = v end
				end
				local layerProps = (c.object and c.object.layer and c.object.layer.properties) or nil
				if type(layerProps) == 'table' then
					for k,v in pairs(layerProps) do if props[k] == nil then props[k] = v end end
					-- If this fixture is marked as a sensor trigger (sensor1), make it a sensor
					-- so the player can pass through even if no explicit 'sensor' property exists.
					if props.sensor1 == true then
						c.fixture:setSensor(true)
					end
				end
				ud.properties = props
				c.fixture:setUserData(ud)
				if props and props.sensor1 then sensors = sensors + 1 end
				merged = merged + 1
			end
		end
	print(string.format("[STI] Fixtures: %d, sensor1 fixtures: %d", merged, sensors))
	end

	-- If the map has a visible "solid" layer, hide it so we only draw tiles, not debug
	if map.layers.solid then map.layers.solid.visible = false end
	-- Also hide the 'sensor'/'sensors' object layer so its rectangles are not drawn by STI
	if map.layers.sensor then map.layers.sensor.visible = false end
	if map.layers.sensors then map.layers.sensors.visible = false end

	-- Simple background image
	background = love.graphics.newImage("asets/sprites/background.png")

	-- Create and load player physics body/fixture at (64,64) in pixels
	player = Player
	player:load(world, 64, 64)

	-- Init debug menu now that world, map, and player exist
	DebugMenu.init(world, map, player)

	-- Init Sensors handler (named sensors in Tiled: sensor1, sensor2, ...)
	Sensors.init(world, map, function()
		return player and player.physics and player.physics.fixture or nil
	end)
	-- Example callbacks: show text when entering sensor1/sensor2
	Sensors.onEnter.sensor1 = function()
		if playerTextBox and playerTextBox.show then playerTextBox:show("Sensor1 hit!", 2) end
		print("[Sensor1] ENTER")
	end
	Sensors.onExit.sensor1 = function()
		print("[Sensor1] EXIT")
	end
	Sensors.onEnter.sensor2 = function()
		if playerTextBox and playerTextBox.show then playerTextBox:show("Sensor2 hit!", 2) end
		print("[Sensor2] ENTER")
	end
	Sensors.onExit.sensor2 = function()
		print("[Sensor2] EXIT")
	end

	-- Text box bound to player
	playerTextBox = PlayerTextBox.new(player)

	-- Create balls so you can see them collide with the player/boxes
	table.insert(balls, Ball.new(world, 140, 40, 10, { restitution = 0.6, friction = 0.4 }))
	table.insert(balls, Ball.new(world, 160, 32, 6,  { restitution = 0.8, friction = 0.5, color = {0.9, 0.6, 0.2, 1} }))
	table.insert(balls, Ball.new(world, 120, 28, 8,  { restitution = 0.7, friction = 0.5, color = {0.4, 0.8, 1.0, 1} }))

	-- Create a few boxes beside the ball
	boxes[1] = Box.new(world, 180, 40, 16, 16, { type = 'dynamic', restitution = 0.2 })
	boxes[2] = Box.new(world, 210, 40, 24, 24, { type = 'dynamic', restitution = 0.2 })
	-- A static ground block (if your map lacks solid at that height)
	-- boxes[3] = Box.new(world, 160, 120, 120, 16, { type = 'static' })

	-- Create a hanging chain (links connected by revolute joints) anchored near the top
	-- args: world, anchorX, anchorY, linkCount, linkLength, linkThickness, opts
	chain = Chain.new(world, 220, 1, 8, 16, 6, { group = -1 })

	-- Spawn a second chain, draggable from its END via a mouse joint
	-- Use a different group index so the two chains can collide with each other
	chain2 = Chain.new(world, 300, 1, 8, 16, 6, { group = -2, dragTarget = 'both', endAnchored = true, color = {0.8, 0.9, 0.8, 1} })
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
	if chain2 and chain2.update then chain2:update(dt) end
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
	if chain2 and chain2.draw then chain2:draw() end
	for _, b in ipairs(balls) do if b.draw then b:draw() end end
	for _, b in ipairs(boxes) do if b.draw then b:draw() end end
	if player and player.draw then
		player:draw()
	end
	-- World-space debug overlays (F2/F3)
	DebugMenu.drawWorld()
	if playerTextBox and playerTextBox.draw then playerTextBox:draw() end
	love.graphics.pop()

	-- Screen-space overlays (F4)
	DebugMenu.drawScreen()

end

function love.keypressed(key, scancode, isrepeat)
	-- Delegate debug keys first so F2/F3/F4 are handled centrally
	DebugMenu.keypressed(key)

	if key == "r" then
		-- Reset player position for testing
		local meter = love.physics.getMeter()
		if player and player.physics and player.physics.body then
			player.physics.body:setLinearVelocity(0,0)
			player.physics.body:setPosition(64 / meter, 64 / meter)
		end
	elseif key == "escape" then
		love.event.quit()
	end
	-- Text box demo disabled in minimal mode

	-- Forward keypresses to player (jump etc.)
	if player and player.keypressed then
		player:keypressed(key)
	end
end

-- Forward mouse input to chain for dragging the red anchor
function love.mousepressed(x, y, button)
	-- account for visual scale (map + entities drawn at "scale")
	local sx, sy = x / scale, y / scale
	-- Choose one chain to capture the click based on hit test (prefer chain2 end-drag)
	local captured = false
	if chain2 and chain2.isMouseOver and chain2.mousepressed then
		if chain2:isMouseOver(sx, sy) then
			chain2:mousepressed(sx, sy, button)
			captured = true
		end
	end
	if (not captured) and chain and chain.isMouseOver and chain.mousepressed then
		if chain:isMouseOver(sx, sy) then
			chain:mousepressed(sx, sy, button)
			captured = true
		end
	end
end

function love.mousereleased(x, y, button)
	local sx, sy = x / scale, y / scale
	if chain and chain.mousereleased then chain:mousereleased(sx, sy, button) end
	if chain2 and chain2.mousereleased then chain2:mousereleased(sx, sy, button) end
end

function love.mousemoved(x, y, dx, dy, istouch)
	local sx, sy = x / scale, y / scale
	if chain and chain.mousemoved then chain:mousemoved(sx, sy, dx / scale, dy / scale) end
	if chain2 and chain2.mousemoved then chain2:mousemoved(sx, sy, dx / scale, dy / scale) end
end

-- Box2D world contact callbacks
function beginContact(a, b, collision)
	if player and player.beginContact then
		player:beginContact(a, b, collision)
	end

	-- Delegate sensor contacts to handler
	Sensors.beginContact(a, b)
end

function endContact(a, b, collision)
	if player and player.endContact then
		player:endContact(a, b, collision)
	end

	Sensors.endContact(a, b)
end

