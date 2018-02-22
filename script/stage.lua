local MENU_ITEM_W = WND_W
local MENU_ITEM_H = 31
local MAX_MENU_ITEM = 20

local game_lvl_id = 0
local map_lvl_id = 39
local combat_id = 15

LoadGame()

Stage = {}

Stage.OnCreate = function(param)
  -- Display coin info.
  UpdateCoinCountObj(false)
  -- Gen menu.
  param.menu_root_obj = Good.GenDummy(-1)
  param.menu_obj = Good.GenDummy(param.menu_root_obj)
  local first_stage_id = GetFirstStageId()
  for stage_id = first_stage_id, first_stage_id + MAX_MENU_ITEM - 1 do
    local o = AddMenuItem(param, stage_id)
  end
  local menu_offset_y = (first_stage_id - 1) * MENU_ITEM_H
  Good.SetPos(param.menu_root_obj, 0, -menu_offset_y + TILE_H/2)
  -- Gen sel stage obj.
  sel_stage_id = max_stage_id
  GenSelStageObj(param, sel_stage_id)
end

Stage.OnStep = function(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    Good.GenObj(-1, map_lvl_id)
    return
  end
  -- Handle sel menu item.
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    local menu_x, menu_y = Good.GetPos(param.menu_root_obj)
    local mouse_x, mouse_y = Input.GetMousePos()
    local first_stage_id = GetFirstStageId()
    local sel_id = math.floor((-menu_y + mouse_y) / MENU_ITEM_H) + 1
    if (first_stage_id <= sel_id and max_stage_id >= sel_id) then
      if (sel_stage_id ~= sel_id) then
        sel_stage_id = sel_id
        GenSelStageObj(param, sel_id)
      else
        Good.GenObj(-1, game_lvl_id)
      end
    end
  end
end

function AddMenuItem(param, stage_id)
  -- Stage id.
  local t_color = 0xffffffff
  if (max_stage_id < stage_id) then
    t_color = 0xff505050
  end
  --local stage = StageData[stage_id]
  local stage = GetStageData(stage_id)
  local menu_item = Good.GenTextObj(param.menu_obj, string.format('%d', stage_id), TILE_W/2)
  SetTextObjColor(menu_item, t_color)
  Good.SetPos(menu_item, 0, (stage_id - 1) * MENU_ITEM_H + (MENU_ITEM_H - TILE_H/2)/2)
  local cp = Good.GenObj(menu_item, combat_id, '')
  local scale = (TILE_W/2) / 32
  Good.SetScale(cp, scale, scale)
  Good.SetPos(cp, TILE_W, 0)
  local cp_text = Good.GenTextObj(menu_item, string.format('%d', GetStageCombatPower(stage_id, stage.Heroes)), TILE_W/2)
  Good.SetPos(cp_text, TILE_W + TILE_W/2, 0)
  SetTextObjColor(cp_text, t_color)
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
    SetTextObjColor(o2, t_color)
    offset = offset + 1
  end
  return menu_item
end

function GetEnemyLevel(stage_id)
  return 1 + stage_id / 15
end

function GetFirstStageId()
  return math.max(1, max_stage_id - MAX_MENU_ITEM + 1)
end

function GenSelStageObj(param, id)
  if (nil ~= param.sel_stage_obj) then
    Good.KillObj(param.sel_stage_obj)
  end
  local y = (id - 1) * MENU_ITEM_H
  local sel_stage_obj = Good.GenObj(param.menu_root_obj, -1, 'AnimSelMenuItem')
  Good.SetAnchor(sel_stage_obj, 0.5, 0.5)
  Good.SetScale(sel_stage_obj, 0, 0)
  Good.SetPos(sel_stage_obj, 0, y)
  Good.SetDim(sel_stage_obj, 0, 0, WND_W, MENU_ITEM_H)
  Good.SetBgColor(sel_stage_obj, 0xffff6a00)
  Good.AddChild(param.menu_root_obj, sel_stage_obj, 0)
  param.sel_stage_obj = sel_stage_obj
end

function GetStageCombatPower(stage_id, heroes)
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
