local MENU_ITEM_H = 31

local combat_tex_id = 15

function GenStageInfoObj(parent, stage_id)
  -- Stage id.
  local stage = GetStageData(stage_id)
  local menu_item = Good.GenTextObj(parent, string.format('%d', stage_id), TILE_W/2)
  Good.SetPos(menu_item, 0, (stage_id - 1) * MENU_ITEM_H + (MENU_ITEM_H - TILE_H/2)/2)
  local cp = Good.GenObj(menu_item, combat_tex_id, '')
  local scale = (TILE_W/2) / 32
  Good.SetScale(cp, scale, scale)
  Good.SetPos(cp, TILE_W, 0)
  local cp_text = Good.GenTextObj(menu_item, string.format('%d', GetStageCombatPower_i(stage_id, stage.Heroes)), TILE_W/2)
  Good.SetPos(cp_text, TILE_W + TILE_W/2, 0)
  -- Stage heroes info.
  local offset = -3
  for i = 1, #stage.Heroes do
    local hero_config = stage.Heroes[i]
    local hero_id = hero_config[1]
    local hero_count = hero_config[2]
    local hero = HeroData[hero_id]
    local o2 = GenHeroPieceObj(menu_item, hero.Face, false, '')
    Good.SetScale(o2, 0.5, 0.5)
    Good.SetPos(o2, WND_W/2 + TILE_W/2 * offset, 0)
    offset = offset + 1
    o2 = Good.GenTextObj(menu_item, string.format('%d', hero_count), TILE_W/2)
    Good.SetPos(o2, WND_W/2 + TILE_W/2 * offset, 0)
    offset = offset + 1
  end
  return menu_item
end

function GetEnemyLevel(stage_id)
  return 1 + stage_id / 15
end

function GetStageCombatPower_i(stage_id, heroes)
  local p = 0
  for i = 1, #heroes do
    local hero_config = heroes[i]
    local hero_id = hero_config[1]
    local hero = HeroData[hero_id]
    local hero_count = hero_config[2]
    p = p + hero_count * GetLevelValue(GetEnemyLevel(stage_id), hero.Atk)
  end
  return p
end

function GetStageCombatPower(stage_id)
  local stage = GetStageData(stage_id)
  return GetStageCombatPower_i(stage_id, stage.Heroes)
end

function GetStageData(stage_id)
  -- Heroes: hero list and number of the sage. {HeroDataId, Number, Probability}, Each HeroDataId in the list is unique.
  -- Wave: {Time,HeroCount}, period time of each wave(in sec) and how many heroes of each wave.
  -- Coin: {Min,Max}, drop coin range of each hero.
  local stage = {}
  stage_id = stage_id - 1
  local coin = 1 + math.floor(stage_id / 15)
  local range = 1 + math.floor(stage_id / 25)
  stage.Coin = {coin, coin + range}
  local wave_time = math.max(5, 10 - math.floor(stage_id / 10))
  local hero_count = math.min(9, 2 + math.floor(stage_id / 20))
  stage.Wave = {wave_time, hero_count}
  stage.Heroes = {}
  for hero_id = 1, 6 do
    local count = math.min(50, math.floor((1 + stage_id) / (1 + 4 * (hero_id - 1))))
    if (0 < count) then
      table.insert(stage.Heroes, {hero_id, count})
    end
  end
  return stage
end
