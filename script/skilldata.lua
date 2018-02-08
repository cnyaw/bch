-- Target: select self or enemy.
-- Type: how to choose target.
-- Dist: range of fire, in cells.
-- Cd: cold time, in ticks.
-- Atk: base atk value.
-- Buff: BuffDataId.

SKILL_TARGET_ENEMY = 1
SKILL_TARGET_SELF = 2

SKILL_TARGET_TYPE_NEAR = 1
SKILL_TARGET_TYPE_FAR = 2
SKILL_TARGET_TYPE_RANDOM = 3
SKILL_TARGET_TYPE_MIN_HP = 4
SKILL_TARGET_TYPE_SELF = 5

SkillData = {
  [1] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_NEAR, Dist = 1, Cd = 60, Atk = 1, Buff = 1},
  [2] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_NEAR, Dist = 3, Cd = 60, Atk = 1, Buff = 1},
  [101] = {Target = SKILL_TARGET_SELF, Type = SKILL_TARGET_TYPE_MIN_HP, Dist = 3, Cd = 300, Atk = 5, Buff = 2},
  [201] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_FAR, Dist = 7, Cd = 80, Atk = 5, Buff = 4},
  [202] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_RANDOM, Dist = 5, Cd = 180, Atk = 10, Buff = 4},
  [301] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_FAR, Dist = 5, Cd = 360, Atk = 2, Buff = 3},
  [501] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_RANDOM, Dist = 20, Cd = 400, Atk = 0, Buff = 5},
  [502] = {Target = SKILL_TARGET_SELF, Type = SKILL_TARGET_TYPE_SELF, Dist = 20, Cd = 1440, Atk = 0, Buff = 2},
  [503] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_RANDOM, Dist = 20, Cd = 300, Atk = 0, Buff = 6},
  [601] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_NEAR, Dist = 1, Cd = 180, Atk = 1, Buff = 1},
  [602] = {Target = SKILL_TARGET_ENEMY, Type = SKILL_TARGET_TYPE_NEAR, Dist = 1, Cd = 800, Atk = 30, Buff = 1}
}
