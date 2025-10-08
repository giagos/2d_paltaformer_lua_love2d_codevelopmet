-- spawning/factories/statue.lua
-- Factory for the singleton statue/flame

---@diagnostic disable: undefined-global
local M = {}

function M.create(world, x, y, obj, cfg, ctx)
  local statue = require('statue')
  statue.load(x, y)
  return statue
end

return M
