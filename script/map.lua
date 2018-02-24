local title_lvl_id = 19
local stage_lvl_id = 14
local map_obj_id = 41
local dummy_group_id = 42

local curr_sel_city = nil
local curr_sel_city_obj = nil

function SetSelCity(o)
  if (curr_sel_city == o) then
    Good.GenObj(-1, stage_lvl_id)
    return
  end

  curr_sel_city = o
  if (curr_sel_city_obj ~= nil) then
    Good.KillObj(curr_sel_city_obj)
  end

  curr_sel_city_obj = GenColorObj(-1, 32, 32, 0x80ff0000)
  Good.SetPos(curr_sel_city_obj, Good.GetScreenPos(o))
end

function SelectCity(mx, my)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    local x, y = Good.GetPos(o)
    if (PtInRect(mx, my, x - 16, y - 16, x + 48, y + 48)) then
      SetSelCity(o)
      return
    end
  end
end

Map = {}

Map.OnCreate = function(param)
  -- Coin info.
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
