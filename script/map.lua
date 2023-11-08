local PLAYER_LABLE_W = 60
local CITY_LABLE_W = 40
local CITY_LABLE_H = 16
local CITY_LABLE_TEXT_SIZE = 15
local CITY_ICON_SIZE = 32
local CITY_HITTEST_DELTA = 10

local game_lvl_id = 0
local map_obj_id = 41
local dummy_group_id = 42
local battle_tex_id = 14
local coin_tex_id = 13
local round_obj_id = 46
local upgrade_tex_id = 16
local map_tex_id = 38

local map_tex_updated = false
local curr_sel_city = nil
local anim_sel_city_obj = nil
local action_btn_panel = nil
local players_info_obj = nil
local city_obj_map = nil
local city_obj_dummy_map = nil

my_sel_city_id = nil
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

function SetSelCity(o)
  local id = GetCityId(o)
  local dummy = GetCityObjDummyById(id)
  if (curr_sel_city == dummy) then
    return GetMyPlayerId() == city_owner[id]
  end

  -- Sel change.
  if (nil ~= curr_sel_city) then
    Good.SetScript(curr_sel_city, '')
    Good.SetScale(curr_sel_city, 1, 1)
  end

  curr_sel_city = dummy
  Good.SetScript(curr_sel_city, 'AnimSelCity')
  GenHeroMenu(id, GetMyPlayerId() ~= city_owner[id])

  return false
end

function SelCity(mx, my)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = GetCityObj(i)
    local x, y = Good.GetPos(o)
    if (PtInRect(mx, my, x - CITY_HITTEST_DELTA, y - CITY_HITTEST_DELTA, x + CITY_ICON_SIZE + CITY_HITTEST_DELTA, y + CITY_ICON_SIZE + CITY_HITTEST_DELTA)) then
      return SetSelCity(o)
    end
  end
  return false
end

function GenCityInfo_i(o)
  local id = GetCityId(o)
  local clr = GetPlayerColor(city_owner[id])
  Good.SetBgColor(o, clr)
  local bg = GenColorObj(o, CITY_LABLE_W, CITY_LABLE_H, clr)
  Good.SetAnchor(bg, 0.5, 0.5)
  Good.SetPos(bg, (CITY_ICON_SIZE - CITY_LABLE_W)/2, CITY_ICON_SIZE)
  local combat_power = GetHeroCombatPower(id)
  local s = Good.GenTextObj(bg, string.format('%d', combat_power), CITY_LABLE_TEXT_SIZE)
  local w = GetTextObjWidth(s)
  Good.SetPos(s, (CITY_LABLE_W - w)/2, (CITY_LABLE_H - CITY_LABLE_TEXT_SIZE)/2)
end

function GenCityInfo()
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = GetCityObj(i)
    GenCityInfo_i(o)
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

function GetCityObj(i)
  return city_obj_map[i]
end

function GetCityObjById(id)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = GetCityObj(i)
    if (GetCityId(o) == id) then
      return o
    end
  end
  return -1
end

function GetCityObjDummyById(id)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = GetCityObj(i)
    if (GetCityId(o) == id) then
      return city_obj_dummy_map[i]
    end
  end
  return -1
end

function DrawCityLinks()
  if (map_tex_updated) then
    return
  end

  local tw, th = Resource.GetTexSize(map_tex_id)
  local canvas = Graphics.GenCanvas(tw, th)
  if (-1 >= canvas) then
    return
  end

  Graphics.DrawImage(canvas, 0, 0, map_tex_id, 0, 0, tw, th)

  local gened_links = {}
  local mx, my = Good.GetPos(map_obj_id)
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = GetCityObj(i)
    local id = GetCityId(o)
    local links = CityData[id]
    for j = 1, #links do
      local idTarget = links[j]
      if (not IsLinkExist(gened_links, id, idTarget)) then
        table.insert(gened_links, string.format('%d-%d', id, idTarget))
        table.insert(gened_links, string.format('%d-%d', idTarget, id))
        DrawCityLink(canvas, mx, my, o, GetCityObjById(idTarget))
      end
    end
  end

  Resource.UpdateTex(map_tex_id, 0, 0, canvas, 0, 0, tw, th)
  Graphics.KillCanvas(canvas)

  map_tex_updated = true
end

function GenActionBtn(id, tex_id)
  local x, y = Good.GetPos(action_btn_panel)
  local ox, oy = Good.GetPos(GetCityObjById(id))
  local o = Good.GenObj(action_btn_panel, tex_id)
  Good.SetPos(o, ox - x, oy - y)
  Good.SetName(o, tostring(id))
  return o
end

function GenActionBtnPanel()
  local l,t,w,h = Good.GetDim(map_obj_id)
  action_btn_panel = Good.GenDummy(-1)
  local panel = GenColorObj(action_btn_panel, w, h, 0xa0000000)
  Good.SetPos(panel, Good.GetPos(map_obj_id))
  local o = Good.GetChild(curr_sel_city, 0)
  local id = GetCityId(o)
  local links = CityData[id]
  for i = 1, #links do
    local idTarget = links[i]
    if (GetMyPlayerId() ~= city_owner[idTarget]) then
      GenActionBtn(idTarget, battle_tex_id)
    end
  end
end

function InitCityObjDummyMap()
  local m = {}
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = GetCityObj(i)
    local dummy = Good.GenDummy(dummy_group_id)
    Good.AddChild(dummy, o)
    m[i] = dummy
  end
  return m
end

function InitCityObjMap()
  local m = {}
  local c = Good.GetChildCount(dummy_group_id)
  for i = 0, c - 1 do
    local o = Good.GetChild(dummy_group_id, i)
    Good.SetAnchor(o, 0.5, 0.5)
    m[i] = o
  end
  return m
end

function UpdateCityInfo(o)
  Good.KillAllChild(o)
  GenCityInfo_i(o)
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
        local co = Good.GetChild(curr_sel_city, 0)
        my_sel_city_id = GetCityId(co)
        sel_city_id = GetCityId(o)
        Good.GenObj(-1, game_lvl_id)
        return false
      end
    end
  end
  KillActionPanel()
  return false
end

Map = {}

Map.OnCreate = function(param)
  -- Coin info.
  coin_obj = nil
  hud_obj = nil
  UpdateCoinCountObj()
  -- Init.
  curr_sel_city = nil
  anim_sel_city_obj = nil
  stage_info_obj = nil
  action_btn_panel = nil
  anim_game_over_obj = nil
  players_info_obj = nil
  city_obj_map = InitCityObjMap()
  city_obj_dummy_map = InitCityObjDummyMap()
  check_game_over_flag = GetCheckGameOverFlag()
  UpdateRoundInfo()
  UpdatePlayersRankInfo()
  DrawCityLinks()
  GenCityInfo()
  local o = GetCityObjById(GetFirstCurrPlayerCityId())
  SetSelCity(o)
  SetPlayingStep(param)
end

function GenHarvestCoinAnimObj(id)
  local o = Good.GenObj(-1, coin_tex_id, 'AnimFlyingUpObj')
  Good.SetPos(o, Good.GetPos(id))
end

function GetCityHarvest()
  for i = 1, MAX_CITY do
    if (GetMyPlayerId() == city_owner[i]) then
      GenHarvestCoinAnimObj(GetCityObjById(i))
    end
  end
  AddCoin(players_coin[my_player_idx])
  players_coin[my_player_idx] = 0
  SaveGame()
end

Map.OnStep = function(param)
  if (0 < players_coin[my_player_idx]) then
    param.step = OnMapHarvest
  end
  param.step(param)
end

function OnMapHarvest(param)
  if (nil == param.harvest_time) then
    param.harvest_time = 50
    GetCityHarvest()
  elseif (0 < param.harvest_time) then
    param.harvest_time = param.harvest_time - 1
    if (0 == param.harvest_time) then
      param.harvest_time = nil
      SetPlayingStep(param)
    end
  end
end

function OnMapMenu(param)
  local NextStep
  if (MyTurn()) then
    NextStep = OnMapPlaying
  elseif (nil ~= param.ai_step) then
    NextStep = param.ai_step
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

function CollectPlayersRankInfo()
  local active_players = {}
  for i = 1, MAX_PLAYER do
    local city_count = GetPlayerCityCount(i)
    if (0 < city_count) then
      table.insert(active_players, {i, GetPlayerTotalCombatPower(i)})
    end
  end
  table.sort(active_players, function(a,b) return a[2] > b[2] end)
  return active_players
end

function GenPlayerRankObj(x, y, prev_x, prev_y, player_id, combat_power)
  local color = GetPlayerColor(player_id)
  local o = GenColorObj(players_info_obj, PLAYER_LABLE_W, CITY_LABLE_H, color)
  Good.SetPos(o, x, y)
  local s = Good.GenTextObj(o, string.format('%d', combat_power), CITY_LABLE_TEXT_SIZE)
  local w = GetTextObjWidth(s)
  Good.SetPos(s, (PLAYER_LABLE_W - w)/2, (CITY_LABLE_H - CITY_LABLE_TEXT_SIZE)/2)
  local param = Good.GetParam(o)
  param.player_id = player_id
  param.new_x = x
  param.new_y = y
  if (-1 ~= prev_x and -1 ~= prev_y and (x ~= prev_x or y ~= prev_y)) then
    Good.SetPos(o, prev_x, prev_y)
    Good.SetScript(o, 'AnimInfoOrder')
  end
end

function CollectPlayersRankPos()
  local players_pos = {}
  for i = 1, MAX_PLAYER do
    players_pos[i] = {-1, -1}
  end
  if (nil ~= players_info_obj) then
    local c = Good.GetChildCount(players_info_obj)
    for i = 0, c - 1 do
      local o = Good.GetChild(players_info_obj, i)
      local param = Good.GetParam(o)
      players_pos[param.player_id] = {param.new_x, param.new_y}
    end
  end
  return players_pos
end

function UpdatePlayersRankInfo()
  local prev_players_pos = CollectPlayersRankPos()
  if (nil ~= players_info_obj) then
    Good.KillObj(players_info_obj)
    players_info_obj = nil
  end
  players_info_obj = Good.GenDummy(-1)
  SetTopmost(players_info_obj)
  local active_players = CollectPlayersRankInfo()
  local x, y = 0, TILE_H/2 + 6
  for i = 1, #active_players do
    local info = active_players[i]
    local player_id = info[1]
    local combat_power = info[2]
    local prev_pos = prev_players_pos[player_id]
    GenPlayerRankObj(x, y, prev_pos[1], prev_pos[2], player_id, combat_power)
    x = x + 1.2 * PLAYER_LABLE_W
    if (WND_W <= x + 1.2 * PLAYER_LABLE_W) then
      x = 0
      y = y + TILE_H/2
    end
  end
end

function UpdateRoundInfo()
  Good.KillAllChild(round_obj_id)
  local s = Good.GenTextObj(round_obj_id, string.format('%d', curr_round), TILE_W/2)
  local w = GetTextObjWidth(s)
  Good.SetPos(s, -w - TILE_W/2, 0)
end

function SetNextTurn(param)
  NextTurn()
  UpdateRoundInfo()
  SetPlayingStep(param)
  UpdatePlayersRankInfo()
  if (MyTurn()) then
    if (GetMyPlayerId() ~= city_owner[GetCityId(Good.GetChild(curr_sel_city, 0))]) then
      local o = GetCityObjById(GetFirstCurrPlayerCityId())
      SetSelCity(o)
    end
  end
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
    param.ai_step = nil
    return
  end

  if (not Input.IsKeyPressed(Input.LBUTTON)) then
    return
  end

  local is_victory = IsVictory()
  local mx, my = Input.GetMousePos()

  -- End of round.
  if (not is_victory and PtInRect(mx, my, WND_W - 40, 0, WND_W, 40)) then
    SetNextTurn(param)
    return
  end

  -- Click on hero menu.
  if (PtInRect(mx, my, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y, HERO_MENU_OFFSET_X + HERO_MENU_W * MAX_HERO, WND_H)) then
    local is_upgrade, menu = SelHeroMenu(mx, my)
    if (is_upgrade) then
      UpgradeMyHero(menu)
      UpdatePlayersRankInfo()
      param.step = OnMapWaitAnimDone
    end
    return
  end

  -- Click on map.
  if (PtInObj(mx, my, map_obj_id)) then
    if (SelCity(mx, my) and not is_victory) then
      GenActionBtnPanel()
      param.step = OnActionPanel
    end
    return
  end
end

function UpgradeHero(city_id)
  local heroes = city_hero[city_id]
  for i = MAX_HERO, 1, -1 do
    local lv = heroes[i]
    if (0 < lv or (1 < i and 0 ~= heroes[i - 1])) then
      local cost = GetLevelValue(lv, HeroData[i].UpgradeCost)
      if (cost < players_coin[curr_player_idx]) then
        players_coin[curr_player_idx] = players_coin[curr_player_idx] - cost
        heroes[i] = heroes[i] + 1
        local o = GetCityObjById(city_id)
        UpdateCityInfo(o)
        GenUpgradeAnimObj(o)
        return true
      end
    end
  end
  return false
end

function SortCities(cities)
  if (0 == (curr_player_idx % 2)) then
    table.sort(cities, function(a,b) return GetHeroCombatPower(a) > GetHeroCombatPower(b) end)
  else
    Shuffle(cities)
  end
end

function UpgradeCityHero()
  local cities = GetCurrPlayerCityIdList()
  SortCities(cities)
  for i = 1, #cities do
    if (UpgradeHero(cities[i])) then
      return true
    end
  end
  return false
end

function GenInvadeCityAnimObj(player_id, city_id, target_city_id, is_win)
  local city_obj = GetCityObjById(city_id)
  local o = Good.GenObj(-1, battle_tex_id, 'AnimInvadeCity')
  Good.SetPos(o, Good.GetPos(city_obj))
  local param = Good.GetParam(o)
  param.player_id = player_id
  param.target_city_id = target_city_id
  param.is_win = is_win
end

function InvadeNearEmptyCity(city_id)
  local near_city = CityData[city_id]
  for i = 1, #near_city do
    local near_city_id = near_city[i]
    if (0 == city_owner[near_city_id]) then
      GenInvadeCityAnimObj(players[curr_player_idx], city_id, near_city_id, true)
      return true
    end
  end
  return false
end

function GetInvadeNearCityList(city_id)
  local near_city = {unpack(CityData[city_id])} -- Clone.
  table.sort(near_city, function(a,b) return GetHeroCombatPower(a) > GetHeroCombatPower(b) end)
  return near_city
end

function InvadeNearCityFrom(city_id)
  local player_id = players[curr_player_idx]
  local hero_combat_power = GetHeroCombatPower(city_id)
  local near_city = GetInvadeNearCityList(city_id)
  for i = 1, #near_city do
    local near_city_id = near_city[i]
    local near_player_id = city_owner[near_city_id]
    if (near_player_id ~= player_id) then
      local target_combat_power = GetHeroCombatPower(near_city_id)
      if (hero_combat_power > target_combat_power) then
        local total_weight = hero_combat_power + target_combat_power
        local is_win = math.random(total_weight) > target_combat_power/2
        GenInvadeCityAnimObj(player_id, city_id, near_city_id, is_win)
        return true
      end
    end
  end
  return false
end

function InvadeNearCity()
  local cities = GetCurrPlayerCityIdList()
  SortCities(cities)
  for i = 1, #cities do
    local city_id = cities[i]
    if (InvadeNearEmptyCity(city_id)) then
      return true
    end
  end
  for i = 1, #cities do
    local city_id = cities[i]
    if (InvadeNearCityFrom(city_id)) then
      return true
    end
  end
  return false
end

function CheckCitySelChange()
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    local mx, my = Input.GetMousePos()
    if (PtInObj(mx, my, map_obj_id)) then
      SelCity(mx, my)
    end
  end
end

function OnMapAiPlaying(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnMapMenu
    param.ai_step = OnMapAiPlaying
    return
  end

  CheckCitySelChange()

  if (UpgradeCityHero()) then
    param.step = OnMapWaitAnimDone
    return
  end

  if (InvadeNearCity()) then
    param.step = OnMapWaitAnimDone
    return
  end

  OnMapAiPlayingNextTurn(param)
end

function OnMapAiPlayingNextTurn(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnMapMenu
    param.ai_step = OnMapAiPlayingNextTurn
    return
  end

  CheckCitySelChange()

  SetNextTurn(param)

  if (check_game_over_flag and 0 == GetPlayerCityCount(GetMyPlayerId())) then
    ShowGameOver(param, OnMapGameOver, 'Game Over', 0xff500000)
    game_over_count = game_over_count + 1
    param.step = OnGameOverEnter
    check_game_over_flag = false
    UpdateHeroMenuSel()
    return
  end
end

function OnMapWaitAnimDone(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnMapMenu
    param.ai_step = nil
    return
  end

  CheckCitySelChange()
end

function OnMapGameOver(param)
  if (Input.IsKeyPressed(Input.ESCAPE) or Input.IsKeyPressed(Input.LBUTTON)) then
    if (nil ~= anim_game_over_obj) then
      Good.KillObj(anim_game_over_obj)
      anim_game_over_obj = nil
    end
    param.step = OnMapAiPlaying
  end
end

function GenUpgradeAnimObj(id)
  local o = Good.GenObj(-1, upgrade_tex_id, 'AnimUpgradeCity')
  Good.SetPos(o, Good.GetPos(id))
end

function UpgradeMyHero(menu)
  coin_count = coin_count - menu.upgrade_cost
  local hero = HeroData[menu.hero_id]
  menu.lv = menu.lv + 1
  menu.max_count = math.min(hero.MaxCount, menu.max_count + 1)
  menu.put_cost = GetHeroPutCost(menu.lv, hero.PutCost)
  menu.upgrade_cost = GetHeroUpgradeCost(menu.lv, hero.UpgradeCost)
  menu.gen_cd = GetLevelCdValue(menu.lv, hero.GenCd)
  UpdateHeroMenuItemInfo(menu)
  if (menu.hero_id ~= MAX_HERO) then
    local next_menu = GetHeroMenu()[menu.hero_id + 1]
    if (0 >= next_menu.max_count) then
      next_menu.max_count = 0           -- Unlock to set count to 1.
      UpdateHeroMenuItemInfo(next_menu)
    end
  end
  UpdateCoinCountObj()
  local o = Good.GetChild(curr_sel_city, 0)
  local heroes = city_hero[GetCityId(o)]
  heroes[menu.hero_id] = heroes[menu.hero_id] + 1
  UpdateCityInfo(o)
  UpdateHeroMenuSel()
  GenUpgradeAnimObj(o)
  SaveGame()
end
