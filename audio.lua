---@diagnostic disable: undefined-global
-- audio.lua: Centralized sound registry and helpers
-- Tweak paths, volumes, and behavior here in one place.

local Audio = {}

-- Master settings
Audio.masterVolume = 1.0  -- overall game SFX volume (0..1)

-- Registry: define all game sounds in a separate module for clarity
-- You can edit audio/registry.lua without touching code here.
local ok, reg = pcall(require, 'audio.registry')
if ok and type(reg) == 'table' then
  Audio.registry = reg
else
  -- Fallback inline registry (in case module is missing)
  Audio.registry = {
    bell_ring = {
      path = 'asets/sound/thud-sound-effect-405470.mp3',
      type = 'static',
      volume = 0.9,
      pitch = 1.0,
      loop = false,
    },
  }
end

-- Loaded LÖVE Source objects by name
Audio.sources = {}

-- Initialize and load all registered sounds
function Audio.init()
  for name, cfg in pairs(Audio.registry) do
    if not Audio.sources[name] then
      local src = love.audio.newSource(cfg.path, cfg.type or 'static')
      src:setLooping(cfg.loop == true)
      src:setPitch(cfg.pitch or 1.0)
      src:setVolume((cfg.volume or 1.0) * (Audio.masterVolume or 1.0))
      Audio.sources[name] = src
    end
  end
end

-- Update master volume (applies to already-loaded sources)
function Audio.setMasterVolume(v)
  Audio.masterVolume = math.max(0, math.min(1, tonumber(v) or 1))
  for name, src in pairs(Audio.sources) do
    local cfg = Audio.registry[name] or {}
    src:setVolume((cfg.volume or 1.0) * Audio.masterVolume)
  end
end

-- Play a named sound
-- opts: { restart=true|false, loop=true|false, volume=number, pitch=number, allowOverlap=true|false }
function Audio.play(name, opts)
  local src = Audio.sources[name]
  if not src then return end
  local cfg = Audio.registry[name] or {}
  opts = opts or {}

  -- Handle overlap by cloning a new source (for rapid SFX bursts)
  if opts.allowOverlap then
    local clone = src:clone()
    clone:setLooping(opts.loop ~= nil and opts.loop or (cfg.loop == true))
    clone:setPitch(opts.pitch or cfg.pitch or 1.0)
    local vol = (opts.volume or cfg.volume or 1.0) * (Audio.masterVolume or 1.0)
    clone:setVolume(vol)
    clone:play()
    return
  end

  if opts.restart then src:stop() end
  src:setLooping(opts.loop ~= nil and opts.loop or (cfg.loop == true))
  if opts.pitch then src:setPitch(opts.pitch) end
  if opts.volume then src:setVolume(opts.volume * (Audio.masterVolume or 1.0))
  else src:setVolume((cfg.volume or 1.0) * (Audio.masterVolume or 1.0)) end
  src:play()
end

-- Stop a named sound
function Audio.stop(name)
  local src = Audio.sources[name]
  if src then src:stop() end
end

-- Adjust per-sound volume (persists)
function Audio.setVolume(name, v)
  local cfg = Audio.registry[name]
  if not cfg then return end
  cfg.volume = math.max(0, math.min(1, tonumber(v) or cfg.volume or 1.0))
  local src = Audio.sources[name]
  if src then src:setVolume(cfg.volume * (Audio.masterVolume or 1.0)) end
end

return Audio
