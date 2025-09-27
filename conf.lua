--- Minimal LÖVE configuration
---@diagnostic disable: undefined-global
-- Keep it small and compatible across LÖVE 11.x

function love.conf(t)
  -- Avoid pinning LÖVE version to prevent mismatch warnings across installations
  t.identity = "2d_platformer_empty"

  -- Window
  t.window.title = "2D Platformer"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.highdpi = true
  t.window.vsync = 0

  -- Console on Windows (shows print output)
  t.console = true

  -- Modules: keep defaults (all on) for simplicity in a starter
  -- You can disable here later for perf/size if needed
end
