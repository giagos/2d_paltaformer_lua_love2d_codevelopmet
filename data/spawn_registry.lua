-- data/spawn_registry.lua
-- Declarative, JSON-like registry for spawning entities from Tiled objects.
-- Keep logic out of here; this is data designers can edit.

return {
  -- Type registry: type -> factory module path and per-type defaults
  types = {
    box  = { factory = 'spawning.factories.box',  defaults = { type = 'dynamic', restitution = 0.2 } },
    ball = { factory = 'spawning.factories.ball', defaults = { restitution = 0.6, friction = 0.4 } },
    bell = { factory = 'spawning.factories.bell', defaults = {} },
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
    }
  },

  -- Matching rules. Prefer object.type; fall back to name prefixes for legacy maps.
  rules = {
    { when = { type = 'box'  },  type = 'box',  variant = { fromName = true } },
    { when = { type = 'ball' },  type = 'ball', variant = { fromName = true } },
    { when = { type = 'bell' },  type = 'bell', variant = { fromName = true } },

    -- Fallbacks by name prefix (e.g., name "box2" → type=box, variant="box2")
    { when = { namePrefix = 'box'  }, type = 'box',  variant = { fromName = true } },
    { when = { namePrefix = 'ball' }, type = 'ball', variant = { fromName = true } },
    { when = { namePrefix = 'bell' }, type = 'bell', variant = { fromName = true } },
  }
}
