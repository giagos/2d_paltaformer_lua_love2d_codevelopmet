# 2d_paltaformer_lua_love2d_codevelopmet


Minimal LÖVE 2D starter with Tiled map loading via STI.

## Run

1. Install LÖVE 11.x from https://love2d.org/
2. In this folder, run:

```powershell
love .
```

## STI (Simple Tiled Implementation)

To render `tiled/map/1.lua`, add STI to the project:

- Option A: place STI in `libs/sti` so it can be required as `libs.sti`
- Option B: add STI to your Lua path so `require('sti')` works

Repo: https://github.com/karai17/Simple-Tiled-Implementation

After adding STI, the project will load and draw `tiled/map/1.lua` automatically.

