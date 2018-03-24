local CITY_LABLE_W = 32
local CITY_LABLE_H = 16
local CITY_LABLE_TEXT_SIZE = 15
local CITY_ICON_SIZE = 32
local CITY_HITTEST_DELTA = 10
local CITY_UPGRADE_DISABLE_COLOR = 0xff505050

local game_lvl_id = 0
local map_obj_id = 41
local dummy_group_id = 42
local battle_tex_id = 14
local upgrade_tex_id = 44
local hero_menu_button_tex_id = 3
local coin_tex_id = 13

local curr_sel_city = nil
local curr_sel_city_obj = nil
local stage_info_obj = nil
local action_btn_panel = nil
sel_city_id = nil

CityData = {
  [1] = {4, 5, 8, 9, 15},
  [2] = {3, 4, 5, 10, 11, 12},
  [3] = {2, 4, 6, 12, 13, 14},
  [4] = {1, 2, 3, 5, 6, 8},
  [5] = {1, 2, 4, 9, 10, 22},
  [6] = {3, 4, 8, 14, 16, 17},
  [7] = {8, 15, 16},
  [8] = {1, 4, 6, 7, 15, 16},
  [9] = {1, 5, 22},
  [10] = {2, 5, 11, 20, 21, 22},
  [11] = {23, 2, 10, 12, 19, 20},
  [12] = {23, 2, 3, 11, 13},
  [13] = {3, 12, 14},
  [14] = {3, 6, 13, 17, 18},
  [15] = {1, 7, 8},
  [16] = {6, 7, 8, 17},
  [17] = {6, 14, 16, 18},
  [18] = {14, 17},
  [19] = {23, 11, 20},
  [20] = {10, 11, 19, 21},
  [21] = {10, 20, 22, 24},
  [22] = {5, 9, 10, 21, 24},
  [23] = {11, 12, 19},
  [24] = {21, 22}
}

function GetCityId(o)
  return tonumber(Good.GetName(o))
end

function GetCityStageId(o)
  local id = GetCityId(o)
  return city_stage_id[id]
end

function SetSelCity(o, stage_id)
  local id = GetCityId(o)
  if (curr_sel_city == o) then
    return GetMyPlayerId() == city_owner[id]
  end

  curr_sel_city = o
  if (nil ~= curr_sel_city_obj) then
    Good.KillObj(curr_sel_city_obj)
  end

  curr_sel_city_obj = GenColorObj(-1, 32, 32, 0x80ff0000, 'AnimSelCity')
  Good.SetPos(curr_sel_city_obj, Good.GetScreenPos(o))

  if (nil ~= stage_info_obj) then
    Good.KillObj(stage_info_obj)
  end

  stage_info_obj = GenStageInfoObj(-1, stage_id)
  Good.SetPos(stage_info_obj, 0, TILE_H/2)

  return false
end

function SelectCity(mx, my)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local x, y = Good.GetPos(o)
    if (PtInRect(mx, my, x - CITY_HITTEST_DELTA, y - CITY_HITTEST_DELTA, x + CITY_ICON_SIZE + CITY_HITTEST_DELTA, y + CITY_ICON_SIZE + CITY_HITTEST_DELTA)) then
      return SetSelCity(o, GetCityStageId(o))
    end
  end
  return false
end

function GenCityLevelInfo_i(o)
  local id = GetCityId(o)
  local clr = GetPlayerColor(city_owner[id])
  local bg = GenColorObj(o, CITY_LABLE_W, CITY_LABLE_H, clr)
  Good.SetPos(bg, 0, CITY_ICON_SIZE)
  local lv = GetCityStageId(o)
  local s = Good.GenTextObj(bg, string.format('%d', lv), CITY_LABLE_TEXT_SIZE)
  local w = GetTextObjWidth(s)
  Good.SetPos(s, (CITY_LABLE_W - w)/2, (CITY_LABLE_H - CITY_LABLE_TEXT_SIZE)/2)
end

function GenCityLevelInfo()
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    GenCityLevelInfo_i(o)
  end
end

function IsLinkExist(links, a, b)
  local tag1 = string.format('%d-%d', a, b)
  local tag2 = string.format('%d-%d', b, a)
  for _,tag in ipairs(links) do
    if (tag1 == tag or tag2 == tag) then
      return true
    end
  end
  return false
end

function GetObjByCityId(id)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    if (GetCityId(o) == id) then
      return o
    end
  end
  return -1
end

function GetCityAnchor(o)
  local x, y = Good.GetPos(o)
  local l,t,w,h = Good.GetDim(o)
  return x + w/2, y + h/2
end

function GenCityLink(o1, o2)
  local mx, my = Good.GetPos(map_obj_id)
  local x1, y1 = GetCityAnchor(o1)
  local x2, y2 = GetCityAnchor(o2)
  local len = math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
  local delta = 1 / (len / 8)
  local t = 0
  while (true) do
    local o = GenColorObj(map_obj_id, 3, 3, 0xfff00000)
    Good.SetPos(o, Lerp(x1, x2, t) - mx, Lerp(y1, y2, t) - my)
    t = t + delta
    if (1 <= t) then
      break
    end
  end
end

function GenCityLinks()
  local gened_links = {}
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local id = GetCityId(o)
    local links = CityData[id]
    for j = 1, #links do
      local idTarget = links[j]
      if (not IsLinkExist(gened_links, id, idTarget)) then
        table.insert(gened_links, string.format('%d-%d', id, idTarget))
        table.insert(gened_links, string.format('%d-%d', idTarget, id))
        GenCityLink(o, GetObjByCityId(idTarget))
      end
    end
  end
end

function GenActionBtn(id, tex_id)
  local x, y = Good.GetPos(action_btn_panel)
  local ox, oy = Good.GetPos(GetObjByCityId(id))
  local o = Good.GenObj(action_btn_panel, tex_id)
  Good.SetPos(o, ox - x, oy - y)
  Good.SetName(o, tostring(id))
  return o
end

function GetUpgradeCityCost(stage_id)
  return 100 + GetStageCombatPower(stage_id)
end

function GenUpgradeBtn(id)
  local btn_obj = GenActionBtn(id, upgrade_tex_id)
  local label_obj = Good.GenObj(btn_obj, hero_menu_button_tex_id)
  local l,t,w,h = Good.GetDim(label_obj)
  Good.SetPos(label_obj, (CITY_ICON_SIZE - w)/2, CITY_ICON_SIZE)
  local upgrade_cost = GetUpgradeCityCost(GetCityStageId(curr_sel_city))
  local s = Good.GenTextObj(label_obj, string.format('$%d', upgrade_cost), CITY_LABLE_TEXT_SIZE)
  local tw = GetTextObjWidth(s)
  Good.SetPos(s, (w - tw)/2, (h - CITY_LABLE_TEXT_SIZE)/2)
  if (upgrade_cost > coin_count) then
    Good.SetBgColor(btn_obj, CITY_UPGRADE_DISABLE_COLOR)
    Good.SetBgColor(label_obj, CITY_UPGRADE_DISABLE_COLOR)
  end
end

function GenActionBtnPanel()
  local x, y = Good.GetPos(map_obj_id)
  local l,t,w,h = Good.GetDim(map_obj_id)
  action_btn_panel = Good.GenDummy(-1)
  local panel = GenColorObj(action_btn_panel, w, h, 0xa0000000)
  Good.SetPos(action_btn_panel, x, y)
  local id = GetCityId(curr_sel_city)
  local links = CityData[id]
  for i = 1, #links do
    local idTarget = links[i]
    if (GetMyPlayerId() ~= city_owner[idTarget]) then
      GenActionBtn(idTarget, battle_tex_id)
    end
  end
  GenUpgradeBtn(id)
end

function GenUpgradeAnimObj(id)
  local o = Good.GenObj(-1, upgrade_tex_id, 'AnimFlyingUpObj')
  Good.SetPos(o, Good.GetPos(id))
end

function UpgradeCurSelCity()
  local stage_id = GetCityStageId(curr_sel_city)
  local upgrade_cost = GetUpgradeCityCost(stage_id)
  if (upgrade_cost <= coin_count) then
    coin_count = coin_count - upgrade_cost
    UpdateCoinCountObj(false)
    StageClear(GetCityId(curr_sel_city))
    Good.KillAllChild(curr_sel_city)
    GenCityLevelInfo_i(curr_sel_city)
    Good.KillObj(stage_info_obj)
    stage_info_obj = GenStageInfoObj(-1, stage_id + 1)
    Good.SetPos(stage_info_obj, 0, TILE_H/2)
    UpdateMaxStageId()
    GenUpgradeAnimObj(curr_sel_city)
    SaveGame()
  else
    return false                        -- No coin to upgrade.
  end
  return true
end

function KillActionPanel()
  if (nil ~= action_btn_panel) then
    Good.KillObj(action_btn_panel)
    action_btn_panel = nil
  end
end

function SelActionBtn(mx, my)
  if (nil ~= action_btn_panel) then
    local px, py = Good.GetPos(action_btn_panel)
    local c = Good.GetChildCount(action_btn_panel)
    for i = 1, c - 1 do                 -- Skip panel(idx=0).
      local o = Good.GetChild(action_btn_panel, i)
      local x, y = Good.GetPos(o)
      if (PtInRect(mx - px, my - py, x - CITY_HITTEST_DELTA, y - CITY_HITTEST_DELTA, x + CITY_ICON_SIZE + CITY_HITTEST_DELTA, y + CITY_ICON_SIZE + CITY_HITTEST_DELTA)) then
        sel_city_id = GetCityId(o)
        -- Click on upgrade btn.
        if (GetCityId(curr_sel_city) == sel_city_id) then
          KillActionPanel()
          if (UpgradeCurSelCity()) then
            return true
          else
            return false
          end
        -- Click on battle btn.
        else
          sel_stage_id = GetCityStageId(o)
          Good.GenObj(-1, game_lvl_id)
          return false
        end
      end
    end
  end
  KillActionPanel()
  return false
end

Map = {}

Map.OnCreate = function(param)
  -- Coin info.
  hud_obj = nil
  UpdateCoinCountObj(false)
  -- Hero menu.
  for hero_id = 1, 6 do
    local menu = HeroMenu[hero_id]
    InitHeroMenu(menu, hero_id)
    UpdateHeroMenuInfo(menu)
  end
  UpdateHeroMenuSel()
  -- Init.
  curr_sel_city = nil
  curr_sel_city_obj = nil
  stage_info_obj = nil
  action_btn_panel = nil
  GenCityLinks()
  GenCityLevelInfo()
  local o = GetObjByCityId(GetFirstCurrPlayerCityId())
  SetSelCity(o, GetCityStageId(o))
  SetPlayingStep(param)
end

function AddHarvestCoinObj(id)
  local o = Good.GenObj(-1, coin_tex_id, 'AnimFlyingUpObj')
  Good.SetPos(o, Good.GetPos(id))
end

function GetCityHarvest()
  for i = 1, MAX_CITY do
    if (GetMyPlayerId() == city_owner[i]) then
      AddHarvestCoinObj(GetObjByCityId(i))
    end
  end
  AddCoin(players_coin[my_player_idx])
  players_coin[my_player_idx] = 0
  SaveGame()
end

Map.OnStep = function(param)
  if (0 < players_coin[my_player_idx]) then
    GetCityHarvest()
  end
  param.step(param)
end

function OnMapMenu(param)
  local NextStep
  if (MyTurn()) then
    NextStep = OnMapPlaying
  else
    NextStep = OnMapAiPlaying
  end
  HandleGameMenu(param, NextStep)
end

function SetPlayingStep(param)
  if (MyTurn()) then
    param.step = OnMapPlaying
  else
    param.step = OnMapAiPlaying
  end
end

function SetNextTurn(param)
  NextTurn()
  local o = GetObjByCityId(GetFirstCurrPlayerCityId())
  SetSelCity(o, GetCityStageId(o))
  SetPlayingStep(param)
end

function OnActionPanel(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    KillActionPanel()
    param.step = OnMapPlaying
    return
  end

  if (not Input.IsKeyPressed(Input.LBUTTON)) then
    return
  end

  if (SelActionBtn(Input.GetMousePos())) then
    SetNextTurn(param)
  else
    SetPlayingStep(param)
  end
end

function OnMapPlaying(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnMapMenu
    return
  end

  if (not Input.IsKeyPressed(Input.LBUTTON)) then
    return
  end

  local mx, my = Input.GetMousePos()

  -- Click on hero menu.
  if (PtInRect(mx, my, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y, HERO_MENU_OFFSET_X + HERO_MENU_W * #HeroMenu, WND_H)) then
    SelectHero(mx, my)
    return
  end

  -- Click on map.
  if (PtInObj(mx, my, map_obj_id)) then
    if (SelectCity(mx, my)) then
      GenActionBtnPanel()
      param.step = OnActionPanel
    end
    return
  end
end

function TimeExpired(param, timer)
  if (nil == param.timer) then
    param.timer = timer
    return false
  else
    param.timer = param.timer - 1
    if (0 < param.timer) then
      return false
    else
      param.timer = nil
      return true
    end
  end
end

function OnMapAiPlaying(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnMapMenu
  end

  if (not TimeExpired(param, 40)) then
    return
  end

  SetNextTurn(param)
end
