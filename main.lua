---@diagnostic disable: undefined-global
-- minimal STI map loader
 
local sti = require("sti")
local Player = require("player")

local map
local scale = 2
local player

function love.load()
	map = sti("tiled/map/1.lua",{"box2d"})
	world = love.physics.newWorld(0, 9.81 * 32) -- gravity down (pixels/s^2), meter=32 by default
	map:box2d_init(world)
	map.layers.solid.visible = false
	--background = love.graphics.newImage()

	-- Create player
	player = Player
	player:load(world, 64, 64)
end

function love.update(dt)
	if map and map.update then
		map:update(dt)
	end
	if player and player.update then
		player:update(dt)
	end
end

function love.draw()
	--love.graphics.draw(background)
	love.graphics.push()
	if map and map.draw then
		map:draw(0, 0, scale, scale)
	end
	-- Draw player in same scaled space
	love.graphics.scale(scale, scale)
	if player and player.draw then
		player:draw()
	end
	love.graphics.pop()
end

