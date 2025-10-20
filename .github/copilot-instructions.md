# Copilot instructions for this repo (LÖVE2D + STI platformer)

These notes give AI coding agents the minimum context to be immediately productive in this codebase. Keep guidance specific to this project’s patterns; avoid generic refactors.

## Big picture

- Engine: LÖVE 11.x. Run from the repo root with: love .
- Core loop lives in `main.lua` and delegates systems to `map.lua`.
- Map and physics:
  - STI loads Tiled maps (`tiled/map/N.lua`) with the Box2D plugin.
  - Physics units: `love.physics.setMeter(1)` so 1 pixel == 1 meter. Do not rescale physics; only visuals scale.
  - Visual scale is controlled by `Map:getScale()` and applied in draw only.
- Ownership: `map.lua` is the single owner of the STI level, Box2D world, entities, sensors, and transitions. New gameplay should integrate via Map hooks, not global state.

## Run + debug workflow

- Windows PowerShell: install LÖVE, then run from repo root: `love .`
- Controls (see `main.lua` and `debugmenu.lua`):
  - F1 camera panel, F2 collider overlay, F3 sensor overlay, F4 player info, F5 interactables hover, F6 FPS, F7 transitions inspector.
  - R reset player to (64, 64); ESC quit. Mouse: drag chain anchors in world.
- Debug overlays: world-space overlays render inside Map’s scaled draw via `Map:setWorldOverlayDrawFn`; screen-space panels render after pop.

## Architecture and data flow

- `map.lua` responsibilities:
  - Load STI level and create Box2D world; set world callbacks; spawn entities.
  - Manage level transitions and sensor systems; expose getters (`getWorld`, `getLevel`, `getPlayer`, `getScale`).
  - Keep a flat `state.entities` updated/drawn; forwards input to entities; first true from `:keypressed` short-circuits further handling.
- `game_context.lua` provides read/write helpers into the live STI map objects (layers and objects in the entity layer). Use this to query/set properties rather than mutating entities directly.
- `save_state.lua` overlays persisted per-map per-entity props onto the live STI data after a map loads. In this repo persistence is off by default (session-only). Enable with `SaveState.setPersistent(true)` before `SaveState.init` if you need disk saves.
- `spawning/spawner.lua` reads Tiled “entity” layer objects and, using `data/spawn_registry.lua`, calls factories in `spawning/factories/*` to build instances. Merge order: `types.defaults <- variants[preset] <- object.properties`.
- Input and contacts:
  - `map.lua`’s world:setCallbacks forwards to: player, `sensor_handler.lua`, `interactable_sensor_handler.lua`, and `level_transitions_handler.lua`.
  - Sensors are read-only state machines, exposed via metatables (e.g., `Sensors.sensor1`).

## Tiled authoring conventions (important!)

- Layers by name:
  - `solid` (STI colliders), `ground` (tiles), `entity` (spawned objects), `sensor`/`sensors` (triggers), `transitions` (map links).
- Sensors:
  - Name as `sensorN` or set property `sensorN = true` on any object in `sensor`/`sensors` layers. Module forces fixtures to sensors and tracks enter/exit per name.
- Interactable sensors (press-to-activate): name objects `interactableSensorN` in `sensor`/`sensors`; optional property `key = "e"` etc. Query via `Interact.isInside`, activate via `Interact.onPress(N, key)`.
- Transitions:
  - In `transitions` layer, add rectangles named `transitionN`. The handler scans all maps under `tiled/map` and builds name-based links.
  - Optional per-object overrides: set `destMap` (e.g., `tiled/map/3` or `3`) and optional `destName` to pick a specific transition in the destination map.
  - Spawn position is computed based on entry direction and rectangle orientation (height > width = horizontal transition).
- Entities:
  - Place in `entity` layer. Either:
    - Set object Type to a registered type (`data/spawn_registry.lua`), or
    - Name using a rule’s `namePrefix` with exact variant keys (e.g., `box1`, `door2`).

## Spawning rules and factories

- Registry lives in `data/spawn_registry.lua`:
  - `types`: `type -> { factory, defaults }`
  - `variants[type][variantKey]`: presets (e.g., sizes/flags)
  - `rules`: name-based mapping; if `variant.fromName=true` the object name must exactly match a declared variant.
- Factories in `spawning/factories/*.lua` must export `create(world, x, y, obj, cfg, ctx)` and return an instance (e.g., `Door.new(...)`). Use the template `_template_generic.lua`.
- Example: `door.lua` reads live state from `GameContext` and persists via `SaveState.setEntityPropCurrent(name, 'isOpen', true)`; it toggles its fixture sensor flag depending on `isOpen`.

## Save/persisted state

- Map IDs: use the base path (e.g., `tiled/map/2`). `SaveState.setCurrentMapId(Map:getCurrentLevel())` is applied on load and after switches.
- Apply overlay after each load/switch: `SaveState.applyToMapCurrent()` (Map does this).
- By default `SaveState.persistent = false` (session-only). To persist across runs, call `SaveState.setPersistent(true)` before `SaveState.init('save/slot1.lua')`, then `SaveState.save()` at your chosen cadence.

## Audio

- Centralized in `audio.lua` with declarative entries in `audio/registry.lua`.
- Use `Audio.init()` once (done in `main.lua`), then `Audio.play('bell_ring', { restart=true })`. Per-sound settings live in the registry.

## Camera and drawing

- `camera.lua` draws a world-space guide rectangle that smoothly follows the player. Size/Y-offset adjustable via F1 panel and `Camera.setBoxScale` / `Camera.setYOffset`.
- Draw order (`main.lua`): `Map:draw()` does background and world (scaled); camera rectangle is drawn inside world scaling; screen-space debug panels are drawn last.

## Dos and don’ts for edits

- Do: keep physics in pixel units; do not change the global meter or scale physics to “fix” visual scale.
- Do: use `GameContext` and `SaveState` to modify entity state; this keeps state visible to other systems and debuggers.
- Do: add new gameplay via factories and the spawn registry; avoid hardcoding spawns in `map.lua`.
- Don’t: mutate STI internals from random modules; if you must, expose it via `map.lua` or `game_context.lua`.
- Don’t: change global visual scale for debug overlays; pass an overlay fn to `Map:setWorldOverlayDrawFn` instead.

## Pointers to key files

- Entry/runtime: `main.lua`, `conf.lua`
- Orchestrator: `map.lua`
- Context/state overlay: `game_context.lua`, `save_state.lua`
- Spawning: `spawning/spawner.lua`, `data/spawn_registry.lua`, `spawning/factories/*`
- Sensors: `sensor_handler.lua`, `interactable_sensor_handler.lua`
- Transitions: `level_transitions_handler.lua`
- Player and examples: `player.lua`, `door.lua`, `button.lua`, `box.lua`, `bell.lua`, `statue.lua`
- Debug: `debugmenu.lua`, `debugdraw.lua`, `camera.lua`

---
Questions or unclear areas to refine in these instructions:
- Should persistence be enabled by default for your workflow?
- Any additional non-obvious run tasks (packaging, asset export) you want documented?
- Do you want stricter rules for variants (e.g., allow fallback to `variant` property when `fromName` is set)?
