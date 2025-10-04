---@diagnostic disable: undefined-global
-- DebugMenu: centralizes debug toggles and drawing (F2/F3/F4)
-- F2: collider overlay (world-space)
-- F3: sensor1-only overlay (world-space)
-- F4: player info panel (screen-space)

local DebugDraw = require("debugdraw")
local GameContext = require("game_context")
local Bell = require("bell")


local DebugMenu = {}

local state = {
    showColliders = false,
    showSensorsOverlay = false, -- F3: show all sensor fixtures
    showInfo = false,
    showFPS = false,
    showTransitions = false,
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
        state.showSensorsOverlay = not state.showSensorsOverlay
        print(string.format('[F3] Sensors overlay %s', state.showSensorsOverlay and 'ON' or 'OFF'))
    elseif key == "f4" or key == "f" then
        state.showInfo = not state.showInfo
        print(string.format('[%s] Debug info %s', key:upper(), state.showInfo and 'ON' or 'OFF'))
    elseif key == "f5" then
        state.showTransitions = not state.showTransitions
        print(string.format('[F5] Transitions panel %s', state.showTransitions and 'ON' or 'OFF'))
    elseif key == "f6" then
        -- F6 dedicated to FPS
        state.showFPS = not state.showFPS
        print(string.format('[F6] FPS counter %s', state.showFPS and 'ON' or 'OFF'))
    end
end

-- World-space overlays: call this inside your scaled draw block
function DebugMenu.drawWorld()
    if state.showColliders and DebugMenu.world then
        DebugDraw.drawWorldTransparent(DebugMenu.world)
    end
    if state.showSensorsOverlay and DebugMenu.map and DebugMenu.map.box2d_collision then
        DebugDraw.drawSensorsOverlay(DebugMenu.map)
    end
end

-- Screen-space overlays: call this outside scaled draw (after love.graphics.pop())
function DebugMenu.drawScreen()
    -- FPS counter (independent of player or other panels)
    if state.showFPS then
        local fps = love.timer.getFPS()
        local lines = { string.format("FPS: %d", fps) }
        -- Read bell1.isSolved via GameContext
        local bellProps = GameContext and GameContext.getEntityObjectProperties and GameContext.getEntityObjectProperties("bell1") or nil
        if bellProps and bellProps.isSolved ~= nil then
            table.insert(lines, string.format("bell1.isSolved: %s", tostring(bellProps.isSolved)))
        end

        -- Measure panel size
        local pad, lh = 6, 16
        local font = love.graphics.getFont()
        local w = 0
        for _, line in ipairs(lines) do
            local tw = font and font:getWidth(line) or 0
            if tw > w then w = tw end
        end
        local h = lh * #lines
        local x = love.graphics.getWidth() - w - pad * 2 - 8
        local y = 8

        love.graphics.push('all')
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', x, y, w + pad * 2, h + pad * 2, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        for i, line in ipairs(lines) do
            love.graphics.print(line, x + pad, y + pad + (i - 1) * lh)
        end
        love.graphics.pop()
    end

    -- Transitions inspector (F5)
    if state.showTransitions and DebugMenu.map then
        local lines = {}
        local added = 0
        -- Try to read via transitions handler cache on Map
        local mapModule = DebugMenu.map -- STI map or Map.level
        local owner = DebugMenu._mapOwner -- set from init if needed
        local transitionsState = nil
        if owner and owner.getCurrentLevel then
            -- owner is likely Map; try to access its private state via known field
            transitionsState = owner and owner._getTransitions and owner:_getTransitions() or nil
        end
        -- Header with current map path if available
        local currentPath = nil
        if transitionsState and transitionsState.destinations and transitionsState.destinations.__current then
            currentPath = tostring(transitionsState.destinations.__current) .. '.lua'
        elseif owner and owner.getCurrentLevel then
            local ok, path = pcall(function() return owner:getCurrentLevel() end)
            if ok and path then currentPath = tostring(path) .. '.lua' end
        end
        table.insert(lines, currentPath and ('Transitions (current map: ' .. currentPath .. ')') or 'Transitions (current map)')
        -- Fallback: scan box2d_collision for transitions layer
        local function pushLine(name, dest, candidates)
            local text
            if dest and dest.mapPath then
                text = string.format('%s -> %s.lua', name, dest.mapPath)
            else
                if candidates and #candidates > 0 then
                    local parts = {}
                    for i, c in ipairs(candidates) do parts[i] = c.mapPath .. '.lua' end
                    text = string.format('%s -> candidates: %s', name, table.concat(parts, ', '))
                else
                    text = string.format('%s -> (no destination)', name)
                end
            end
            table.insert(lines, text)
            added = added + 1
        end
        local destinations = nil
        local candidatesByName = nil
        if transitionsState and transitionsState.destinations then
            destinations = transitionsState.destinations
            candidatesByName = destinations.__candidates
        end
        if mapModule and mapModule.box2d_collision then
            local seen = {}
            for _, c in ipairs(mapModule.box2d_collision) do
                if c and c.fixture and c.object and c.object.layer and c.object.layer.name == 'transitions' then
                    local nm = c.object.name or ''
                    if type(nm) == 'string' and nm:match('^transition%d+$') then
                        if not seen[nm] then
                            seen[nm] = true
                            local dest = destinations and destinations[nm] or nil
                            local cands = candidatesByName and candidatesByName[nm] or nil
                            pushLine(nm, dest, cands)
                        end
                    end
                end
            end
        end

        if added == 0 then
            table.insert(lines, '(none found)')
        end

        -- Draw panel
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
        -- Continue to show player panel below if enabled
        y = y + h + 8
    end

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

-- Optional: allow Map to pass itself for deeper transitions access
function DebugMenu.setMapOwner(owner)
    DebugMenu._mapOwner = owner
end

return DebugMenu
