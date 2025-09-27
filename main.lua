---@diagnostic disable: undefined-global
-- minimal STI map loader
 
local sti = require("sti")

local map
local scale = 2

function love.load()
	map = sti("tiled/map/1.lua",{"box2d"})
	world = love.physics.newWorld(0,0)
	map:box2d_init(world)
	map.layers.solid.visible = false
	background = love.graphics.newImage()
end

function love.update(dt)
	if map and map.update then
		map:update(dt)
	end
end

function love.draw()
	love.graphics.draw(background)
	love.graphics.push()
	if map and map.draw then
		map:draw(0, 0, scale, scale)
	end
	love.graphics.pop()
end

