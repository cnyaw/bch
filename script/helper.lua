local SAV_FILE_NAME = "bch2.sav"
local UPGRADE_CD_CURVE = 1.05
local UPGRADE_CURVE = 1.2
local MENU_TEXT_OFFSET_X, MENU_TEXT_OFFSET_Y = 2, 2
local MENU_TEXT_SIZE = 15
local HERO_UPGRADE_DISABLE_COLOR = 0xff505050
local HERO_MENU_DISABLE_COLOR = 0xff808080
local HERO_MENU_DESEL_COLOR = 0xff4c8000
local HERO_MENU_SEL_COLOR = 0xff8cff00
local MAX_PLAYER = 10
local INIT_COIN_COUNT = 200
local PLAYER_COLOR = {
  0xffFF0000, 0xffFF6A00, 0xffB6FF00, 0xff00FF21, 0xff7F6A00,
  0xff267F00, 0xff00FFFF, 0xffFFD800, 0xffFF00DC, 0xff7F0037}
MAX_CITY = 24
MAX_HERO = 6

local game_lvl_id = 0

Graphics.SetAntiAlias(1)                -- Enable anti alias.

WND_W, WND_H = Good.GetWindowSize()

MAP_X, MAP_Y = 0, 0
MAP_W, MAP_H = 9, 10
TILE_W, TILE_H = 44, 44

HERO_MENU_W, HERO_MENU_H = 65, 2.2 * TILE_H
HERO_MENU_OFFSET_X = (WND_W - 6 * HERO_MENU_W) / 2
HERO_MENU_OFFSET_Y = WND_H - HERO_MENU_H

sel_stage_id = 1
max_stage_id = 1
max_max_stage_id = 1
local hero_menu_button_tex_id = 3

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

glass_speed = 1

max_combat_power = 0

TotalKillEnemy = {0, 0, 0, 0, 0, 0}
CurrKillEnemy = {0, 0, 0, 0, 0, 0}

OccupyMap = {}

HeroMenu = nil
SelHero = nil
local hero_menu = nil

function ConvertRedPos(pos)
  local col = pos % MAP_W
  local row = math.floor(pos / MAP_W)
  return (MAP_W - col - 1) + MAP_W * (MAP_H - row - 1)
end

function GetCombatPower()
  local p = 0
  for hero_id = 1, #HeroMenu do
    local menu = HeroMenu[hero_id]
    if (0 < menu.max_count) then
      local hero = HeroData[hero_id]
      p = p + menu.max_count * GetLevelValue(menu.lv, hero.Atk)
    end
  end
  max_combat_power = math.max(max_combat_power, p)
  return p
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

function ResetHeroMenu()
  HeroMenu = {}
  for hero_id = 1, MAX_HERO do
    local menu = {}
    if (1 == hero_id) then
      menu.lv = 1
      menu.max_count = 1
    else
      menu.lv = 0
      menu.max_count = -1               -- 0 means unlockable.
    end
    HeroMenu[hero_id] = menu
  end
end

if (nil == HeroMenu) then
  ResetHeroMenu()
end

function InitHeroMenu(menu, hero_id)
  local hero = HeroData[hero_id]
  menu.gen_cd = GetLevelCdValue(menu.lv, hero.GenCd)
  menu.put_cost = GetLevelValue(menu.lv, hero.PutCost)
  menu.upgrade_cost = GetLevelValue(menu.lv, hero.UpgradeCost)
  menu.count = 0
  menu.cd = 0
  local x = HERO_MENU_OFFSET_X + (hero_id - 1) * HERO_MENU_W
  local y = HERO_MENU_OFFSET_Y
  local dummy = Good.GenDummy(-1)
  Good.SetPos(dummy, x, y)
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
  menu.read_only = false
end

function UpdateHeroMenuInfo(menu)
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

function UpdateHeroMenuState_i(HeroMenu)
  local IsInGame = InGame()
  for  i = 1, #HeroMenu do
    local menu = HeroMenu[i]
    if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
      Good.SetAlpha(menu.o, 128)
      Good.SetBgColor(menu.cd_obj, HERO_MENU_DISABLE_COLOR)
    elseif (IsInGame) then
      if (i == SelHero or nil == SelHero) then
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
  UpdateHeroMenuSel_i(HeroMenu)
end

function UpdateHeroMenuCd()
  for i = 1, #HeroMenu do
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
  max_stage_id = 1
  ResetCityOwner()
  ResetCityHero()
  ResetPlayers()
  curr_play_time = 0
  for i = 1, MAX_HERO do
    CurrKillEnemy[i] = 0
  end
  ResetHeroMenu()
  reset_count = reset_count + 1
end

LoadGame()

function SaveGame()
  local outf = io.open(SAV_FILE_NAME, "w")
  outf:write(string.format('reset_count=%d\n', reset_count))
  outf:write(string.format('coin_count=%d\n', coin_count))
  outf:write(string.format('max_stage_id=%d\n', max_stage_id))
  outf:write(string.format('max_max_stage_id=%d\n', max_max_stage_id))
  outf:write(string.format('max_combat_power=%d\n', max_combat_power))
  outf:write(string.format('curr_total_coin_count=%d\n', curr_total_coin_count))
  outf:write(string.format('total_coin_count=%d\n', total_coin_count))
  outf:write(string.format('curr_play_time=%d\n', curr_play_time))
  outf:write(string.format('total_play_time=%d\n', total_play_time))
  for hero_id = 1, MAX_HERO do
    outf:write(string.format('CurrKillEnemy[%d]=%d\n', hero_id, CurrKillEnemy[hero_id]))
    outf:write(string.format('TotalKillEnemy[%d]=%d\n', hero_id, TotalKillEnemy[hero_id]))
  end
  for i = 1, MAX_CITY do
    outf:write(string.format('city_owner[%d]=%d\n', i, city_owner[i]))
    outf:write(string.format('city_hero[%d]={', i))
    local heroes = city_hero[i]
    for j = 1, #heroes do
      if (MAX_HERO == j) then
        outf:write(string.format('%d', heroes[j]))
      else
        outf:write(string.format('%d,', heroes[j]))
      end
    end
    outf:write(string.format('}\n'))
  end
  for i = 1, MAX_PLAYER do
    outf:write(string.format('players[%d]=%d\n', i, players[i]))
    outf:write(string.format('players_coin[%d]=%d\n', i, players_coin[i]))
  end
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

function GetFirstCurrPlayerCityId()
  local id = players[curr_player_idx]
  for i = 1, MAX_CITY do
    if (id == city_owner[i]) then
      return i
    end
  end
  return -1
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

function GetPlayerIdx(id)
  for i = 1, MAX_PLAYER do
    if (players[i] == id) then
      return i
    end
  end
  return -1
end

function GetHarvestOfRound()
  for i = 1, MAX_CITY do
    if (0 < city_owner[i]) then
      local coin = 100 + GetHeroCombatPower(i)
      local player_idx = GetPlayerIdx(city_owner[i])
      players_coin[player_idx] = players_coin[player_idx] + coin
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
    local hero = HeroData[hero_id]
    local x = HERO_MENU_OFFSET_X + (hero_id - 1) * HERO_MENU_W
    local y = HERO_MENU_OFFSET_Y
    local dummy = Good.GenDummy(hero_menu)
    Good.SetPos(dummy, x, y)
    local menu = {}
    menu.lv = heroes[hero_id]
    menu.gen_cd = GetLevelCdValue(menu.lv, hero.GenCd)
    menu.put_cost = GetLevelValue(menu.lv, hero.PutCost)
    menu.upgrade_cost = GetLevelValue(menu.lv, hero.UpgradeCost)
    menu.count = 0
    menu.max_count = math.min(menu.lv, hero.MaxCount)
    max_count[hero_id] = menu.max_count
    if (1 < hero_id and 0 == max_count[hero_id - 1]) then
      menu.max_count = -1
    end
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
    menu.read_only = read_only
    menu.info_obj = nil
    HeroMenu[hero_id] = menu
    UpdateHeroMenuInfo(menu)
  end
  UpdateHeroMenuState_i(HeroMenu)
end
