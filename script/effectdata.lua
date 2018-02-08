-- Effect: effect.
-- Type: effect type.
-- Speed: valid for EFFECT_TYPE_FLY == Type, in Ticks/Cell.
-- FlyObj: valid for EFFECT_TYPE_FLY == Type, res id.
-- Duration: valid for Effect = {PARALYSIS}.

EFFECT_DAMAGE = 1
EFFECT_HEAL = 2
EFFECT_PARALYSIS = 3

EFFECT_TYPE_STRIKE = 1
EFFECT_TYPE_FLY = 2

EffectData = {
  [1] = {Effect = EFFECT_DAMAGE, Type = EFFECT_TYPE_STRIKE},
  [2] = {Effect = EFFECT_HEAL, Type = EFFECT_TYPE_STRIKE},
  [3] = {Effect = EFFECT_DAMAGE, Type = EFFECT_TYPE_FLY, Speed = 10, FlyObj = 23},
  [4] = {Effect = EFFECT_DAMAGE, Type = EFFECT_TYPE_FLY, Speed = 10, FlyObj = 24},
  [5] = {Effect = EFFECT_PARALYSIS, Type = EFFECT_TYPE_FLY, Speed = 10, FlyObj = 25, Duration = 100}
}
