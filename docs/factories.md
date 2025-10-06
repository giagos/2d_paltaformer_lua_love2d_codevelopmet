# Writing factories for the spawner

Factories are tiny adapters that turn Tiled objects into live game entities. They keep map/spawn logic decoupled from your entity modules.

This guide shows:
- The factory contract and inputs
- A minimal template
- Examples (box, ball, bell)
- How to add a new type (registry + rules)
- Best practices

---

## Factory contract

Each factory is a Lua module returning a table with a single function:

- `create(world, x, y, obj, cfg, ctx) -> instance`

Parameters:
- `world` — love.physics World (already created by Map)
- `x, y` — object center in pixels (Spawner computed these for you)
- `obj` — raw Tiled object (fields: name, type, width, height, properties)
- `cfg` — merged configuration (defaults + variant + obj.properties)
- `ctx` — extra context: `{ registry, level, map }` (optional)

Return:
- A live entity instance (table/object). This can be whatever your module returns
  (e.g., `Box.new(...)`), or a simple table if you’re still prototyping.

---

## Minimal template

Save this as `spawning/factories/mytype.lua` (or copy `_template_generic.lua`).

```lua
---@diagnostic disable: undefined-global
local M = {}

function M.create(world, x, y, obj, cfg, ctx)
  cfg = cfg or {}
  -- If you already have a module, delegate to it here:
  -- local MyType = require('mytype')
  -- return MyType.new(world, x, y, cfg)

  -- Placeholder: show something visible until you wire the real thing
  local body = love.physics.newBody(world, x, y, cfg.type or 'dynamic')
  local w, h = cfg.w or obj.width or 16, cfg.h or obj.height or 16
  local shape = love.physics.newRectangleShape(w, h)
  local fixture = love.physics.newFixture(body, shape)
  fixture:setUserData({ kind = 'mytype', name = obj.name, properties = cfg })
  return { body = body, shape = shape, fixture = fixture, kind = 'mytype', name = obj.name }
end

return M
```

---

## Examples from this repo

- `spawning/factories/box.lua`
  - Adapts to `Box.new(world, x, y, w, h, opts)` and passes `cfg` as `opts`.
- `spawning/factories/ball.lua`
  - Adapts to `Ball.new(world, x, y, r, opts)`.
- `spawning/factories/bell.lua`
  - Adapts to `bell.new(world, x, y, w, h, opts)`.

All three include placeholder fallbacks so the game still runs if the module can’t be required.

---

## Registering a new type

1) Create the factory file, e.g. `spawning/factories/spike.lua`.

2) Edit `data/spawn_registry.lua`:

```lua
return {
  types = {
    spike = { factory = 'spawning.factories.spike', defaults = { lethal = true } },
  },
  variants = {
    spike = {
      spike1 = { w = 16, h = 8 },
      spike2 = { w = 32, h = 8 },
    }
  },
  rules = {
    { when = { namePrefix = 'spike' }, type = 'spike', variant = { fromName = true } },
  }
}
```

3) In Tiled, place objects in the `entity` layer named `spike1`, `spike2`, etc.

The Spawner will:
- Match by name prefix (spike)
- Derive the variant from the full object name (spike1, spike2)
- Require your factory and call `create(...)`

---

## Best practices

- Keep factories thin
  - Delegate to your real entity module as soon as it exists.
  - Use the placeholder only while prototyping.
- Treat `cfg` as your entity’s constructor options
  - Introduce new fields in `defaults`/`variants` instead of hardcoding in factories.
- Exact-name variants
  - If the object’s name doesn’t match a declared variant, it won’t spawn. This helps catch typos.
- UserData tagging
  - Set `fixture:setUserData({ kind='...', name=obj.name, properties=cfg })` for debug overlays and sensors.
- SaveState and properties
  - SaveState overlays are applied before spawning, so factories can look at `cfg` or `obj.properties` to react to current state.
- Logging (optional)
  - During setup, print when a factory is hit to confirm wiring. Remove noisy logs later.

---

## Troubleshooting

- Nothing spawns: check the object name matches a declared variant (case-insensitive in our setup; we lowercase for matching).
- Wrong size: confirm `variants[type][name]` has `w/h` (rect) or `r` (circle), and your factory uses them.
- Module not found: placeholder will be used; verify your require path and file location.
- Need circles: set `cfg.shape='circle'` and `cfg.r` in the registry variant; tweak the factory accordingly.
