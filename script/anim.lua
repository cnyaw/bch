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

function AcKillAnimObj(param)
  Good.KillObj(param._id)
end

function AcAnimKillHero(param)
  local dummy = Good.GetParent(param._id)
  Good.KillObj(dummy)
  CheckGameOver()
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
    UpdateCityInfo(GetObjByCityId(target_city_id))
  end
  Good.KillObj(param._id)
end

--
-- Animator.
--

AnimFlyBuffEffect = {}

AnimFlyBuffEffect.OnStep = function(param)
  local o = param._id
  local target_id = param.target_id
  if (nil == param.k) then
    local loop1 = ArAddLoop(nil)
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
    local loop1 = ArAddLoop(nil)
    ArAddMoveBy(loop1, 'Pos', 0.2, dx, -TILE_H/2).ease = ArEaseOut
    ArAddMoveBy(loop1, 'Pos', 0.35, 0, TILE_H).ease = ArEaseOutBounce
    ArAddCall(loop1, 'AcKillAnimObj', 0.3)
    local loop2 = ArAddLoop(nil)
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
    local loop1 = ArAddLoop(nil)
    ArAddMoveBy(loop1, 'Pos', 0.2, 0, -20).ease = ArEaseOut
    ArAddCall(loop1, 'AcKillAnimObj', 0.2)
    local loop2 = ArAddLoop(nil)
    ArAddDelay(loop2, 0.3)
    ArAddMoveTo(loop2, 'Scale', 0.1, 0, 0)
    param.k = ArAddAnimator({loop1, loop2})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimSelMenuItem = {}

AnimSelMenuItem.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop(nil, 1)
    ArAddMoveTo(loop1, 'Scale', 0.2, 1, 1).ease = ArEaseOut
    param.k = ArAddAnimator({loop1})
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
    local loop1 = ArAddLoop(nil)
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
    local x, y = GetXyFromPos(param.pos)
    local loop1 = ArAddLoop(nil)
    ArAddMoveTo(loop1, 'Pos', HERO_MOVE_SPEED, x, y)
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
    local loop1 = ArAddLoop(nil)
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
    local x, y = GetXyFromPos(param.pos)
    local loop1 = ArAddLoop(nil)
    ArAddMoveTo(loop1, 'Pos', HERO_MOVE_SPEED * param.dist, x, y)
    ArAddCall(loop1, 'SetHeroBeginNextWave', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimDamageBounce = {}

AnimDamageBounce.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop(nil)
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
    local loop1 = ArAddLoop(nil)
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
    local loop1 = ArAddLoop(nil)
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
    local loop1 = ArAddLoop(nil)
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
    local loop1 = ArAddLoop(nil)
    ArAddMoveTo(loop1, 'Scale', 0.5, 1, 1).ease = ArEaseOutElastic
    ArAddMoveTo(loop1, 'Scale', 0.1, 0.8, 0.8)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end

AnimFlyingUpObj = {}

AnimFlyingUpObj.OnStep = function(param)
  if (nil == param.k) then
    local loop1 = ArAddLoop(nil)
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
    local target_city = GetObjByCityId(param.target_city_id)
    local tx, ty = Good.GetPos(target_city)
    local loop1 = ArAddLoop(nil)
    ArAddMoveTo(loop1, 'Pos', 0.3, tx, ty).ease = ArEaseInOut
    ArAddCall(loop1, 'AcInvadeCity', 0)
    param.k = ArAddAnimator({loop1})
  else
    ArStepAnimator(param, param.k)
  end
end
