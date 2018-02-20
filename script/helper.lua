local SAV_FILE_NAME = "bch.sav"
local UPGRADE_CD_CURVE = 1.05
local UPGRADE_CURVE = 1.2

Graphics.SetAntiAlias(1)                -- Enable anti alias.

WND_W, WND_H = Good.GetWindowSize()

MAP_X, MAP_Y = 0, 0
MAP_W, MAP_H = 9, 10
TILE_W, TILE_H = 44, 44

sel_stage_id = 1
max_stage_id = 1
max_max_stage_id = 1

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
  curr_play_time = 0
  for i = 1, 6 do
    CurrKillEnemy[i] = 0
  end
  GenHeroMenu()
end

function SaveGame()
  local outf = io.open(SAV_FILE_NAME, "w")
  outf:write(string.format('reset_count=%d\n', reset_count))
  outf:write(string.format('coin_count=%d\n', coin_count))
  outf:write(string.format('max_stage_id=%d\n', max_stage_id))
  for hero_id = 1, 6 do
    local menu = HeroMenu[hero_id]
    outf:write(string.format('HeroMenu[%d].lv=%d\n', hero_id, menu.lv))
    outf:write(string.format('HeroMenu[%d].max_count=%d\n', hero_id, menu.max_count))
  end
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
  outf:close()
end

function GetLevelCdValue(lv, init_val)
  return math.floor(init_val * math.pow(UPGRADE_CD_CURVE, lv))
end

function GetLevelValue(lv, init_val)
  return math.floor(init_val * math.pow(UPGRADE_CURVE, lv))
end
