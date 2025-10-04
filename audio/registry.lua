-- audio/registry.lua: declarative list of game sounds
-- name -> { path, type('static'|'stream'), volume, pitch, loop }

return {
  bell_ring = {
    path = 'asets/sound/thud-sound-effect-405470.mp3',
    type = 'static',
    volume = 0.9,
    pitch = 1.0,
    loop = false,
  },
  bell_ring_long = {
    path = 'asets/sound/waterphone-174768.mp3',
    type = 'static',
    volume = 0.9,
    pitch = 1.0,
    loop = false,
  },
  -- add more sounds here... e.g., 'jump', 'hit', etc.
}
