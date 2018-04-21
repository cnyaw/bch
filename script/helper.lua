local SAV_FILE_NAME = "bch2.sav"
local UPGRADE_CD_CURVE = 1.05
local UPGRADE_CURVE = 1.2
local MENU_TEXT_OFFSET_X, MENU_TEXT_OFFSET_Y = 2, 2
local MENU_TEXT_SIZE = 15
local HERO_UPGRADE_DISABLE_COLOR = 0xff505050
local HERO_MENU_DISABLE_COLOR = 0xff808080
local HERO_MENU_DESEL_COLOR = 0xff4c8000
local HERO_MENU_SEL_COLOR = 0xff8cff00
local INIT_COIN_COUNT = 500
local PLAYER_COLOR = {
  0xffFF0000, 0xffFF6A00, 0xffB6FF00, 0xff00FF21, 0xff7F6A00,
  0xff267F00, 0xff00FFFF, 0xffFFD800, 0xffFF00DC, 0xff7F0037}
TILE_W, TILE_H = 44, 44
local STAT_TEXT_SIZE = TILE_H/2
local SMALL_STAT_TEXT_SIZE = TILE_H/3
local STATS_TEXT_COLOR = 0xffa0a0a0
local STATS_OFFSET_1 = 1.05
local STATS_OFFSET_2 = 0.65
MAX_PLAYER = 10
MAX_CITY = 24
MAX_HERO = 6

local game_lvl_id = 0
local hero_menu_button_tex_id = 3
local castle_tex_id = 26
local combat_tex_id = 15
local coin_tex_id = 13
local sand_glass_tex_id = 17
local win_tex_id = 44
local fail_tex_id = 48

Graphics.SetAntiAlias(1)                -- Enable anti alias.

WND_W, WND_H = Good.GetWindowSize()
MAP_X, MAP_Y = 0, 0
MAP_W, MAP_H = 9, 10

HERO_MENU_W, HERO_MENU_H = 65, 2.2 * TILE_H
HERO_MENU_OFFSET_X = (WND_W - 6 * HERO_MENU_W) / 2
HERO_MENU_OFFSET_Y = WND_H - HERO_MENU_H

invade_stage_count = 0
total_invade_stage_count = 0
anim_game_over_obj = nil

city_owner = nil

function ResetCityOwner()
  city_owner = {}
  for i = 1, MAX_CITY do
    city_owner[i] = 0
  end
end

if (nil == city_owner) then
  ResetCityOwner()
end

function Shuffle(a)
  local len = #a
  for i = len, 1, -1 do
    local r = math.random(len)
    a[i], a[r] = a[r], a[i]
  end
end

city_hero = nil

function ResetCityHero()
  city_hero = {}
  for i = 1, MAX_CITY do
    city_hero[i] = {}
    for j = 1, MAX_HERO do
      if (1 == j) then
        table.insert(city_hero[i], 1)
      else
        table.insert(city_hero[i], 0)
      end
    end
  end
end

players = nil                           -- Player ID.
players_coin = nil
my_player_idx = nil
curr_player_idx = nil
curr_round = 1
check_game_over_flag = true

function ResetPlayers()
  players = {}
  players_coin = {}
  for i = 1, MAX_PLAYER do
    players[i] = i
    players_coin[i] = INIT_COIN_COUNT
  end
  Shuffle(players)
  for i = 1, MAX_PLAYER do
    city_owner[i] = players[i]
  end
  Shuffle(city_owner)
  my_player_idx = math.random(MAX_PLAYER)
  players_coin[my_player_idx] = 0       -- Refer to global::coin_count.
  curr_player_idx = 1
end

if (nil == players) then
  ResetPlayers()
end

coin_count = 100
curr_total_coin_count = 0
total_coin_count = 0

total_play_time = 0
curr_play_time = 0
reset_count = 0
victory_count = 0
victory_min_round = 0
game_over_count = 0

glass_speed = 1

max_combat_power = 0

total_kill = {0, 0, 0, 0, 0, 0}
curr_kill = {0, 0, 0, 0, 0, 0}

OccupyMap = {}

SelHero = nil
local hero_menu = nil

function ConvertRedPos(pos)
  local col = pos % MAP_W
  local row = math.floor(pos / MAP_W)
  return (MAP_W - col - 1) + MAP_W * (MAP_H - row - 1)
end

function GetFormatTimeStr(ticks)
  local play_time = math.floor(ticks / 60)
  local sec = play_time % 60
  local minute = math.floor(play_time / 60) % 60
  local hour = math.floor(play_time / 3600) % 24
  local day = math.floor(play_time / 86400)
  local s_play_time
  if (0 < day) then
    s_play_time = string.format('%d:%d:%d:%d', day, hour, minute, sec)
  elseif (0 < hour) then
    s_play_time = string.format('%d:%d:%d', hour, minute, sec)
  elseif (0 < minute) then
    s_play_time = string.format('%d:%d', minute, sec)
  else
    s_play_time = string.format('%d', sec)
  end
  return s_play_time
end

function GetXyFromPos(pos)
  local col = pos % MAP_W
  local row = math.floor(pos / MAP_W)
  local x = col * TILE_W - TILE_W/2 + 8
  local y = row * TILE_H - TILE_H/2 + 8
  return x, y
end

function UpdateHeroMenuItemInfo(menu)
  if (nil ~= menu.info_obj) then
    Good.KillObj(menu.info_obj)
    menu.info_obj = nil
  end
  if (0 > menu.max_count) then
    return
  end
  local info_obj = Good.GenDummy(menu.dummy)
  if (0 < menu.max_count) then
    local lv_obj = Good.GenTextObj(info_obj, string.format('%d', menu.lv), MENU_TEXT_SIZE)
    Good.SetPos(lv_obj, (HERO_MENU_W + TILE_W/2)/2, (HERO_MENU_H + TILE_H/2)/2)
    local cost_obj = Good.GenTextObj(info_obj, string.format('$%d', menu.put_cost), MENU_TEXT_SIZE)
    Good.SetPos(cost_obj, MENU_TEXT_OFFSET_X, MENU_TEXT_OFFSET_Y)
    local count_obj = Good.GenTextObj(info_obj, string.format('%d/%d', menu.count, menu.max_count), MENU_TEXT_SIZE)
    local tw = GetTextObjWidth(count_obj)
    Good.SetPos(count_obj, HERO_MENU_W - MENU_TEXT_OFFSET_X - tw, MENU_TEXT_OFFSET_Y)
  end
  local btn_obj = Good.GenObj(info_obj, hero_menu_button_tex_id)
  local l,t,w,h = Good.GetDim(btn_obj)
  Good.SetPos(btn_obj, (HERO_MENU_W - w)/2, HERO_MENU_H - MENU_TEXT_OFFSET_Y - h)
  local upgrade_obj = Good.GenTextObj(btn_obj, string.format('$%d', menu.upgrade_cost), MENU_TEXT_SIZE)
  local tw = GetTextObjWidth(upgrade_obj)
  Good.SetPos(upgrade_obj, (w - tw)/2, (h - MENU_TEXT_SIZE)/2)
  menu.btn_obj = btn_obj
  menu.info_obj = info_obj
end

function InGame()
  return game_lvl_id == Good.GetLevelId()
end

function IsPutHeroValid(menu)
  return coin_count >= menu.put_cost and menu.count < menu.max_count
end

function AutoSelHero(HeroMenu)
  if (nil == SelHero or not IsPutHeroValid(HeroMenu[SelHero])) then
    for  i = 1, MAX_HERO do
      if (IsPutHeroValid(HeroMenu[i])) then
        SelHero = i
        break
      end
    end
  end
end

function UpdateHeroMenuState_i(HeroMenu)
  AutoSelHero(HeroMenu)
  local IsInGame = InGame()
  for  i = 1, MAX_HERO do
    local menu = HeroMenu[i]
    if (not IsPutHeroValid(menu)) then
      Good.SetAlpha(menu.o, 128)
      Good.SetBgColor(menu.cd_obj, HERO_MENU_DISABLE_COLOR)
    elseif (IsInGame) then
      if (i == SelHero) then
        Good.SetAlpha(menu.o, 255)
        Good.SetBgColor(menu.cd_obj, HERO_MENU_SEL_COLOR)
        SelHero = i
      else
        Good.SetAlpha(menu.o, 128)
        Good.SetBgColor(menu.cd_obj, HERO_MENU_DESEL_COLOR)
      end
    end
    if (nil == menu.info_obj) then
      return
    end
    if (menu.read_only or coin_count < menu.upgrade_cost) then
      Good.SetBgColor(menu.btn_obj, HERO_UPGRADE_DISABLE_COLOR)
    else
      Good.SetBgColor(menu.btn_obj, 0xffffffff)
    end
  end
end

function UpdateHeroMenuSel()
  UpdateHeroMenuState_i(GetHeroMenu())
end

function UpdateHeroMenuCd()
  local HeroMenu = GetHeroMenu()
  for i = 1, MAX_HERO do
    local menu = HeroMenu[i]
    if (0 < menu.cd) then
      menu.cd = menu.cd - 1
      local d = menu.cd / menu.gen_cd
      local offset_y = math.floor(HERO_MENU_H * d)
      local h = HERO_MENU_H - offset_y
      Good.SetPos(menu.cd_obj, 2, 2 + offset_y)
      Good.SetDim(menu.cd_obj, 0, 0, HERO_MENU_W - 4, h)
    end
  end
end

function InitOccupyMap()
  for i = 0, MAP_W * MAP_H - 1 do
    OccupyMap[i] = 0
  end
end

function LoadGame()
  ResetGame()
  local inf = io.open(SAV_FILE_NAME, "r")
  if (nil == inf) then
    return
  end
  assert(loadstring(inf:read("*all")))()
  inf:close()
end

function ResetGame()
  coin_count = INIT_COIN_COUNT
  curr_total_coin_count = 0
  invade_stage_count = 0
  curr_round = 1
  ResetCityOwner()
  ResetCityHero()
  ResetPlayers()
  curr_play_time = 0
  for i = 1, MAX_HERO do
    curr_kill[i] = 0
  end
  reset_count = reset_count + 1
  check_game_over_flag = true
end

LoadGame()

function GetMaxCombatPower()
  local my_city_count = GetPlayerCityCount(GetMyPlayerId())
  if (0 ~= my_city_count and MAX_CITY ~= my_city_count) then
    max_combat_power = math.max(max_combat_power, GetMyPlayerTotalCombatPower()) -- Update only when not victiry or game over.
  end
  return max_combat_power
end

function WriteTable(outf, name, t)
  outf:write(string.format('%s={', name))
  for i = 1, #t do
    if (#t == i) then
      outf:write(string.format('%d', t[i]))
    else
      outf:write(string.format('%d,', t[i]))
    end
  end
  outf:write(string.format('}\n'))
end

function SaveGame()
  local outf = io.open(SAV_FILE_NAME, "w")
  outf:write(string.format('curr_round=%d\n', curr_round))
  outf:write(string.format('reset_count=%d\n', reset_count))
  outf:write(string.format('victory_count=%d\n', victory_count))
  outf:write(string.format('victory_min_round=%d\n', victory_min_round))
  outf:write(string.format('game_over_count=%d\n', game_over_count))
  outf:write(string.format('coin_count=%d\n', coin_count))
  outf:write(string.format('invade_stage_count=%d\n', invade_stage_count))
  outf:write(string.format('total_invade_stage_count=%d\n', total_invade_stage_count))
  outf:write(string.format('max_combat_power=%d\n', GetMaxCombatPower()))
  outf:write(string.format('curr_total_coin_count=%d\n', curr_total_coin_count))
  outf:write(string.format('total_coin_count=%d\n', total_coin_count))
  outf:write(string.format('curr_play_time=%d\n', curr_play_time))
  outf:write(string.format('total_play_time=%d\n', total_play_time))
  WriteTable(outf, 'curr_kill', curr_kill)
  WriteTable(outf, 'total_kill', total_kill)
  WriteTable(outf, 'city_owner', city_owner)
  for i = 1, MAX_CITY do
    WriteTable(outf, string.format('city_hero[%d]', i), city_hero[i])
  end
  WriteTable(outf, 'players', players)
  WriteTable(outf, 'players_coin', players_coin)
  outf:write(string.format('my_player_idx=%d\n', my_player_idx))
  outf:write(string.format('curr_player_idx=%d\n', curr_player_idx))
  outf:close()
end

function GetLevelCdValue(lv, init_val)
  return math.floor(init_val * math.pow(UPGRADE_CD_CURVE, lv))
end

function GetLevelValue(lv, init_val)
  return math.floor(init_val * math.pow(UPGRADE_CURVE, lv))
end

function GetKingLv(stage_id)
  return 1 + stage_id/25
end

function GetMyPlayerId()
  return players[my_player_idx]
end

function StageClear(city_id)
  local my_player_id = GetMyPlayerId()
  if (my_player_id ~= city_owner[city_id]) then
    city_owner[city_id] = my_player_id
  end
end

function PtInObj(mx, my, o)
  local l,t,w,h = Good.GetDim(o)
  local x, y = Good.GetPos(o)
  return PtInRect(mx, my, x, y, x + w, y + h)
end

function MyTurn()
  return my_player_idx == curr_player_idx
end

function GetCurrPlayerCityIdList()
  local cities = {}
  local id = players[curr_player_idx]
  for i = 1, MAX_CITY do
    if (id == city_owner[i]) then
      table.insert(cities, i)
    end
  end
  return cities
end

function GetFirstCurrPlayerCityId()
  local cities = GetCurrPlayerCityIdList()
  if (0 == #cities) then
    return -1
  else
    return cities[1]
  end
end

function GetFirstPlayerCityId(idx)
  local id = players[idx]
  for i = 1, MAX_CITY do
    if (id == city_owner[i]) then
      return i
    end
  end
  return -1
end

function GetPlayerCityCount(id)
  local c = 0
  for i = 1, MAX_CITY do
    if (id == city_owner[i]) then
      c = c + 1
    end
  end
  return c
end

function GetFirstPlayerIdx()
  for i = 1, MAX_PLAYER do
    if (0 < GetPlayerCityCount(players[i])) then
      return i
    end
  end
  return -1
end

function GetPlayerTotalCombatPower(id)
  local combat_power = 0
  for i = 1, MAX_CITY do
    if (id == city_owner[i]) then
      combat_power = combat_power + GetHeroCombatPower(i)
    end
  end
  return combat_power
end

function GetMyPlayerTotalCombatPower()
  return GetPlayerTotalCombatPower(GetMyPlayerId())
end

function GetPlayerIdx(id)
  for i = 1, MAX_PLAYER do
    if (players[i] == id) then
      return i
    end
  end
  return -1
end

function GetHarvestOfRound()
  local player_power = {}
  for i = 1, MAX_PLAYER do
    player_power[i] = 0
  end
  for i = 1, MAX_CITY do
    if (0 < city_owner[i]) then
      local city_power = GetHeroCombatPower(i)
      local player_idx = GetPlayerIdx(city_owner[i])
      players_coin[player_idx] = players_coin[player_idx] + city_power
      player_power[player_idx] = player_power[player_idx] + city_power
    end
  end
  local extra_coin = INIT_COIN_COUNT
  if (0 == (curr_round % 10)) then
    extra_coin = extra_coin + INIT_COIN_COUNT
  end
  for i = 1, MAX_PLAYER do
    if (0 < player_power[i]) then
      players_coin[i] = players_coin[i] + extra_coin
    end
  end
end

function NextTurn()
  while true do
    if (MAX_PLAYER == curr_player_idx) then
      curr_player_idx = 1
    else
      curr_player_idx = curr_player_idx + 1
    end
    if (-1 ~= GetFirstCurrPlayerCityId()) then
      break
    end
  end
  if (GetFirstPlayerIdx() == curr_player_idx) then
    curr_round = curr_round + 1
    GetHarvestOfRound()
  end
end

function Lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1
end

function GetPlayerColor(id)
  local clr = 0xff808080
  if (GetMyPlayerId() == id) then
    clr = 0xff0000ff
  elseif (0 ~= id) then
    clr = PLAYER_COLOR[id]
  end
  return clr
end

function GetPlayerCoinCount(id)
  local idx = GetPlayerIdx(id)
  if (my_player_idx == idx) then
    return coin_count
  else
    return players_coin[idx]
  end
end

function SetPlayerCoinCount(id, count)
  local idx = GetPlayerIdx(id)
  if (my_player_idx == idx) then
    coin_count = count
  else
    players_coin[idx] = count
  end
end

function GetHeroCombatPower(city_id)
  local heroes = city_hero[city_id]
  local p = 0
  for hero_id = 1, MAX_HERO do
    local hero = HeroData[hero_id]
    local lv = heroes[hero_id]
    local hero_max_count = math.min(lv, hero.MaxCount)
    if (0 < hero_max_count) then
      p = p + hero_max_count * GetLevelValue(lv, hero.Atk)
    end
  end
  return p
end

function GetHeroPutCost(lv, hero_put_cost)
  return math.min(9999, GetLevelValue(lv, hero_put_cost))
end

function GetHeroUpgradeCost(lv, hero_upgrade_cost)
  return math.min(999999, GetLevelValue(lv, hero_upgrade_cost))
end

function GenHeroMenuItem(hero_id, lv)
  local hero = HeroData[hero_id]
  local x = HERO_MENU_OFFSET_X + (hero_id - 1) * HERO_MENU_W
  local y = HERO_MENU_OFFSET_Y
  local dummy = Good.GenDummy(hero_menu)
  Good.SetPos(dummy, x, y)
  local menu = {}
  menu.hero_id = hero_id
  menu.lv = lv
  menu.gen_cd = GetLevelCdValue(menu.lv, hero.GenCd)
  menu.put_cost = GetHeroPutCost(menu.lv, hero.PutCost)
  menu.upgrade_cost = GetHeroUpgradeCost(menu.lv, hero.UpgradeCost)
  menu.count = 0
  menu.max_count = math.min(menu.lv, hero.MaxCount)
  menu.cd = 0
  local cd_obj = GenColorObj(dummy, HERO_MENU_W - 4, HERO_MENU_H, HERO_MENU_DISABLE_COLOR)
  Good.SetPos(cd_obj, 2, 2)
  menu.cd_obj = cd_obj
  local piece_obj = GenHeroPieceObj(dummy, hero.Face, true, '')
  Good.SetAlpha(piece_obj, 128)
  Good.SetPos(piece_obj, (HERO_MENU_W - TILE_W) / 2, (HERO_MENU_H - TILE_H) / 2)
  SetTextObjColor(piece_obj, hero.Color)
  menu.o = piece_obj
  menu.dummy = dummy
  menu.info_obj = nil
  return menu
end

function GenHeroMenu(city_id, read_only)
  if (nil ~= hero_menu) then
    Good.KillObj(hero_menu)
    hero_menu = nil
  end
  local heroes = city_hero[city_id]
  hero_menu = Good.GenDummy(-1)
  local HeroMenu = Good.GetParam(hero_menu)
  local max_count = {}
  for hero_id = 1, MAX_HERO do
    local menu = GenHeroMenuItem(hero_id, heroes[hero_id])
    menu.read_only = read_only
    max_count[hero_id] = menu.max_count
    if (1 < hero_id and 0 == max_count[hero_id - 1]) then
      menu.max_count = -1
    end
    UpdateHeroMenuItemInfo(menu)
    HeroMenu[hero_id] = menu
  end
  UpdateHeroMenuState_i(HeroMenu)
  return HeroMenu
end

function GenGameHeroMenu(city_id)
  return GenHeroMenu(city_id, true)
end

function GetHeroMenu()
  return Good.GetParam(hero_menu)
end

function AllCityClear(skip_city_id)
  local my_player_id = GetMyPlayerId()
  for i = 1, MAX_CITY do
    if (skip_city_id ~= i and city_owner[i] ~= my_player_id) then
      return false
    end
  end
  return true
end

function ShowGameOver(param, next_step, msg, clr)
  if (nil ~= anim_game_over_obj) then
    return
  end
  anim_game_over_obj = GenColorObj(-1, WND_W, WND_H + 10, clr, 'AnimGameOver')
  local s = Good.GenTextObj(anim_game_over_obj, msg, 64)
  local slen = GetTextObjWidth(s)
  Good.SetPos(s, (WND_W - slen)/2, 3/7 * WND_H)
  Good.SetPos(anim_game_over_obj, 0, -WND_H)
  local p = Good.GetParam(anim_game_over_obj)
  p.lvl_param = param
  p.next_step = next_step
end

function GenKillsInfo(dummy)
  local s_kill = Good.GenTextObj(dummy, 'Kill', STAT_TEXT_SIZE)
  Good.SetPos(s_kill, 0, TILE_H/2)
  local offset = 1.4
  for hero_id = 1, MAX_HERO do
    local hero_obj = GenHeroPieceObj(s_kill, HeroData[hero_id].Face, false, '')
    Good.SetScale(hero_obj, 0.5, 0.5)
    Good.SetPos(hero_obj, 0, TILE_W/2 * offset)
    local hero_count = Good.GenTextObj(s_kill, string.format('%d', curr_kill[hero_id]), STAT_TEXT_SIZE)
    Good.SetPos(hero_count, TILE_W, TILE_W/2 * offset)
    offset = offset + STATS_OFFSET_1
    hero_count = Good.GenTextObj(s_kill, string.format('%d', total_kill[hero_id]), SMALL_STAT_TEXT_SIZE)
    SetTextObjColor(hero_count, STATS_TEXT_COLOR)
    Good.SetPos(hero_count, TILE_W, TILE_W/2 * offset)
    offset = offset + STATS_OFFSET_2
  end
end

function GenStatsInfo(dummy)
  local s_max = Good.GenTextObj(dummy, string.format('Stats (%d)', reset_count), STAT_TEXT_SIZE)
  Good.SetPos(s_max, 3 * TILE_W, TILE_H/2)
  local offset = 1.4
  local scale = (TILE_W/2) / 32
  local max_stage_obj = Good.GenObj(s_max, castle_tex_id, '')
  Good.SetScale(max_stage_obj, scale, scale)
  Good.SetPos(max_stage_obj, 0, TILE_W/2 * offset)
  local s_invade_stage_obj = Good.GenTextObj(s_max, string.format('%d', invade_stage_count), STAT_TEXT_SIZE)
  Good.SetPos(s_invade_stage_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
  s_invade_stage_obj = Good.GenTextObj(s_max, string.format('%d', total_invade_stage_count), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_invade_stage_obj, STATS_TEXT_COLOR)
  Good.SetPos(s_invade_stage_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_2
  local max_combat_obj = Good.GenObj(s_max, combat_tex_id, '')
  Good.SetScale(max_combat_obj, scale, scale)
  Good.SetPos(max_combat_obj, 0, TILE_W/2 * offset)
  local s_max_combat_obj = Good.GenTextObj(s_max, string.format('%d', GetMyPlayerTotalCombatPower()), STAT_TEXT_SIZE)
  Good.SetPos(s_max_combat_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
  s_max_combat_obj = Good.GenTextObj(s_max, string.format('%d', GetMaxCombatPower()), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_max_combat_obj, STATS_TEXT_COLOR)
  Good.SetPos(s_max_combat_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_2
  local max_coin_obj = Good.GenObj(s_max, coin_tex_id, '')
  Good.SetScale(max_coin_obj, scale, scale)
  Good.SetPos(max_coin_obj, 0, TILE_W/2 * offset)
  local s_total_coin_obj = Good.GenTextObj(s_max, string.format('%d', curr_total_coin_count), STAT_TEXT_SIZE)
  Good.SetPos(s_total_coin_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
  s_total_coin_obj = Good.GenTextObj(s_max, string.format('%d', total_coin_count), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_total_coin_obj, STATS_TEXT_COLOR)
  Good.SetPos(s_total_coin_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_2
  scale = (TILE_W/2)/45
  local play_time_obj = Good.GenObj(s_max, sand_glass_tex_id, '')
  Good.SetScale(play_time_obj, scale, scale)
  Good.SetPos(play_time_obj, 4, TILE_W/2 * offset)
  local s_play_time_obj = Good.GenTextObj(s_max, GetFormatTimeStr(curr_play_time), STAT_TEXT_SIZE)
  Good.SetPos(s_play_time_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
  s_play_time_obj = Good.GenTextObj(s_max, GetFormatTimeStr(total_play_time), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_play_time_obj, STATS_TEXT_COLOR)
  Good.SetPos(s_play_time_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
  local victory_obj = Good.GenObj(s_max, win_tex_id, '')
  Good.SetScale(victory_obj, scale, scale)
  Good.SetPos(victory_obj, 4, TILE_W/2 * offset)
  local s_victory_obj = Good.GenTextObj(s_max, string.format('%d', victory_count), STAT_TEXT_SIZE)
  Good.SetPos(s_victory_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
  local s_victory_min_round_obj = Good.GenTextObj(s_max, string.format('%d', victory_min_round), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_victory_min_round_obj, STATS_TEXT_COLOR)
  Good.SetPos(s_victory_min_round_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_2
  local game_over_obj = Good.GenObj(s_max, fail_tex_id, '')
  Good.SetScale(game_over_obj, scale, scale)
  Good.SetPos(game_over_obj, 4, TILE_W/2 * offset)
  local s_gameover_obj = Good.GenTextObj(s_max, string.format('%d', game_over_count), STAT_TEXT_SIZE)
  Good.SetPos(s_gameover_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + STATS_OFFSET_1
end

function GetCheckGameOverFlag()
  if (not check_game_over_flag) then
    return check_game_over_flag
  end
  return 0 < GetPlayerCityCount(GetMyPlayerId()) -- At least own a city, so need to check game over.
end
