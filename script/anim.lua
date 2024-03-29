local HERO_MOVE_SPEED = 0.6             -- Cell/sec

--
-- Animator callback.
--

function AcApplyBuffEffect(param)
  if (IsHeroAlive(param.target_id)) then
    ApplyBuffEffect(param.lv, param.hero_id, param.target_id, param.skill_id, param.effect_id)
  end
  Good.KillObj(param._id)
end

function AcEndDamageBounce(param)
  param.k = nil
  Good.SetScript(param._id, '')
end

function AcEndGameOver(param)
  Good.SetScript(param._id, '')
  param.lvl_param.step = param.next_step
end

function AcGenSmokeObj(param)
  local o = Good.GenObj(-1, 1, 'AnimSmokeObj')
  Good.SetAnchor(o, .5, .5)
  Good.SetPos(o, Good.GetPos(param._id, 1))
  SetTopmost(o)
end

function AcKillAnimObj(param)
  Good.KillObj(param._id)
end

function AcAnimKillHero(param)
  local dummy = Good.GetParent(param._id)
  Good.KillObj(dummy)
  CheckGameOver()
end

function AcSetCityColor(param)
  param.k = nil
  Good.SetScript(param._id, '')
end

function AcSetNextWave(param)
  UpdateStage()
  Good.KillObj(param.time_obj)
  Good.KillObj(param._id)
end

function AcUpdateTimeLabel(param)
  param.wave = param.wave - 1
  if (nil ~= param.time_obj) then
    Good.KillObj(param.time_obj)
  end
  param.time_obj = Good.GenTextObj(-1, string.format('%d', param.wave), TILE_W/2)
  Good.SetPos(param.time_obj, WND_W - TILE_W/2 - 2, 0)
  param.ArRot.Duration = math.floor(1/glass_speed * 60)
  if (1 == glass_speed) then
    Good.SetBgColor(param._id, 0xffffffff)
  else
    Good.SetBgColor(param._id, 0xffff0000)
  end
end

function AcInvadeCity(param)
  if (param.is_win) then
    local target_city_id = param.target_city_id
    city_owner[target_city_id] = param.player_id
    local o = GetCityObjById(target_city_id)
    local new_clr = GetPlayerColor(city_owner[target_city_id])
    Good.GetParam(o).new_clr = new_clr
    Good.SetScript(o, 'AnimSetCityColor')
    local bg = Good.GetChild(o, 0)
    Good.GetParam(bg).new_clr = new_clr
    Good.SetScript(bg, 'AnimSetCityColor')
  end
  Good.KillObj(param._id)
  local lvl_param = Good.GetParam(Good.GetLevelId())
  if (OnMapMenu ~= lvl_param.step) then
    lvl_param.step = OnMapAiPlayingNextTurn
  else
    lvl_param.ai_step = OnMapAiPlayingNextTurn
  end
end

function AcUpgradeCity(param)
  Good.KillObj(param._id)
  local lvl_param = Good.GetParam(Good.GetLevelId())
  if (MyTurn()) then
    lvl_param.step = OnMapPlaying
  elseif (OnMapMenu ~= lvl_param.step) then
    lvl_param.step = OnMapAiPlaying
  end
end

--
-- Animator.
--

AnimFlyBuffEffect = {}

AnimFlyBuffEffect.OnStep = function(param)
  local o = param._id
  local target_id = param.target_id
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    if (IsHeroAlive(target_id)) then
      local x1, y1 = Good.GetPos(o)
      local x2, y2 = Good.GetPos(target_id)
      local dist = math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
      local dist_cell = dist / TILE_W
      local effect = EffectData[param.effect_id]
      local c = Good.GetChild(o, 0)
      local l,t,w,h = Good.GetDim(c)
      param.MoveToAr = ArAddMoveTo(loop1, 'Pos', dist_cell * effect.Speed / 60, x2 + (TILE_W - w)/2, y2 + (TILE_H - h)/2)
    end
    ArAddCall(loop1, 'AcApplyBuffEffect', 0)
    param.k = ArAddAnimator({loop1})
  else
    -- Adjust target pos of MoveTo ar.
    if (IsHeroAlive(target_id)) then
      local c = Good.GetChild(o, 0)
      local l,t,w,h = Good.GetDim(c)
      local x, y = Good.GetPos(target_id)
      param.MoveToAr.v1 = x + (TILE_W - w)/2
      param.MoveToAr.v2 = y + (TILE_H - h)/2
    end
    ArStepAnimator(param, param.k)
  end
end

AnimDamageHpObj = {}

AnimDamageHpObj.OnStep = function(param)
  if (nil == param.k) then
    local dx = math.random(TILE_W/3, 2*TILE_W/3)
    if (math.random(2) == 1) then
      dx = -1 * dx
    end
    local loop1 = ArAddLoop()
    ArAddMoveBy(loop1, 'Pos', 0.2, dx, -TILE_H/2).ease = ArEaseOut
    ArAddMoveBy(loop1, 'Pos', 0.35, 0, TILE_H).ease = ArEaseOutBounce
    ArAddCall(loop1, 'AcKillAnimObj', 0.3)
    local loop2 = ArAddLoop()
    ArAddDelay(loop2, 0.75)
    ArAddMoveTo(loop2, 'Scale', 0.1, 0, 0)
    param.k = ArAddAnimator({loop1, loop2})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimHealHpObj = {}

AnimHealHpObj.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveBy(loop1, 'Pos', 0.2, 0, -20).ease = ArEaseOut
    ArAddCall(loop1, 'AcKillAnimObj', 0.2)
    local loop2 = ArAddLoop()
    ArAddDelay(loop2, 0.3)
    ArAddMoveTo(loop2, 'Scale', 0.1, 0, 0)
    param.k = ArAddAnimator({loop1, loop2})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimSandGlass = {}

AnimSandGlass.OnStep = function(param)
  if (nil == param.k) then
    param.time_obj = Good.GenTextObj(-1, string.format('%d', param.wave), TILE_W/2)
    Good.SetPos(param.time_obj, WND_W - TILE_W/2 - 2, 0)
    local loop1 = ArAddLoop(nil, 1)
    local loop2 = ArAddLoop(loop1, param.wave)
    param.ArRot = ArAddMoveTo(loop2, 'Rot', 1/glass_speed, 360)
    param.ArRot.ease = ArEaseOut
    ArAddCall(loop2, 'AcUpdateTimeLabel', 0)
    ArAddCall(loop1, 'AcSetNextWave', 0)
    param.k = ArAddAnimator({loop1})
  elseif (not IsGameOver()) then
    ArStepAnimator(param, param.k)
  end
end

AnimKillHero = {}

AnimKillHero.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Alpha', 0.25, 0).ease = ArEaseOut
    ArAddCall(loop1, 'AcAnimKillHero', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimMoveHero = {}

AnimMoveHero.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Pos', HERO_MOVE_SPEED, GetXyFromPos(param.pos))
    ArAddCall(loop1, 'SetHeroIdle', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimHeroInitNextWave = {}

AnimHeroInitNextWave.OnStep = function(param)
  if (nil == param.k) then
    local x, y = GetXyFromPos(param.pos)
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Pos', math.random(40, 60) / 60, x, y - TILE_H).ease = ArEaseOutBounce
    ArAddCall(loop1, 'SetHeroWaitNextWave', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimHeroBeginNextWave = {}

AnimHeroBeginNextWave.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Pos', HERO_MOVE_SPEED * param.dist, GetXyFromPos(param.pos))
    ArAddCall(loop1, 'SetHeroBeginNextWave', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimDamageBounce = {}

AnimDamageBounce.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveBy(loop1, 'Pos', 0.1, 0, -TILE_H/4).ease = ArEaseOut
    ArAddMoveBy(loop1, 'Pos', 0.25, 0, TILE_H/4).ease = ArEaseOutBounce
    ArAddCall(loop1, 'AcEndDamageBounce', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimWarnPutHero = {}

AnimWarnPutHero.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Alpha', 0.4, 0)
    ArAddCall(loop1, 'AcKillAnimObj', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimGameOver = {}

AnimGameOver.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Pos', 1.2, 0, 0).ease = ArEaseOutBounce
    ArAddCall(loop1, 'AcEndGameOver', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimRotate = {}

AnimRotate.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveBy(loop1, 'Rot', 0.01, 10)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimSelCity = {}

AnimSelCity.OnStep = function(param)
  if (nil == param.k) then
    Good.SetAnchor(param._id, 0.5, 0.5)
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Scale', 0.1, 0.8, 0.8)
    ArAddMoveTo(loop1, 'Scale', 0.5, 1, 1).ease = ArEaseOutElastic
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimFlyingUpObj = {}

AnimFlyingUpObj.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveBy(loop1, 'Pos', 0.4, 0, -TILE_H).ease = ArEaseOut
    ArAddMoveTo(loop1, 'Alpha', .2, 0)
    ArAddCall(loop1, 'AcKillAnimObj', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimInvadeCity = {}

AnimInvadeCity.OnStep = function(param)
  if (nil == param.k) then
    local target_city = GetCityObjById(param.target_city_id)
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'Pos', 0.4, Good.GetPos(target_city)).ease = ArEaseInOut
    ArAddMoveTo(loop1, 'Alpha', 0.2, 0)
    ArAddCall(loop1, 'AcInvadeCity', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimUpgradeCity = {}

AnimUpgradeCity.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveBy(loop1, 'Pos', 0.4, 0, -TILE_H).ease = ArEaseOut
    ArAddMoveTo(loop1, 'Alpha', 0.2, 0)
    ArAddCall(loop1, 'AcUpgradeCity', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimInfoOrder = {}

AnimInfoOrder.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop(nil, 1)
    ArAddMoveTo(loop1, 'Pos', 0.4, param.new_x, param.new_y).ease = ArEaseOut
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimSetCityColor = {}

AnimSetCityColor.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop(nil, 1)
    ArAddMoveTo(loop1, 'BgColor', 0.15, param.new_clr).lerp = LerpARgb
    ArAddCall(loop1, 'AcSetCityColor', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimFireBall = {}

AnimFireBall.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddCall(loop1, 'AcGenSmokeObj', .05)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimSmokeObj = {}

AnimSmokeObj.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop()
    ArAddMoveTo(loop1, 'BgColor', .5, 0).lerp = LerpARgb
    ArAddCall(loop1, 'AcKillAnimObj', 0)
    local loop2 = ArAddLoop()
    ArAddMoveTo(loop2, 'Scale', .5, 0, 0)
    param.k = ArAddAnimator({loop1, loop2})
  else
    ArStepAnimator(param, param.k)
  end
end
