# InteractableSensorHandler: Press-to-activate sensors

Wraps the existing `sensor_handler.lua` with a simple “press while inside” mechanic.

- Author sensors in Tiled like normal, inside a layer named `sensor` or `sensors`.
- Name them `interactableSensor1`, `interactableSensor2`, … (up to any number).
- Optionally add a custom property `key = "e"` (or `"f"`, etc.).
- The sensor is only considered “activated” when the player is inside and you press the expected key.

---

## Setup and integration

In your `map.lua` after STI colliders are created and Sensors are initialized, add:

```lua
local Interact = require('interactable_sensor_handler')

-- In Map:load or Map:init, after state.level:box2d_init(state.world)
Interact.init(state.world, state.level, function()
  return state.player and state.player.physics and state.player.physics.fixture or nil
end)

-- World callbacks: add these alongside Sensors.beginContact/endContact
state.world:setCallbacks(function(a,b,coll)
  Sensors.beginContact(a,b)
  Interact.beginContact(a,b)
  if state.player and state.player.beginContact then state.player:beginContact(a,b,coll) end
end, function(a,b,coll)
  Sensors.endContact(a,b)
  Interact.endContact(a,b)
  if state.player and state.player.endContact then state.player:endContact(a,b,coll) end
end)
```

Tip: If you already set callbacks elsewhere, just forward the same a/b into both `Sensors` and `Interact`.

---

## Using it in input

Call from your `love.keypressed` or your player/controller input handler:

```lua
function love.keypressed(key)
  -- Try to activate the specific sensor 1
  if Interact.onPress(1, key) then
    print('Activated interactableSensor1 with key', key)
  end

  -- Or: check any currently overlapped interactable that accepts this key
  local which = Interact.any(key)
  if which then
    print('Activated', which)
  end
end
```

You can also query simple inside state:

```lua
if Interact.isInside('interactableSensor2') then
  -- show a hint: "Press E"
  local need = Interact.getRequiredKey('interactableSensor2') or 'any'
  -- draw your UI prompt here
end
```

---

## Tiled authoring rules

- Place objects in a layer named `sensor` or `sensors`.
- Name format must be exact: `interactableSensorN` (e.g., `interactableSensor1`).
- Optional property `key` (string): when set, only that key will activate the sensor.
  - Examples: `key = "e"`, `key = "f"`, `key = "space"`.
- You can have multiple interactables in a map; the handler tracks all of them.

---

## API summary

- `Interact.init(world, map, getPlayerFixtureFn[, player])`
  - Initializes and discovers interactable sensors from the STI map.
  - `getPlayerFixtureFn` should return the player’s main fixture.
- `Interact.beginContact(a, b)`, `Interact.endContact(a, b)`
  - Forward Box2D contacts to update overlap state.
- `Interact.isInside(nameOrNumber)`
  - Returns true if the player is overlapping that interactable sensor.
- `Interact.getRequiredKey(nameOrNumber)`
  - Returns the configured key (lowercase) or nil if any key is accepted.
- `Interact.onPress(nameOrNumber, key)`
  - Returns true if the player is inside and the key matches/allowed.
- `Interact.any(key)`
  - Returns the first interactable sensor name that accepts the key, or nil.
- `Interact.onEnter[name]`, `Interact.onExit[name]`
  - Optional callbacks triggered on overlap start/end.

---

## Notes and best practices

- This module doesn’t render prompts; use `Interact.isInside()` + `getRequiredKey()` to drive your UI.
- If you also want generic sensors (like `sensor1`) keep using `sensor_handler.lua` in parallel.
- Internally, fixtures are still plain Box2D sensors; the “press to activate” logic lives in this module.
