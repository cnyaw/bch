local CITY_LABLE_W = 32
local CITY_LABLE_H = 20
local CITY_LABLE_TEXT_SIZE = 16
local CITY_ICON_SIZE = 32
local CITY_HITTEST_DELTA = 10

local title_lvl_id = 19
local game_lvl_id = 0
local map_obj_id = 41
local dummy_group_id = 42
local adv_city_id = 43
local battle_tex_id = 14

local curr_sel_city = nil
local curr_sel_city_obj = nil
local stage_info_obj = nil
local battle_btn_panel = nil
sel_city_id = nil

CityData = {
  [0] = {12},
  [1] = {6},
  [2] = {4, 5, 11, 12},
  [3] = {4, 12, 13, 14},
  [4] = {2, 3, 6, 14},
  [5] = {2, 6, 9},
  [6] = {1, 4, 5, 8},
  [7] = {8},
  [8] = {6, 7},
  [9] = {5},
  [10] = {11},
  [11] = {2, 10},
  [12] = {0, 2, 3},
  [13] = {3},
  [14] = {3, 4},
}

function GetCityId(o)
  return tonumber(Good.GetName(o))
end

function GetCityStageId(o)
  local id = GetCityId(o)
  local lv
  if (0 == id) then
    lv = max_stage_id
  else
    lv = city_max_stage_id[id]
  end
  return lv
end

function GetCityObj(id)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    if (GetCityId(o) == id) then
      return o
    end
  end
  return nil
end

function SetSelCity(o, stage_id)
  if (curr_sel_city == o) then
    return 1 == city_owner[GetCityId(o)]
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

function GenCityLevelInfo()
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local lv = GetCityStageId(o)
    local id = GetCityId(o)
    local clr = 0xff808080
    if (1 == city_owner[id]) then
      clr = 0xff0000ff
    end
    local bg = GenColorObj(o, CITY_LABLE_W, CITY_LABLE_H, clr)
    Good.SetPos(bg, 0, CITY_ICON_SIZE)
    local s = Good.GenTextObj(bg, string.format('%d', lv), CITY_LABLE_TEXT_SIZE)
    local w = GetTextObjWidth(s)
    Good.SetPos(s, (CITY_LABLE_W - w)/2, (CITY_LABLE_H - CITY_LABLE_TEXT_SIZE)/2)
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

function GetObjByCityId(idTarget)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local id = GetCityId(o)
    if (idTarget == id) then
      return o
    end
  end
  return -1
end

function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1
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
  local t = 0
  while (true) do
    local o = GenColorObj(map_obj_id, 3, 3, 0xfff00000)
    Good.SetPos(o, lerp(x1, x2, t) - mx, lerp(y1, y2, t) - my)
    t = t + 0.1
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

function GenBattleBtn(id)
  local x, y = Good.GetPos(battle_btn_panel)
  local ox, oy = Good.GetPos(GetCityObj(id))
  local o = Good.GenObj(battle_btn_panel, battle_tex_id)
  Good.SetPos(o, ox - x, oy - y)
  Good.SetName(o, tostring(id))
end

function GenBattleBtnPanel()
  local x, y = Good.GetPos(map_obj_id)
  local l,t,w,h = Good.GetDim(map_obj_id)
  battle_btn_panel = Good.GenDummy(-1)
  local panel = GenColorObj(battle_btn_panel, w, h, 0xa0000000)
  Good.SetPos(battle_btn_panel, x, y)
  local id = GetCityId(curr_sel_city)
  local links = CityData[id]
  for i = 1, #links do
    local idTarget = links[i]
    if (1 ~= city_owner[idTarget]) then
      GenBattleBtn(idTarget)
    end
  end
  GenBattleBtn(id)
end

function SelBattleBtn(mx, my)
  if (nil ~= battle_btn_panel) then
    local px, py = Good.GetPos(battle_btn_panel)
    local c = Good.GetChildCount(battle_btn_panel)
    for i = 1, c - 1 do                 -- Skip panel(idx=0).
      local o = Good.GetChild(battle_btn_panel, i)
      local x, y = Good.GetPos(o)
      local l,t,w,h = Good.GetDim(o)
      if (PtInRect(mx - px, my - py, x - CITY_HITTEST_DELTA, y - CITY_HITTEST_DELTA, x + CITY_ICON_SIZE + CITY_HITTEST_DELTA, y + CITY_ICON_SIZE + CITY_HITTEST_DELTA)) then
        sel_city_id = GetCityId(o)
        sel_stage_id = GetCityStageId(o)
        Good.GenObj(-1, game_lvl_id)
        return true
      end
    end
    Good.KillObj(battle_btn_panel)
    battle_btn_panel = nil
    return true
  end
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
  battle_btn_panel = nil
  GenCityLinks()
  GenCityLevelInfo()
  SetSelCity(adv_city_id, GetCityStageId(adv_city_id))
end

Map.OnStep = function(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    if (nil ~= battle_btn_panel) then
      SelBattleBtn(-1, -1)              -- Force close panel.
    else
      Good.GenObj(-1, title_lvl_id)
    end
    return
  end

  if (not Input.IsKeyPressed(Input.LBUTTON)) then
    return
  end

  local mx, my = Input.GetMousePos()

  if (SelBattleBtn(mx, my)) then
    return
  end

  -- Click on hero menu.
  if (PtInRect(mx, my, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y, HERO_MENU_OFFSET_X + HERO_MENU_W * #HeroMenu, WND_H)) then
    SelectHero(mx, my)
    return
  end

  -- Click on map.
  local x, y = Good.GetPos(map_obj_id)
  local l,t,w,h = Good.GetDim(map_obj_id)
  if (PtInRect(mx, my, x, y, x + w, y + h)) then
    if (SelectCity(mx, my)) then
      GenBattleBtnPanel(param)
    end
    return
  end
end
