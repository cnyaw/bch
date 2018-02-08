-- Face: display name.
-- MaxCount: max instance count.
-- Hp: init hp and max hp.
-- Atk: base atk value.
-- Skill: SkillDataId list.
-- GenCd: put hero cold time, in ticks.
-- UpgradeCost: cost to upgrade lv.
-- PutCost: coin cost to add hero.

local PIECE_KING = 0
local PIECE_SHI = 1
local PIECE_XIANG = 2
local PIECE_CHE = 3
local PIECE_MA = 4
local PIECE_PAO = 5
local PIECE_ZU = 6

HeroData = {
  [1] = {Face = PIECE_ZU, MaxCount = 5, Hp = 12, Atk = 1, Skill = {1}, GenCd = 120, UpgradeCost = 90, PutCost = 1},
  [2] = {Face = PIECE_SHI, MaxCount = 2, Hp = 40, Atk = 4.44, Skill = {2, 101}, GenCd = 240, UpgradeCost = 400, PutCost = 4},
  [3] = {Face = PIECE_XIANG, MaxCount = 2, Hp = 80, Atk = 4, Skill = {2, 503}, GenCd = 240, UpgradeCost = 420, PutCost = 4},
  [4] = {Face = PIECE_MA, MaxCount = 2, Hp = 50, Atk = 9.78, Skill = {1, 601}, GenCd = 300, UpgradeCost = 880, PutCost = 9},
  [5] = {Face = PIECE_PAO, MaxCount = 2, Hp = 40, Atk = 10.67, Skill = {201, 202, 301}, GenCd = 360, UpgradeCost = 960, PutCost = 10},
  [6] = {Face = PIECE_CHE, MaxCount = 2, Hp = 60, Atk = 22.22, Skill = {1, 602}, GenCd = 420, UpgradeCost = 1250, PutCost = 16},
  [50] = {Face = PIECE_KING, MaxCount = 1, Hp = 500, Atk = 50, Skill = {501, 502}}
}
