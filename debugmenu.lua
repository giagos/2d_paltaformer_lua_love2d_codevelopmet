---@diagnostic disable: undefined-global
-- DebugMenu: centralizes debug toggles and drawing (F2/F3/F4)
-- F2: collider overlay (world-space)
-- F3: sensor1-only overlay (world-space)
-- F4: player info panel (screen-space)

local DebugDraw = require("debugdraw")

local DebugMenu = {}

local state = {
    showColliders = false,
    showSensor1Overlay = false,
    showInfo = false,
}

function DebugMenu.init(world, map, player)
    DebugMenu.world = world
    DebugMenu.map = map
    DebugMenu.player = player
end

function DebugMenu.keypressed(key)
    if key == "f2" then
        state.showColliders = not state.showColliders
        print(string.format('[F2] Colliders %s', state.showColliders and 'ON' or 'OFF'))
    elseif key == "f3" then
        state.showSensor1Overlay = not state.showSensor1Overlay
        print(string.format('[F3] Sensor1 overlay %s', state.showSensor1Overlay and 'ON' or 'OFF'))
    elseif key == "f4" then
        state.showInfo = not state.showInfo
        print(string.format('[F4] Debug info %s', state.showInfo and 'ON' or 'OFF'))
    end
end

-- World-space overlays: call this inside your scaled draw block
function DebugMenu.drawWorld()
    if state.showColliders and DebugMenu.world then
        DebugDraw.drawWorldTransparent(DebugMenu.world)
    end
    if state.showSensor1Overlay and DebugMenu.map and DebugMenu.map.box2d_collision then
        DebugDraw.drawSensor1Overlay(DebugMenu.map)
    end
end

-- Screen-space overlays: call this outside scaled draw (after love.graphics.pop())
function DebugMenu.drawScreen()
    if not state.showInfo or not DebugMenu.player then return end
    local p = DebugMenu.player

    local meter = love.physics.getMeter()
    local bx, by = 0, 0
    if p.physics and p.physics.body then bx, by = p.physics.body:getPosition() end
    local vx, vy = p.xVel or 0, p.yVel or 0
    local grounded = p.grounded and "true" or "false"

    local lines = {
        "Player debug",
        string.format("pos (px):   x=%.1f  y=%.1f", p.x or 0, p.y or 0),
        string.format("pos (m):    x=%.2f  y=%.2f", bx, by),
        string.format("vel (px/s): x=%.1f  y=%.1f", vx, vy),
        "grounded:    " .. grounded,
    }

    local x, y, pad, lh = 8, 8, 6, 16
    local w = 0
    local font = love.graphics.getFont()
    for _, line in ipairs(lines) do
        local tw = font and font:getWidth(line) or 0
        if tw > w then w = tw end
    end
    local h = lh * #lines

    love.graphics.push('all')
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', x - pad, y - pad, w + pad * 2, h + pad * 2, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(lines) do
        love.graphics.print(line, x, y + (i - 1) * lh)
    end
    love.graphics.pop()
end

function DebugMenu.getStates()
    return state
end

return DebugMenu
