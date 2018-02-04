
local HERO_MENU_W, HERO_MENU_H = 65, 2.2 * TILE_H
local HERO_MENU_OFFSET_X = (WND_W - 6 * HERO_MENU_W) / 2
local HERO_MENU_OFFSET_Y = WND_H - HERO_MENU_H

local HERO_UPGRADE_DISABLE_COLOR = 0xff505050
local HERO_MENU_DISABLE_COLOR = 0xff808080
local HERO_MENU_DESEL_COLOR = 0xff4c8000
local HERO_MENU_SEL_COLOR = 0xff8cff00

local MENU_TEXT_OFFSET_X, MENU_TEXT_OFFSET_Y = 2, 2
local MENU_TEXT_SIZE = 15

local NEXT_WAVE_POS = {4, 3, 5, 2, 6, 1, 7, 0, 8}
local INIT_GAME_POS = {{31, 29, 33, 27, 35}, {3, 5}, {2, 6}, {1, 7}, {19, 25}, {0, 8}}
local INIT_KING_POS = 85

local RESET_WAIT_TIME = 120

local map_id = 2
local button_id = 3
local coin_id = 13
local stage_lvl_id = 14
local combat_id = 15
local sand_glass_id = 17
local castle_id = 26
local menu_id = 28
local king_hero_id = 50

local hud_obj = nil
local coin_obj = nil

local init_game = false
local curr_stage_id = 1
local stage_heroes_count = {}
local stage_heroes_obj = nil
local king_obj = nil

local next_wave_heroes = {}
local next_wave_pos = 0

local SelHero = nil

if (nil == HeroMenu) then
  InitMenu()
end

local stage = nil

local menu_obj = nil
local reset_timeout = nil
local reset_timer = RESET_WAIT_TIME

Game = {}

Game.OnCreate = function(param)
  MAP_X, MAP_Y = Good.GetPos(map_id)
  init_game = true
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
  InitStage(sel_stage_id)
  -- Hero menu.
  SelHero = nil
  for hero_id = 1, 6 do
    local menu = HeroMenu[hero_id]
    local hero = HeroData[hero_id]
    menu.gen_cd = GetLevelCdValue(menu.lv, hero.GenCd)
    menu.put_cost = GetLevelValue(menu.lv, hero.PutCost)
    menu.upgrade_cost = GetLevelValue(menu.lv, hero.UpgradeCost)
    menu.count = 0
    menu.cd = 0
  end
  for hero_id = 1, 6 do
    local menu = HeroMenu[hero_id]
    local hero = HeroData[hero_id]
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
    -- Put init heroes.
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
    SaveGame()
    Good.KillObj(menu_obj)
    reset_timeout = nil
    param.step = OnGamePlaying
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
      -- Quit game.
      SaveGame()
      sel_stage_id = curr_stage_id
      Good.GenObj(-1, stage_lvl_id)
      return
    end
    local btn_reset = Good.FindChild(menu_obj, 'reset game')
    l,t,w,h = Good.GetDim(btn_reset)
    x, y = Good.GetPos(btn_reset)
    x = x + menu_x
    y = y + menu_y
    if (PtInRect(mouse_x, mouse_y, x, y, x + w, y + h)) then
      -- Reset game.
      if (nil == reset_timeout) then
        reset_timeout = Good.GenTextObj(btn_reset, 'Push again to reset', TILE_H/3)
        Good.SetPos(reset_timeout, 0, -TILE_H/2)
        reset_timer = RESET_WAIT_TIME
        return
      end
      ResetGame()
      reset_count = reset_count + 1
      SaveGame()
      sel_stage_id = curr_stage_id
      Good.GenObj(-1, stage_lvl_id)
      return
    end
  end
end

function OnGamePlaying(param)
  if (Input.IsKeyPressed(Input.ESCAPE)) then
    ShowGameMenu()
    param.step = OnGameMenu
    return
  end
  if (IsGameOver()) then
    ShowGameOver(param)
    param.step = OnGameOverEnter
    return
  end
  UpdateHeroMenuCd()
  if (Input.IsKeyPushed(Input.LBUTTON)) then
    local l,t,mw,mh = Good.GetDim(map_id) -- map dim.
    local x, y = Input.GetMousePos()
    if (PtInRect(x, y, WND_W - 2 * TILE_W, 0, WND_W, TILE_H)) then
      if (1 == glass_speed) then
        glass_speed = 2
      else
        glass_speed = 1
      end
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
  if (Input.IsKeyPushed(Input.LBUTTON)) then
    sel_stage_id = curr_stage_id
    Good.GenObj(-1, stage_lvl_id)
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
  if (IsGameOver()) then
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
  -- Advance to next stage if curr stage is cleared.
  if (0 >= remain_hero_count) then
    InitStage(curr_stage_id + 1)
    UpdateCoinCountObj(true)
    local p = Good.GetParam(king_obj)
    p.lv = GetKingLv()
    p.max_hp = GetLevelValue(p.lv, HeroData[king_hero_id].Hp)
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
  -- Add sand glass obj.
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
  p.wave = stage.Wave[1]
end

function InitStage(stage_id)
  if (IsGameOver()) then
    return
  end
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
  if (stage_id > max_stage_id) then
    max_stage_id = stage_id
  end
  max_max_stage_id = math.max(max_max_stage_id, max_stage_id)
  stage_heroes_count = {}
  for i = 1, #stage.Heroes do
    local hero_config = stage.Heroes[i]
    local hero_id = hero_config[1]
    local hero_count = hero_config[2]
    if (init_game) then
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
    end
    stage_heroes_count[hero_id] = hero_count
  end
  init_game = false
  InitNextWave()
end

function IsGameOver()
  if (nil == king_obj) then
    return true
  end
  return not IsHeroAlive(king_obj)
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
  -- Select hero.
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
      UpdateCoinCountObj(true)
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
  local s = Good.GenTextObj(o, 'Chess Battle', TILE_H)
  local slen = GetTextObjWidth(s)
  Good.SetPos(s, (w - slen)/2, TILE_H/2)
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

function ShowGameOver(param)
  local o = GenColorObj(-1, WND_W, WND_H + 10, 0xff00137f, 'AnimGameOver')
  local s = Good.GenTextObj(o, 'Game Over', 64)
  local slen = GetTextObjWidth(s)
  Good.SetPos(s, (WND_W - slen)/2, 2/5 * WND_H)
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

function UpdateHeroMenuSel()
  for  i = 1, #HeroMenu do
    local menu = HeroMenu[i]
    if (coin_count < menu.put_cost or menu.count >= menu.max_count) then
      Good.SetAlpha(menu.o, 128)
      Good.SetBgColor(menu.cd_obj, HERO_MENU_DISABLE_COLOR)
    else
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
  local btn_obj = Good.GenObj(info_obj, button_id)
  local l,t,w,h = Good.GetDim(btn_obj)
  Good.SetPos(btn_obj, (HERO_MENU_W - w)/2, HERO_MENU_H - MENU_TEXT_OFFSET_Y - h)
  local upgrade_obj = Good.GenTextObj(btn_obj, string.format('$%d', menu.upgrade_cost), MENU_TEXT_SIZE)
  tw = GetTextObjWidth(upgrade_obj)
  Good.SetPos(upgrade_obj, (w - tw)/2, (h - MENU_TEXT_SIZE)/2)
  menu.btn_obj = btn_obj
  menu.info_obj = info_obj
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
  local btn_quit = Good.FindChild(menu_obj, 'quit game')
  Good.KillObj(Good.GetChild(btn_quit, 1))
  local l,t,w,h = Good.GetDim(btn_quit)
  local dummy = Good.GenDummy(btn_quit)
  Good.SetPos(dummy, 0, h)
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
