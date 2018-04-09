local NEXT_WAVE_POS = {4, 3, 5, 2, 6, 1, 7, 0, 8}
local INIT_GAME_POS = {{31, 29, 33, 27, 35}, {3, 5}, {2, 6}, {1, 7}, {19, 25}, {0, 8}}
local INIT_KING_POS = 85
local STAT_TEXT_SIZE = TILE_H/2
local SMALL_STAT_TEXT_SIZE = TILE_H/3
local STATS_TEXT_COLOR = 0xffa0a0a0
local STATS_OFFSET_1 = 1.05
local STATS_OFFSET_2 = 0.65

local RESET_WAIT_TIME = 120

local board_id = 2
local coin_tex_id = 13
local map_lvl_id = 39
local combat_tex_id = 15
local sand_glass_tex_id = 17
local castle_tex_id = 26
local menu_id = 28
local king_hero_id = 50
local win_tex_id = 44
local fail_tex_id = 48

hud_obj = nil
local coin_obj = nil

local stage_heroes_count = {}
local stage_heroes_obj = nil
local king_obj = nil

local next_wave_heroes = {}
local next_wave_pos = 0
local wave_time = 0
local wave_hero_count = 0

local menu_obj = nil
local reset_timeout = nil
local reset_timer = RESET_WAIT_TIME

function GenInitMyHeroes(menu)
  local hero_count = menu.max_count
  local init_pos = INIT_GAME_POS[menu.hero_id]
  for j = 1, #init_pos do
    if (0 >= hero_count) then
      break
    end
    local pos = ConvertRedPos(init_pos[j])
    AddMyHero(menu.hero_id, pos, menu.lv)
    menu.count = menu.count + 1
    hero_count = hero_count - 1
  end
end

Game = {}

Game.OnCreate = function(param)
  MAP_X, MAP_Y = Good.GetPos(board_id)
  hud_obj = nil
  coin_obj = nil
  anim_game_over_obj = nil
  reset_timeout = nil
  glass_speed = 1
  next_wave_pos = 0
  InitOccupyMap()
  InitHero()
  king_obj = AddMyHero(king_hero_id, INIT_KING_POS, 1)
  stage_heroes_obj = nil
  next_wave_heroes = {}
  InitStage()
  InitNextWave()
  InitSetNextWaveHero()
  -- Hero menu.
  SelHero = nil
  local HeroMenu = GenGameHeroMenu(my_sel_city_id)
  for hero_id = 1, MAX_HERO do
    local menu = HeroMenu[hero_id]
    GenInitMyHeroes(menu)
    UpdateHeroMenuItemInfo(menu)
  end
  UpdateCoinCountObj()
  UpdateHeroMenuSel()
  -- Init stage.
  param.step = OnGamePlaying
end

Game.OnStep = function(param)
  param.step(param)
  curr_play_time = curr_play_time + 1
  total_play_time = total_play_time + 1
end

function CloseGameMenu()
  if (nil == menu_obj) then
    return
  end
  SaveGame()
  Good.KillObj(menu_obj)
  menu_obj = nil
  reset_timeout = nil
end

function HandleQuitGame()
  SaveGame()
  if (InGame()) then
    NextTurn()
    Good.GenObj(-1, map_lvl_id)
  else
    Good.Exit()
  end
end

function HandleResetGame(btn_reset)
  if (nil == reset_timeout) then
    reset_timeout = Good.GenTextObj(btn_reset, 'Push again to reset', TILE_H/3)
    Good.SetPos(reset_timeout, 0, TILE_H)
    reset_timer = RESET_WAIT_TIME
    return
  end
  ResetGame()
  SaveGame()
  Good.GenObj(-1, map_lvl_id)
end

function HandleGameMenu(param, next_step)
  if (nil ~= reset_timeout and 0 < reset_timer) then
    reset_timer = reset_timer - 1
    if (0 >= reset_timer) then
      Good.KillObj(reset_timeout)
      reset_timeout = nil
    end
  end
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    CloseGameMenu()
    param.step = next_step
    return
  end
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    local mouse_x, mouse_y = Input.GetMousePos()
    local menu_x, menu_y = Good.GetPos(menu_obj)
    local btn_quit = Good.FindChild(menu_obj, 'quit game')
    if (PtInObj(mouse_x - menu_x, mouse_y - menu_y, btn_quit)) then
      HandleQuitGame()
      return
    end
    local btn_reset = Good.FindChild(menu_obj, 'reset game')
    if (PtInObj(mouse_x - menu_x, mouse_y - menu_y, btn_reset)) then
      HandleResetGame(btn_reset)
      return
    end
  end
end

function OnGameMenu(param)
  UpdateStatistics()
  UpdateHeroMenuCd()
  HandleGameMenu(param, OnGamePlaying)
end

function ToggleSandGlassSpeed()
  if (1 == glass_speed) then
    glass_speed = 2
  else
    glass_speed = 1
  end
end

function CheckGameOver()
  local param = Good.GetParam(Good.GetLevelId())
  if (nil ~= anim_game_over_obj) then
    return
  end
  if (IsGameComplete()) then
    invade_stage_count = invade_stage_count + 1
    total_invade_stage_count = total_invade_stage_count + 1
    if (AllCityClear(sel_city_id)) then
      ShowGameOver(param, OnGameOver, 'Victory', 0xff00137f)
      victory_count = victory_count + 1
      if (0 < victory_min_round) then
        victory_min_round = math.min(victory_min_round, curr_round)
      else
        victory_min_round = curr_round
      end
    else
      ShowGameOver(param, OnGameOver, 'You Win', 0xff00137f)
    end
    param.step = OnGameOverEnter
  elseif (IsGameOver()) then
    ShowGameOver(param, OnGameOver, 'You Fail', 0xff500000)
    param.step = OnGameOverEnter
  end
end

function OnGamePlaying(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnGameMenu
    return
  end
  UpdateHeroMenuCd()
  if (Input.IsKeyPushed(Input.LBUTTON)) then
    local mx, my = Input.GetMousePos()
    local l,t,w,h = Good.GetDim(board_id)
    if (PtInRect(mx, my, WND_W - 2 * TILE_W, 0, WND_W, TILE_H)) then
      ToggleSandGlassSpeed()
    elseif (PtInRect(mx, my, MAP_X, MAP_Y, MAP_X + w, MAP_Y + h)) then
      PutHero(mx, my, w, h)
    elseif (PtInRect(mx, my, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y, HERO_MENU_OFFSET_X + HERO_MENU_W * MAX_HERO, WND_H)) then
      SelHeroMenu(mx, my)
    end
  end
end

function OnGameOverEnter(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    -- NOP.
  end
end

function OnGameOver(param)
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    if (IsGameComplete()) then
      StageClear(sel_city_id)
    end
    NextTurn()
    SaveGame()
    Good.GenObj(-1, map_lvl_id)
    return
  end
end

function AddCoin(coin)
  coin_count = coin_count + coin
  curr_total_coin_count = curr_total_coin_count + coin
  total_coin_count = total_coin_count + coin
  UpdateCoinCountObj()
  UpdateHeroMenuSel()
end

function PrepareSelectableHeroes(heroes, selectable_hero)
  local remain_hero_count = 0
  for hero_id = 1, MAX_HERO do
    local lv = heroes[hero_id]
    if (0 >= lv) then
      break
    end
    local hero_count = stage_heroes_count[hero_id]
    if (0 < hero_count) then
      selectable_hero[hero_id] = {hero_count}
      remain_hero_count = remain_hero_count + hero_count
    end
  end
  return remain_hero_count
end

function GenStageNextHeroInfo()
  if (nil == hud_obj) then
    hud_obj = Good.GenDummy(-1)
  end
  stage_heroes_obj = Good.GenDummy(hud_obj)
  local offset = 0
  for hero_id, hero_count in pairs(stage_heroes_count) do
    local hero = HeroData[hero_id]
    local o = GenHeroPieceObj(stage_heroes_obj, hero.Face, false, '')
    Good.SetScale(o, 0.5, 0.5)
    Good.SetPos(o, TILE_W/2 * offset, TILE_H/2)
    offset = offset + 1
    if (0 < hero_count) then
      Good.SetAlpha(o, 255)
      local o2 = Good.GenTextObj(stage_heroes_obj, string.format('%d', hero_count), TILE_W/2)
      Good.SetPos(o2, TILE_W/2 * offset, TILE_H/2)
    else
      Good.SetAlpha(o, 128)
    end
    offset = offset + 1.2
  end
end

function GenSandGlassObj(wave)
  local sand_glass_obj = Good.GenObj(-1, sand_glass_tex_id, 'AnimSandGlass')
  Good.SetPos(sand_glass_obj, WND_W - TILE_W - 6, -TILE_H/4)
  Good.SetAnchor(sand_glass_obj, 0.5, 0.5)
  local s = (TILE_W/2)/45
  Good.SetScale(sand_glass_obj, s, s)
  if (1 == glass_speed) then
    Good.SetBgColor(sand_glass_obj, 0xffffffff)
  else
    Good.SetBgColor(sand_glass_obj, 0xffff0000)
  end
  local p = Good.GetParam(sand_glass_obj)
  p.wave = wave
end

function InitNextWave()
  if (IsGameOver()) then
    return
  end
  if (nil ~= stage_heroes_obj) then
    Good.KillObj(stage_heroes_obj)
    stage_heroes_obj = nil
  end
  -- Prepare selectable heroes for next wave.
  local heroes = city_hero[sel_city_id]
  local selectable_hero = {}
  local remain_hero_count = PrepareSelectableHeroes(heroes, selectable_hero)
  if (0 >= remain_hero_count) then
    return
  end
  -- Select next wave heroes.
  next_wave_heroes = {}
  local pos = 1
  local select_count = 0
  local try_count = 100
  while 0 < remain_hero_count and select_count < wave_hero_count do
    try_count = try_count - 1
    if (0 >= try_count) then
      break
    end
    local rand_count = math.random(remain_hero_count)
    for hero_id, config in pairs(selectable_hero) do
      local hero_count = config[1]
      if (0 < hero_count) then
        rand_count = rand_count - hero_count
        if (0 >= rand_count) then
          local o = GenEnemyHeroObj(hero_id, NEXT_WAVE_POS[pos], heroes[hero_id])
          table.insert(next_wave_heroes, o)
          InitNextWaveHero(o)
          pos = pos + 1
          select_count = select_count + 1
          config[1] = config[1] - 1
          stage_heroes_count[hero_id] = stage_heroes_count[hero_id] - 1
          remain_hero_count = remain_hero_count - 1
          break
        end
      end
    end
  end
  -- Gen stage heroes info.
  GenStageNextHeroInfo()
  -- Add sand glass obj.
  GenSandGlassObj(wave_time)
end

function GenInitEnemyHeroes(hero_id, lv)
  local hero_count = lv                 -- Init count = lv.
  local init_pos = INIT_GAME_POS[hero_id]
  for j = 1, #init_pos do
    if (0 >= hero_count) then
      break
    end
    local pos = init_pos[j]
    local o = GenEnemyHeroObj(hero_id, pos, lv)
    OccupyMap[pos] = o
    AddEnemyHeroObj(o)
    hero_count = hero_count - 1
  end
  return hero_count
end

function InitStage()
  if (nil ~= stage_heroes_obj) then
    Good.KillObj(stage_heroes_obj)
    stage_heroes_obj = nil
  end
  -- Save hero list and count of this stage.
  local heroes = city_hero[sel_city_id]
  local total_hero_count = 0
  for i = 1, MAX_HERO do
    total_hero_count = total_hero_count + heroes[i]
  end
  wave_time = math.max(5, 10 - math.floor(total_hero_count / 20))
  wave_hero_count = math.min(9, 2 + math.floor(total_hero_count / 15))
  stage_heroes_count = {}
  for hero_id = 1, MAX_HERO do
    local lv = heroes[hero_id]
    stage_heroes_count[hero_id] = GenInitEnemyHeroes(hero_id, lv)
  end
end

function IsGameOver()
  if (nil == king_obj) then
    return true
  end
  return not IsHeroAlive(king_obj)
end

function IsGameComplete()
  if (0 < #next_wave_heroes) then
    return false
  end
  if (0 < GetSetNextWaveHeroCount()) then
    return false
  end
  for hero_id, hero_count in pairs(stage_heroes_count) do
    if (0 < hero_count) then
      return false
    end
  end
  if (0 < GetEnemyHeroCount()) then
    return false
  end
  return true
end

function KillSelHero(hero_id)
  if (king_hero_id == hero_id) then
    return
  end
  local HeroMenu = GetHeroMenu()
  local menu = HeroMenu[hero_id]
  menu.count = menu.count - 1
  UpdateHeroMenuItemInfo(menu)
  UpdateHeroMenuSel()
end

function PutHero(x, y, mw, mh)
  -- Put selected hero on the battle field.
  if (nil == SelHero) then
    return
  end
  local HeroMenu = GetHeroMenu()
  local menu = HeroMenu[SelHero]
  if (0 >= menu.cd and coin_count >= menu.put_cost and menu.count < menu.max_count) then
    if (PtInRect(x, y, MAP_X, MAP_Y, MAP_X + mw, MAP_Y + 5 * TILE_H)) then
      local o = GenColorObj(-1, mw, 4.5 * TILE_H, 0xffff0000, 'AnimWarnPutHero')
      Good.SetPos(o, MAP_X, MAP_Y + 5 * TILE_H)
      return
    end
    local col = math.floor((x - MAP_X) / TILE_W)
    local row = math.floor((y - MAP_Y) / TILE_H)
    local pos = col + row * MAP_W
    if (-1 ~= AddMyHero(SelHero, pos, menu.lv)) then
      menu.cd = menu.gen_cd
      coin_count = coin_count - HeroMenu[SelHero].put_cost
      UpdateCoinCountObj()
      menu.count = menu.count + 1
      UpdateHeroMenuItemInfo(menu)
      if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
        SelHero = nil
      end
      UpdateHeroMenuSel()
    end
  end
end

function SelHeroMenu(x, y)
  local NewSelHero = 1 + math.floor((x - HERO_MENU_OFFSET_X) / HERO_MENU_W)
  local HeroMenu = GetHeroMenu()
  local menu = HeroMenu[NewSelHero]
  if (PtInRect(x, y, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y + HERO_MENU_H - 26, HERO_MENU_OFFSET_X + HERO_MENU_W * MAX_HERO, WND_H)) then
    if (not menu.read_only and coin_count >= menu.upgrade_cost) then
      return true, menu
    end
  else
    if (NewSelHero == SelHero) then
      return false
    end
    if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
      return false
    end
    SelHero = NewSelHero
  end
  UpdateHeroMenuSel()
  return false
end

function ShowGameMenu()
  local o = Good.GenObj(-1, menu_id, '')
  local l,t,w,h = Good.GetDim(o)
  Good.SetPos(o, (WND_W - w)/2, (WND_H - h)/2)
  menu_obj = o
  -- Buttons.
  local btn_quit = Good.FindChild(o, 'quit game')
  l,t,w,h = Good.GetDim(btn_quit)
  local s_quit = Good.GenTextObj(btn_quit, 'Quit', TILE_H/2)
  local slen_quit = GetTextObjWidth(s_quit)
  Good.SetPos(s_quit, (w - slen_quit)/2, (h - TILE_H/2)/2)
  local btn_reset = Good.FindChild(o, 'reset game')
  l,t,w,h = Good.GetDim(btn_reset)
  local s_reset = Good.GenTextObj(btn_reset, 'Reset', TILE_H/2)
  local slen_reset = GetTextObjWidth(s_reset)
  Good.SetPos(s_reset, (w - slen_reset)/2, (h - TILE_H/2)/2)
  -- Statistics.
  UpdateStatistics()
  return o
end

function UpdateCoinCountObj()
  if (nil ~= coin_obj) then
    Good.KillObj(coin_obj)
    coin_obj = nil
  end
  if (nil == hud_obj) then
    hud_obj = Good.GenDummy(-1)
  end
  coin_obj = Good.GenDummy(hud_obj)
  local scale = (TILE_W/2) / 32
  local o = Good.GenObj(coin_obj, coin_tex_id)
  Good.SetScale(o, scale, scale)
  o = Good.GenTextObj(coin_obj, string.format('%d', coin_count), TILE_W/2)
  Good.SetPos(o, TILE_W/2, 0)
end

function UpdateStage()
  for i = 1, #next_wave_heroes do
    SetNextWaveHero(next_wave_heroes[i], next_wave_pos)
  end
  if (0 == next_wave_pos) then
    next_wave_pos = 45
  else
    next_wave_pos = 0
  end
  next_wave_heroes = {}
  InitNextWave()
end

function UpdateStatistics()
  local msg_dummy = Good.FindChild(menu_obj, 'msg dummy')
  Good.KillObj(Good.GetChild(msg_dummy, 0)) -- First child is the dummy of msgs.
  local dummy = Good.GenDummy(msg_dummy)
  GenKillsInfo(dummy)
  GenStatsInfo(dummy)
end

function GenKillsInfo(dummy)
  local s_kill = Good.GenTextObj(dummy, 'Kill', STAT_TEXT_SIZE)
  Good.SetPos(s_kill, 0, TILE_H/2)
  local offset = 1.4
  for hero_id = 1, MAX_HERO do
    local hero_obj = GenHeroPieceObj(s_kill, HeroData[hero_id].Face, false, '')
    Good.SetScale(hero_obj, 0.5, 0.5)
    Good.SetPos(hero_obj, 0, TILE_W/2 * offset)
    local hero_count = Good.GenTextObj(s_kill, string.format('%d', CurrKillEnemy[hero_id]), STAT_TEXT_SIZE)
    Good.SetPos(hero_count, TILE_W, TILE_W/2 * offset)
    offset = offset + STATS_OFFSET_1
    hero_count = Good.GenTextObj(s_kill, string.format('%d', TotalKillEnemy[hero_id]), SMALL_STAT_TEXT_SIZE)
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
  s_max_combat_obj = Good.GenTextObj(s_max, string.format('%d', max_combat_power), SMALL_STAT_TEXT_SIZE)
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
