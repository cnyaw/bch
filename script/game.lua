local NEXT_WAVE_POS = {4, 3, 5, 2, 6, 1, 7, 0, 8}
local INIT_GAME_POS = {{31, 29, 33, 27, 35}, {3, 5}, {2, 6}, {1, 7}, {19, 25}, {0, 8}}
local INIT_KING_POS = 85

local RESET_WAIT_TIME = 120

local map_id = 2
local coin_id = 13
local map_lvl_id = 39
local combat_id = 15
local sand_glass_id = 17
local castle_id = 26
local menu_id = 28
local king_hero_id = 50
local game_lvl_id = 0

hud_obj = nil
local coin_obj = nil

local curr_stage_id = 1
local stage_heroes_count = {}
local stage_heroes_obj = nil
local king_obj = nil

local next_wave_heroes = {}
local next_wave_pos = 0

local stage = nil

local menu_obj = nil
local reset_timeout = nil
local reset_timer = RESET_WAIT_TIME

Game = {}

Game.OnCreate = function(param)
  MAP_X, MAP_Y = Good.GetPos(map_id)
  hud_obj = nil
  coin_obj = nil
  reset_timeout = nil
  glass_speed = 1
  next_wave_pos = 0
  InitOccupyMap()
  InitHero()
  curr_stage_id = sel_stage_id
  king_obj = AddMyHero(king_hero_id, INIT_KING_POS, GetKingLv())
  stage_heroes_obj = nil
  next_wave_heroes = {}
  InitStage(sel_stage_id)
  -- Hero menu.
  SelHero = nil
  for hero_id = 1, 6 do
    local menu = HeroMenu[hero_id]
    InitHeroMenu(menu, hero_id)
    -- Put init my heroes.
    local hero_count = menu.max_count
    local init_pos = INIT_GAME_POS[hero_id]
    for j = 1, #init_pos do
      if (0 >= hero_count) then
        break
      end
      local pos = ConvertRedPos(init_pos[j])
      AddMyHero(hero_id, pos, menu.lv)
      menu.count = menu.count + 1
      hero_count = hero_count - 1
    end
    UpdateHeroMenuInfo(menu)
  end
  UpdateCoinCountObj(true)
  UpdateHeroMenuSel()
  -- Init stage.
  param.step = OnGamePlaying
end

Game.OnStep = function(param)
  param.step(param)
  curr_play_time = curr_play_time + 1
  total_play_time = total_play_time + 1
end

function CloseGameMenu(param)
  SaveGame()
  Good.KillObj(menu_obj)
  reset_timeout = nil
  param.step = OnGamePlaying
end

function HandleQuitGame()
  SaveGame()
  Good.GenObj(-1, map_lvl_id)
end

function HandleResetGame(btn_reset)
  if (nil == reset_timeout) then
    reset_timeout = Good.GenTextObj(btn_reset, 'Push again to reset', TILE_H/3)
    Good.SetPos(reset_timeout, 0, -TILE_H/2)
    reset_timer = RESET_WAIT_TIME
    return
  end
  ResetGame()
  reset_count = reset_count + 1
  SaveGame()
  Good.GenObj(-1, map_lvl_id)
end

function OnGameMenu(param)
  UpdateStatistics()
  UpdateHeroMenuCd()
  if (nil ~= reset_timeout and 0 < reset_timer) then
    reset_timer = reset_timer - 1
    if (0 >= reset_timer) then
      Good.KillObj(reset_timeout)
      reset_timeout = nil
    end
  end
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    CloseGameMenu(param)
    return
  end
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    local mouse_x, mouse_y = Input.GetMousePos()
    local menu_x, menu_y = Good.GetPos(menu_obj)
    local btn_quit = Good.FindChild(menu_obj, 'quit game')
    local l,t,w,h = Good.GetDim(btn_quit)
    local x, y = Good.GetPos(btn_quit)
    x = x + menu_x
    y = y + menu_y
    if (PtInRect(mouse_x, mouse_y, x, y, x + w, y + h)) then
      HandleQuitGame()
      return
    end
    local btn_reset = Good.FindChild(menu_obj, 'reset game')
    l,t,w,h = Good.GetDim(btn_reset)
    x, y = Good.GetPos(btn_reset)
    x = x + menu_x
    y = y + menu_y
    if (PtInRect(mouse_x, mouse_y, x, y, x + w, y + h)) then
      HandleResetGame(btn_reset)
      return
    end
  end
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
  if (OnGamePlaying ~= param.step) then
    return
  end
  if (IsGameComplete()) then
    ShowGameOver(param, 'Stage Clear', 0xff00137f)
    param.step = OnGameOverEnter
  elseif (IsGameOver()) then
    ShowGameOver(param, 'Game Over', 0xff500000)
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
    local l,t,mw,mh = Good.GetDim(map_id) -- map dim.
    local x, y = Input.GetMousePos()
    if (PtInRect(x, y, WND_W - 2 * TILE_W, 0, WND_W, TILE_H)) then
      ToggleSandGlassSpeed()
    elseif (PtInRect(x, y, MAP_X, MAP_Y, MAP_X + mw, MAP_Y + mh)) then
      PutHero(x, y, mw, mh)
    elseif (PtInRect(x, y, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y, HERO_MENU_OFFSET_X + HERO_MENU_W * #HeroMenu, WND_H)) then
      SelectHero(x, y)
    end
  end
end

function OnGameOverEnter(param)
  -- NOP.
end

function OnGameOver(param)
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    if (IsGameComplete()) then
      if (0 == sel_city_id) then
        max_stage_id = max_stage_id + 1
        max_max_stage_id = math.max(max_max_stage_id, max_stage_id)
      else
        city_max_stage_id[sel_city_id] = city_max_stage_id[sel_city_id] + 1
        max_max_stage_id = math.max(max_max_stage_id, city_max_stage_id[sel_city_id])
      end
    end
    SaveGame()
    Good.GenObj(-1, map_lvl_id)
    return
  end
end

function AddCoin(coin)
  coin_count = coin_count + coin
  curr_total_coin_count = curr_total_coin_count + coin
  total_coin_count = total_coin_count + coin
  UpdateCoinCountObj(true)
  UpdateHeroMenuSel()
end

function AddCoinObj(id)
  if (IsGameOver() or IsGameComplete()) then
    return
  end
  local o = Good.GenObj(-1, coin_id, 'AnimFlyCoinObj')
  local x, y = Good.GetPos(id)
  Good.SetPos(o, MAP_X + x, MAP_Y + y)
  local param = Good.GetParam(o)
  param.coin = math.random(stage.Coin[1], stage.Coin[2])
end

function GetKingLv()
  return 1 + curr_stage_id/25
end

function PrepareSelectableHeroes(stage, selectable_hero)
  local remain_hero_count = 0
  for i = 1, #stage.Heroes do
    local hero_config = stage.Heroes[i]
    local hero_id = hero_config[1]
    local hero_count = stage_heroes_count[hero_id]
    if (0 < hero_count) then
      selectable_hero[hero_id] = {hero_count}
      remain_hero_count = remain_hero_count + hero_count
    end
  end
  return remain_hero_count
end

function AddStageNextHeroInfo()
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
  local sand_glass_obj = Good.GenObj(-1, sand_glass_id, 'AnimSandGlass')
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
  stage = GetStageData(curr_stage_id)
  if (nil == stage) then
    return
  end
  -- Prepare selectable heroes for next wave.
  local selectable_hero = {}
  local remain_hero_count = PrepareSelectableHeroes(stage, selectable_hero)
  if (0 >= remain_hero_count) then
    return
  end
  -- Select next wave heroes.
  next_wave_heroes = {}
  local pos = 1
  local select_count = 0
  local try_count = 100
  while 0 < remain_hero_count and select_count < stage.Wave[2] do
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
          local o = GenEnemyHeroObj(hero_id, NEXT_WAVE_POS[pos], GetEnemyLevel(curr_stage_id))
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
  AddStageNextHeroInfo()
  -- Add sand glass obj.
  GenSandGlassObj(stage.Wave[1])
end

function InitStage(stage_id)
  if (nil ~= stage_heroes_obj) then
    Good.KillObj(stage_heroes_obj)
    stage_heroes_obj = nil
  end
  stage = GetStageData(stage_id)
  if (nil == stage) then
    return
  end
  -- Save hero list and count of this stage.
  curr_stage_id = stage_id
  stage_heroes_count = {}
  for i = 1, #stage.Heroes do
    local hero_config = stage.Heroes[i]
    local hero_id = hero_config[1]
    local hero_count = hero_config[2]
    -- Put init enemy heroes.
    local init_pos = INIT_GAME_POS[hero_id]
    for j = 1, #init_pos do
      if (0 >= hero_count) then
        break
      end
      local pos = init_pos[j]
      local o = GenEnemyHeroObj(hero_id, pos, GetEnemyLevel(stage_id))
      OccupyMap[pos] = o
      AddEnemyHeroObj(o)
      hero_count = hero_count - 1
    end
    stage_heroes_count[hero_id] = hero_count
  end
  InitNextWave()
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
  local remain_hero_count = 0
  for hero_id, hero_count in pairs(stage_heroes_count) do
    remain_hero_count = remain_hero_count + hero_count
  end
  if (0 < remain_hero_count) then
    return false
  end
  local enemy_count = GetEnemyHeroCount()
  if (0 < enemy_count) then
    return false
  end
  return true
end

function KillSelHero(hero_id)
  if (king_hero_id == hero_id) then
    return
  end
  local menu = HeroMenu[hero_id]
  menu.count = menu.count - 1
  UpdateHeroMenuInfo(menu)
  UpdateHeroMenuSel()
end

function PutHero(x, y, mw, mh)
  -- Put selected hero on the battle field.
  if (nil == SelHero) then
    return
  end
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
      UpdateCoinCountObj(true)
      menu.count = menu.count + 1
      UpdateHeroMenuInfo(menu)
      if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
        SelHero = nil
      end
      UpdateHeroMenuSel()
    end
  end
end

function SelectHero(x, y)
  local inGame = game_lvl_id == Good.GetLevelId()
  local NewSelHero = 1 + math.floor((x - HERO_MENU_OFFSET_X) / HERO_MENU_W)
  local menu = HeroMenu[NewSelHero]
  if (PtInRect(x, y, HERO_MENU_OFFSET_X, HERO_MENU_OFFSET_Y + HERO_MENU_H - 26, HERO_MENU_OFFSET_X + HERO_MENU_W * #HeroMenu, WND_H)) then
    if (coin_count >= menu.upgrade_cost) then
      coin_count = coin_count - menu.upgrade_cost
      local hero = HeroData[NewSelHero]
      menu.lv = menu.lv + 1
      menu.max_count = math.min(hero.MaxCount, menu.max_count + 1)
      menu.upgrade_cost = GetLevelValue(menu.lv, hero.UpgradeCost)
      menu.put_cost = GetLevelValue(menu.lv, hero.PutCost)
      menu.gen_cd = GetLevelCdValue(menu.lv, hero.GenCd)
      UpdateHeroMenuInfo(menu)
      if (NewSelHero ~= #HeroMenu) then
        menu = HeroMenu[NewSelHero + 1]
        if (0 >= menu.max_count) then
          menu.max_count = 0        -- unlock to set count to 1.  
          UpdateHeroMenuInfo(menu)
        end
      end
      UpdateCoinCountObj(inGame)
      if (inGame) then
        UpgradeHeroOnField(NewSelHero)
      end
      SaveGame()
    end
  else
    if (NewSelHero == SelHero) then
      return
    end
    if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
      return
    end
    SelHero = NewSelHero
  end
  UpdateHeroMenuSel()
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
end

function ShowGameOver(param, msg, clr)
  local o = GenColorObj(-1, WND_W, WND_H + 10, clr, 'AnimGameOver')
  local s = Good.GenTextObj(o, msg, 64)
  local slen = GetTextObjWidth(s)
  Good.SetPos(s, (WND_W - slen)/2, 3/7 * WND_H)
  Good.SetPos(o, 0, -WND_H)
  local p = Good.GetParam(o)
  p.lvl_param = param
end

function UpdateCoinCountObj(ShowStage)
  if (nil ~= coin_obj) then
    Good.KillObj(coin_obj)
  end
  if (nil == hud_obj) then
    hud_obj = Good.GenDummy(-1)
  end
  coin_obj = Good.GenDummy(hud_obj)
  local scale = (TILE_W/2) / 32
  local o = Good.GenObj(coin_obj, coin_id)
  Good.SetScale(o, scale, scale)
  o = Good.GenTextObj(coin_obj, string.format('%d', coin_count), TILE_W/2)
  Good.SetPos(o, TILE_W/2, 0)
  local combat_obj = Good.GenObj(coin_obj, combat_id)
  local x = (WND_W - TILE_W/2)/4
  Good.SetPos(combat_obj, x, 0)
  Good.SetScale(combat_obj, scale, scale)
  o = Good.GenTextObj(coin_obj, string.format('%d', GetCombatPower()), TILE_W/2)
  Good.SetPos(o, x + TILE_W/2, 0)
  if (ShowStage) then
    local castle_obj = Good.GenObj(coin_obj, castle_id)
    local x = (WND_W - TILE_W/2)/2
    Good.SetPos(castle_obj, x, 0)
    Good.SetScale(castle_obj, scale, scale)
    o = Good.GenTextObj(coin_obj, string.format('%d', curr_stage_id), TILE_W/2)
    Good.SetPos(o, x + TILE_W/2, 0)
  end
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
  local STAT_TEXT_SIZE = TILE_H/2
  local SMALL_STAT_TEXT_SIZE = TILE_H/3
  local OFFSET_1 = 1.05
  local OFFSET_2 = 0.65
  local TextColor = 0xffa0a0a0
  -- Kills.
  local s_kill = Good.GenTextObj(dummy, 'Kill', STAT_TEXT_SIZE)
  Good.SetPos(s_kill, 0, TILE_H/2)
  local offset = 1.4
  for hero_id = 1, 6 do
    local hero_obj = GenHeroPieceObj(s_kill, HeroData[hero_id].Face, false, '')
    Good.SetScale(hero_obj, 0.5, 0.5)
    Good.SetPos(hero_obj, 0, TILE_W/2 * offset)
    local hero_count = Good.GenTextObj(s_kill, string.format('%d', CurrKillEnemy[hero_id]), STAT_TEXT_SIZE)
    Good.SetPos(hero_count, TILE_W, TILE_W/2 * offset)
    offset = offset + OFFSET_1
    hero_count = Good.GenTextObj(s_kill, string.format('%d', TotalKillEnemy[hero_id]), SMALL_STAT_TEXT_SIZE)
    SetTextObjColor(hero_count, TextColor)
    Good.SetPos(hero_count, TILE_W, TILE_W/2 * offset)
    offset = offset + OFFSET_2
  end
  -- Stats.
  local s_max = Good.GenTextObj(dummy, string.format('Stats (%d)', reset_count), STAT_TEXT_SIZE)
  Good.SetPos(s_max, 3 * TILE_W, TILE_H/2)
  offset = 1.4
  local scale = (TILE_W/2) / 32
  local max_stage_obj = Good.GenObj(s_max, castle_id, '')
  Good.SetScale(max_stage_obj, scale, scale)
  Good.SetPos(max_stage_obj, 0, TILE_W/2 * offset)
  local s_max_stage_obj = Good.GenTextObj(s_max, string.format('%d', max_stage_id), STAT_TEXT_SIZE)
  Good.SetPos(s_max_stage_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_1
  s_max_stage_obj = Good.GenTextObj(s_max, string.format('%d', max_max_stage_id), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_max_stage_obj, TextColor)
  Good.SetPos(s_max_stage_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_2
  local max_combat_obj = Good.GenObj(s_max, combat_id, '')
  Good.SetScale(max_combat_obj, scale, scale)
  Good.SetPos(max_combat_obj, 0, TILE_W/2 * offset)
  local s_max_combat_obj = Good.GenTextObj(s_max, string.format('%d', GetCombatPower()), STAT_TEXT_SIZE)
  Good.SetPos(s_max_combat_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_1
  s_max_combat_obj = Good.GenTextObj(s_max, string.format('%d', max_combat_power), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_max_combat_obj, TextColor)
  Good.SetPos(s_max_combat_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_2
  local max_coin_obj = Good.GenObj(s_max, coin_id, '')
  Good.SetScale(max_coin_obj, scale, scale)
  Good.SetPos(max_coin_obj, 0, TILE_W/2 * offset)
  local s_total_coin_obj = Good.GenTextObj(s_max, string.format('%d', curr_total_coin_count), STAT_TEXT_SIZE)
  Good.SetPos(s_total_coin_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_1
  s_total_coin_obj = Good.GenTextObj(s_max, string.format('%d', total_coin_count), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_total_coin_obj, TextColor)
  Good.SetPos(s_total_coin_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_2
  scale = (TILE_W/2)/45
  local play_time_obj = Good.GenObj(s_max, sand_glass_id, '')
  Good.SetScale(play_time_obj, scale, scale)
  Good.SetPos(play_time_obj, 4, TILE_W/2 * offset)
  local s_play_time_obj = Good.GenTextObj(s_max, GetFormatTimeStr(curr_play_time), STAT_TEXT_SIZE)
  Good.SetPos(s_play_time_obj, TILE_W, TILE_W/2 * offset)
  offset = offset + OFFSET_1
  s_play_time_obj = Good.GenTextObj(s_max, GetFormatTimeStr(total_play_time), SMALL_STAT_TEXT_SIZE)
  SetTextObjColor(s_play_time_obj, TextColor)
  Good.SetPos(s_play_time_obj, TILE_W, TILE_W/2 * offset)
end
