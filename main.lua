---@diagnostic disable: undefined-global
-- minimal STI map loader
 
local sti = require("sti")

local map
local scale = 2

function love.load()
	map = sti("tiled/map/1.lua")
end

function love.update(dt)
	if map and map.update then
		map:update(dt)
	end
end

function love.draw()
	love.graphics.push()
	love.graphics.scale(scale, scale)
	if map and map.draw then
		map:draw()
	end
	love.graphics.pop()
end

