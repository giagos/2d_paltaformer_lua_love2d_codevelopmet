-- data/spawn_registry.lua
-- Declarative, JSON-like registry for spawning entities from Tiled objects.
-- Keep logic out of here; this is data designers can edit.

return {
  -- Type registry: type -> factory module path and per-type defaults
  types = {
    box  = { factory = 'spawning.factories.box',  defaults = { type = 'dynamic', restitution = 0.2 } },
    ball = { factory = 'spawning.factories.ball', defaults = { restitution = 0.6, friction = 0.4 } },
    bell = { factory = 'spawning.factories.bell', defaults = {} },
    statue = { factory = 'spawning.factories.statue', defaults = {} },
     button = { factory = 'spawning.factories.button', defaults = { w = 16, h = 16 } },
  },

  -- Variants per type (sizes/options). Names should match object.name variants when using fromName.
  variants = {
    box  = {
      box1 = { w = 16, h = 16 },
      box2 = { w = 28, h = 28 },
    },
    ball = {
      ball1 = { r = 8 },
      ball2 = { r = 12 },
    },
    bell = {
      bell1 = { w = 16, h = 32 },
    },
    statue = {
      statue = {}, -- singleton/image-based; no size tuning needed now
    },
    button = {
      button1 = { w = 16, h = 16, toggle = true },
      button2 = { w = 16, h = 16, toggle = false },
    },
  },

  -- Matching rules: name-based only. Variant is derived from the full object name, and must exist.
  -- Example: name "box2" → type=box, variant="box2" (exact variant required or the object is skipped).
  rules = {
    { when = { namePrefix = 'box'  }, type = 'box',  variant = { fromName = true } },
    { when = { namePrefix = 'ball' }, type = 'ball', variant = { fromName = true } },
    { when = { namePrefix = 'bell' }, type = 'bell', variant = { fromName = true } },
     { when = { namePrefix = 'button' }, type = 'button', variant = { fromName = true } },
    { when = { namePrefix = 'statue' }, type = 'statue', variant = { fromName = true } },
  }
}
