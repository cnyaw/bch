local CITY_LABLE_W = 32
local CITY_LABLE_H = 20
local CITY_LABLE_TEXT_SIZE = 16
local CITY_ICON_SIZE = 32
local CITY_HITTEST_DELTA = 20

local title_lvl_id = 19
local game_lvl_id = 0
local map_obj_id = 41
local dummy_group_id = 42
local adv_city_id = 43

local curr_sel_city = nil
local curr_sel_city_obj = nil
local stage_info_obj = nil

function GetCityStageId(o)
  local id = tonumber(Good.GetName(o))
  local lv
  if (0 == id) then
    lv = max_stage_id
  else
    lv = city_max_stage_id[id]
  end
  return lv
end

function SetSelCity(o, stage_id)
  if (curr_sel_city == o) then
    if (adv_city_id == o) then
      sel_stage_id = stage_id
      Good.GenObj(-1, game_lvl_id)
    end
    return
  end

  curr_sel_city = o
  if (nil ~= curr_sel_city_obj) then
    Good.KillObj(curr_sel_city_obj)
  end

  curr_sel_city_obj = GenColorObj(-1, 32, 32, 0x80ff0000)
  Good.SetPos(curr_sel_city_obj, Good.GetScreenPos(o))

  if (nil ~= stage_info_obj) then
    Good.KillObj(stage_info_obj)
  end

  stage_info_obj = GenStageInfoObj(-1, stage_id)
  Good.SetPos(stage_info_obj, 0, TILE_H/2)
end

function SelectCity(mx, my)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local x, y = Good.GetPos(o)
    if (PtInRect(mx, my, x - CITY_HITTEST_DELTA, y - CITY_HITTEST_DELTA, x + CITY_ICON_SIZE + CITY_HITTEST_DELTA, y + CITY_ICON_SIZE + CITY_HITTEST_DELTA)) then
      SetSelCity(o, GetCityStageId(o))
      return
    end
  end
end

function AddCityLevelInfo()
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local lv = GetCityStageId(o)
    local id = tonumber(Good.GetName(o))
    local clr = 0xff808080
    if (0 == id) then
      clr = 0xff0000ff
    end
    local bg = GenColorObj(o, CITY_LABLE_W, CITY_LABLE_H, clr)
    Good.SetPos(bg, 0, CITY_ICON_SIZE)
    local s = Good.GenTextObj(bg, string.format('%d', lv), CITY_LABLE_TEXT_SIZE)
    local w = GetTextObjWidth(s)
    Good.SetPos(s, (CITY_LABLE_W - w)/2, (CITY_LABLE_H - CITY_LABLE_TEXT_SIZE)/2)
  end
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
  AddCityLevelInfo()
  SetSelCity(adv_city_id, GetCityStageId(adv_city_id))
end

Map.OnStep = function(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    Good.GenObj(-1, title_lvl_id)
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
  local x, y = Good.GetPos(map_obj_id)
  local l,t,w,h = Good.GetDim(map_obj_id)
  if (PtInRect(mx, my, x, y, x + w, y + h)) then
    SelectCity(mx, my)
    return
  end
end
