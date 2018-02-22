local title_lvl_id = 19
local stage_lvl_id = 14

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
end

Map.OnStep = function(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    Good.GenObj(-1, title_lvl_id)
    return
  end

  if (not Input.IsKeyPressed(Input.LBUTTON)) then
    return
  end

  local x, y = Input.GetMousePos()
  if (PtInRect(x, y, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y, HERO_MENU_OFFSET_X + HERO_MENU_W * #HeroMenu, WND_H)) then
    SelectHero(x, y)
  else
    Good.GenObj(-1, stage_lvl_id)
  end
end
