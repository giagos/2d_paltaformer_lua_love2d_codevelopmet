-- data/player_data.lua
-- Central place for player tuning. Adjust values here instead of editing code.

local PlayerData = {
  -- Spawn
  spawn = { x = 100, y = 0 },

  -- Size (pixels)
  size = { width = 8, height = 16 },

  -- Movement (pixel units per second / second^2)
  movement = {
    maxSpeed    = 100,
    maxYSpeed   = 2000,
    acceleration= 2000,
    friction    = 3400,
    gravity     = 1500,
    jumpAmount  = -340,
  },

  -- Physics body/fixtures
  physics = {
    bodyType = 'dynamic',
    fixedRotation = true,
    gravityScale = 0,   -- 0 = ignore world gravity (we apply manual gravity)
    density = 1,
    friction = 0.8,
    restitution = 0.0,
    sensor = false,

    -- Foot sensor parameters
    foot = {
      widthFactor = 0.8,  -- 80% of body width
      height = 3,         -- pixels
      inset = 1,          -- sticks 1px into ground to detect contact
    }
  },

  -- Visuals
  color = { 0.9, 0.3, 0.3, 1 },

  -- Animations (frame timing overrides; keep nil to use defaults in code)
  animations = {
    idleFrameTime = 0.5,
    walkFrameTime = 0.09,
    jumpFrameTime = 0.10,
    fallFrameTime = 0.10,
  },
}

return PlayerData
