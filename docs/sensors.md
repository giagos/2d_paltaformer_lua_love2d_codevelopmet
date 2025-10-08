# SensorHandler: Triggers from Tiled "sensor" layers

Centralized trigger/sensor management for Tiled object layers named `sensor` or `sensors`.

- Forces any fixture originating from those layers to be a Box2D sensor (non‑solid)
- Supports named sensors via either object name `sensorN` or a custom property `sensorN=true`
- Tracks player overlap with each named sensor and exposes a simple API:
  - Query: `if Sensors.sensor1 then ... end`
  - Callbacks: `Sensors.onEnter.sensor1 = function(name) ... end` and `Sensors.onExit.sensor1 = function(name) ... end`

This module is read‑only from the outside; you hook into the provided `onEnter`/`onExit` tables.

---

## Quickstart (typical flow)

```lua
local Sensors = require('sensor_handler')

-- 1) Create STI map and Box2D world
map = sti('tiled/map/1.lua', { 'box2d' })
world = love.physics.newWorld(0, 1200)
map:box2d_init(world)

-- 2) Initialize SensorHandler
Sensors.init(world, map, function()
  return player and player.physics and player.physics.fixture or nil
end)

-- 3) Wire world callbacks (usually done once in your Map)
world:setCallbacks(Sensors.beginContact, Sensors.endContact)

-- 4) Register behavior
Sensors.onEnter.sensor1 = function(name) print('ENTER', name) end
Sensors.onExit.sensor1  = function(name) print('EXIT', name) end

-- 5) Read current overlap state any time
if Sensors.sensor1 then
  -- player is overlapping sensor1 now
end
```

In this project, `map.lua` already integrates these steps, so you typically only register callbacks.

---

## Authoring in Tiled

SensorHandler looks only at object layers named exactly `sensor` or `sensors`.

A fixture becomes a named trigger when either:
- The object’s name is `sensorN` (e.g., `sensor1`, `sensor42`), or
- The object has a custom property `sensorN = true`.

Notes:
- Objects in `sensor`/`sensors` layers are always made non‑solid (Box2D sensor) automatically.
- Named flags (`sensorN`) are only needed if you want to query a specific name or receive onEnter/onExit for it.

### Minimal example
- Add an Object Layer named `sensor`.
- Add a rectangle object and set its Name to `sensor1`.
- Alternatively, leave the name empty and add a custom property `sensor1` = `true`.

---

## How it works

1) When `Sensors.init(world, map, getPlayerFixture)` runs:
- It ensures objects in `sensor`/`sensors` layers are collidable so STI creates fixtures.
- After STI’s `map:box2d_init(world)`, it scans fixtures and:
  - Forces them to be `fixture:setSensor(true)` when they belong to a sensor layer or explicitly set sensor.
  - Extracts names `sensorN` from either object name or properties and caches them.
- It builds a small index so it can maintain per‑name overlap counts.

2) During physics contacts:
- `Sensors.beginContact(a, b)` / `Sensors.endContact(a, b)` are called by the world.
- If one fixture is a sensor and the other is the player fixture, SensorHandler increments/decrements the count for each discovered name on that sensor fixture.
- When a count transitions 0→1: `onEnter[name]()` is fired. When it goes 1→0: `onExit[name]()` is fired.
- `Sensors[name]` evaluates to `true` when that count is > 0 (thanks to a metatable).

---

## API Reference

- `Sensors.init(world, map, getPlayerFixtureFn, player?)`
  - `world`: Box2D world
  - `map`: STI map (must have had `map:box2d_init(world)` beforehand)
  - `getPlayerFixtureFn`: function returning the player’s main fixture
  - `player?`: optional; only used if you don’t provide a custom getter

- `Sensors.beginContact(a, b)` / `Sensors.endContact(a, b)`
  - Forward your `world:setCallbacks` to these. In this repo, `map.lua` does this for you.

- `Sensors.onEnter[name] = function(name) ... end`
  - Called once when player overlap with that named sensor starts (count 0→1).

- `Sensors.onExit[name] = function(name) ... end`
  - Called once when player overlap with that named sensor ends (count 1→0).

- `if Sensors.sensorN then ... end`
  - Boolean query for “is the player overlapping this named sensor right now?”.

Internals stored per name: `{ count = number, active = { [fixture] = true } }`.

---

## Integration in this project

- `map.lua` ensures:
  - STI is initialized, and sensor layers are made collidable
  - Sensor fixtures get their properties merged and are converted to true Box2D sensors
  - World callbacks forward to SensorHandler
- You can just register callbacks anywhere after `Sensors.init` (e.g., in `map.lua` or a gameplay module):

```lua
local Sensors = require('sensor_handler')
Sensors.onEnter.sensor2 = function() print('Sensor2 ENTER') end
Sensors.onExit.sensor2  = function() print('Sensor2 EXIT')  end
```

For visualization, `debugdraw.lua` includes overlays to draw only sensor fixtures (toggled in `debugmenu.lua`).

---

## Edge cases & gotchas

- Layer names must be exactly `sensor` or `sensors` (case‑sensitive).
- Fixtures outside these layers may be sensors (via physics flags) but do not participate in named enter/exit unless they are in a sensor layer.
- If your callbacks don’t fire:
  - Ensure your player fixture getter returns the correct fixture
  - Ensure the object is actually in a `sensor`/`sensors` layer
  - Ensure the object name/property is a valid `sensorN`
- Counts are per‑fixture: overlapping multiple fixtures with the same name increases the count; you get a single enter at 0→1 and a single exit at 1→0.
- Callbacks persist across map reloads: they’re stored on the module and not cleared by `init`.

---

## Example: open a door while inside sensor3

```lua
local Sensors = require('sensor_handler')

Sensors.onEnter.sensor3 = function()
  GameContext.setEntityProp('door1', 'open', true)
end

Sensors.onExit.sensor3 = function()
  GameContext.setEntityProp('door1', 'open', false)
end

function update(dt)
  if Sensors.sensor3 then
    -- keep something active while inside
  end
end
```

---

## Troubleshooting

- “My sensor doesn’t show up” → Check you placed the object on a layer named `sensor` or `sensors`.
- “Enter/Exit never fires” → Verify `world:setCallbacks` includes `Sensors.beginContact` / `Sensors.endContact`.
- “I named it ‘Sensor1’ and it doesn’t work” → Name must match `^sensor%d+$` (lowercase `sensor`). Alternatively, add a custom property `sensor1=true`.
- “Multiple enters/exits spam” → This is expected if you have multiple fixtures named the same; the handler collapses that into a single state by counting.

---

## Related files

- `sensor_handler.lua` — The implementation
- `map.lua` — Initialization and world callback wiring
- `debugdraw.lua` / `debugmenu.lua` — Overlays to visualize sensors
- `game_context.lua` — Utility to read/write entity properties (often used from sensor callbacks)
