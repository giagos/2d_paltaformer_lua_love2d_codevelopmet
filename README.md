# 2d_paltaformer_lua_love2d_codevelopmet

A 2D platformer built with [LÖVE](https://love2d.org/) (Lua), using Box2D physics and levels made in [Tiled](https://www.mapeditor.org/), loaded with STI (Simple Tiled Implementation).

## Preview

![Demo gameplay](./mis/love_kvWX7bSqY6.gif)

## Run

1. Install LÖVE 11.x from https://love2d.org/
2. In this folder, run:

```powershell
love .
```

STI is already included in the [`sti/`](./sti) folder, so no extra setup is needed.

## Controls

| Key | Action |
| --- | --- |
| A / D or ← / → | Move |
| W / ↑ / Space | Jump |
| E (or F, per object) | Interact (doors, buttons, bells) |
| R | Reset player to (64, 64) |
| Esc | Quit |

### Debug keys

| Key | Action |
| --- | --- |
| F1 | Camera panel (+ / − to change camera box size) |
| F2 | Collider overlay |
| F3 | Sensors overlay |
| F4 | Debug info |
| F5 | Interactables hover |
| F6 | FPS counter |
| F7 | Level transitions panel |

## Project layout

- `main.lua` – entry point
- `map.lua` – loads levels, physics world and entities
- `player.lua`, `door.lua`, `button.lua`, `bell.lua`, `statue.lua`, ... – game entities
- `spawning/` and `data/spawn_registry.lua` – registry-driven entity spawning
- `tiled/` – Tiled project and maps
- `asets/` – sprites and sounds
- `docs/` – guides

## Docs

- [Adding new entities](./docs/adding_entities.md)
- [Spawning](./docs/spawning.md)
- [Factories](./docs/factories.md)
- [Sensors](./docs/sensors.md)
- [Interactable sensors](./docs/interactable_sensors.md)
- [Save state](./docs/save_state.md)
- [Level design guide](./docs/level_design_guide.md)
