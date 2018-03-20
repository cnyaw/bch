local SAV_FILE_NAME = "bch.sav"
local UPGRADE_CD_CURVE = 1.05
local UPGRADE_CURVE = 1.2
local MENU_TEXT_OFFSET_X, MENU_TEXT_OFFSET_Y = 2, 2
local MENU_TEXT_SIZE = 15
local HERO_UPGRADE_DISABLE_COLOR = 0xff505050
local HERO_MENU_DISABLE_COLOR = 0xff808080
local HERO_MENU_DESEL_COLOR = 0xff4c8000
local HERO_MENU_SEL_COLOR = 0xff8cff00
local MAX_CITY = 24
local MAX_PLAYER = 10

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

city_stage_id = nil

function ResetCityStageId()
  city_stage_id = {}
  for i = 1, MAX_CITY do
    city_stage_id[i] = 1
  end
end

if (nil == city_stage_id) then
  ResetCityStageId()
end

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

function shuffle(a)
  local len = #a
  for i = len, 1, -1 do
    local r = math.random(len)
    a[i], a[r] = a[r], a[i]
  end
end

players = nil
my_player_id = nil

function ResetPlayers()
  players = {}
  for i = 1, MAX_PLAYER do
    players[i] = i
  end
  shuffle(players, MAX_PLAYER - 1)
  for i = 1, MAX_PLAYER do
    city_owner[i] = players[i]
  end
  my_player_id = math.random(MAX_PLAYER)
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

function GenHeroMenu()
  HeroMenu = {}
  for hero_id = 1, 6 do
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
  GenHeroMenu()
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
end

function UpdateHeroMenuInfo(menu)
  if (nil ~= menu.info_obj) then
    Good.KillObj(menu.info_obj)
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

function isInGame()
  return game_lvl_id == Good.GetLevelId()
end

function UpdateHeroMenuSel()
  local inGame = isInGame()
  for  i = 1, #HeroMenu do
    local menu = HeroMenu[i]
    if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
      Good.SetAlpha(menu.o, 128)
      Good.SetBgColor(menu.cd_obj, HERO_MENU_DISABLE_COLOR)
    elseif (inGame) then
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
    if (coin_count < menu.upgrade_cost) then
      Good.SetBgColor(menu.btn_obj, HERO_UPGRADE_DISABLE_COLOR)
    else
      Good.SetBgColor(menu.btn_obj, 0xffffffff)
    end
  end
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
  coin_count = 200
  curr_total_coin_count = 0
  max_stage_id = 1
  ResetCityStageId()
  ResetCityOwner()
  ResetPlayers()
  curr_play_time = 0
  for i = 1, 6 do
    CurrKillEnemy[i] = 0
  end
  GenHeroMenu()
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
  for hero_id = 1, 6 do
    outf:write(string.format('CurrKillEnemy[%d]=%d\n', hero_id, CurrKillEnemy[hero_id]))
    outf:write(string.format('TotalKillEnemy[%d]=%d\n', hero_id, TotalKillEnemy[hero_id]))
  end
  for hero_id = 1, 6 do
    local menu = HeroMenu[hero_id]
    outf:write(string.format('HeroMenu[%d].lv=%d\n', hero_id, menu.lv))
    outf:write(string.format('HeroMenu[%d].max_count=%d\n', hero_id, menu.max_count))
  end
  for i = 1, MAX_CITY do
    outf:write(string.format('city_stage_id[%d]=%d\n', i, city_stage_id[i]))
    outf:write(string.format('city_owner[%d]=%d\n', i, city_owner[i]))
  end
  outf:write(string.format('my_player_id=%d\n', my_player_id))
  for i = 1, MAX_PLAYER do
    outf:write(string.format('players[%d]=%d\n', i, players[i]))
  end
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

function GetMaxStageId()
  local max_id = 0
  for i = 1, MAX_CITY do
    if (my_player_id == city_owner[i] and city_stage_id[i] > max_id) then
      max_id = city_stage_id[i]
    end
  end
  return max_id
end

function UpdateMaxStageId()
  max_stage_id = math.max(max_stage_id, GetMaxStageId())
  max_max_stage_id = math.max(max_max_stage_id, max_stage_id)
end

function StageClear(city_id)
  if (my_player_id ~= city_owner[city_id]) then
    city_owner[city_id] = my_player_id
  else
    city_stage_id[city_id] = city_stage_id[city_id] + 1
    UpdateMaxStageId()
  end
end

function PtInObj(mx, my, o)
  local l,t,w,h = Good.GetDim(o)
  local x, y = Good.GetPos(o)
  return PtInRect(mx, my, x, y, x + w, y + h)
end
