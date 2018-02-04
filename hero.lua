local INIT_RANDOM_CD = 30               -- Ticks

-- 5 1 7
-- 3 * 4
-- 8 2 6
local NEXT_MOVE_OFFSET = {MAP_W, -MAP_W, -1, 1, -MAP_W-1, MAP_W+1, -MAP_W+1, MAP_W-1}
-- 7 1 5
-- 4 * 3
-- 6 2 8
local NEXT_MOVE_OFFSET_REVERT = {MAP_W, -MAP_W, 1, -1, MAP_W+1, -MAP_W-1, MAP_W-1, -MAP_W+1}

local ENEMY_HP_COLOR = 0xf0ff0000
local MY_HP_COLOR = 0xf000ff00

local MyHeroes = {}
local EnemyHeroes = {}

local map_id = 2
local chess_tex_id = 18

local COLOR_RED = 0
local COLOR_BLACK = 1

-- Hero impl.

Hero = {}

Hero.OnCreate = function(param)
  param.step = OnHeroIdle
end

Hero.OnStep = function(param)
  if (0 < param.paralysis_time) then
    param.paralysis_time = param.paralysis_time - 1
    if (0 >= param.paralysis_time) then
      Good.SetBgColor(param._id, 0xffffffff)
      Good.KillObj(Good.FindChild(param._id, 'paralysis'))
    end
  else
    param.step(param)
    UpdateHeroSkill(param)
  end
end

function OnHeroWaitNextWave(param)
  -- NOP.
end

function OnHeroIdle(param)
  UpdateHeroCd(param)
  if (nil ~= param.skill_id) then
    -- Find a target when skill is selected.
    param.target_id = FindSkillTarget(param)
    if (nil ~= param.target_id) then
      param.step = OnHeroMove           -- Try move toward to the target.
    else
      param.skill_id = nil              -- Can't find a target, retry next skill and target.
    end
  end
end

function OnHeroMove(param)
  local target_id = param.target_id
  if (not IsHeroAlive(target_id)) then
    -- Target is dead, retry next skill and target.
    param.skill_id = nil
    param.step = OnHeroIdle
    return
  end

  local id = param._id
  local skill = SkillData[param.skill_id]
  local dist = GetManhattanDist(id, target_id)
  if (dist <= skill.Dist) then
    -- Target is in the skill scope.
    param.step = OnHeroCastSkill
  else
    -- Target is not in the skill scope, try to move close it one time one cell.
    param.pos = GetNextMoveToTargetPos(id, target_id)
    Good.SetScript(id, 'AnimMoveHero')
  end
end

function OnHeroCastSkill(param)
  local skill = SkillData[param.skill_id]
  local buff = BuffData[skill.Buff]
  local effect = EffectData[buff.Effect]
  -- Create a buff instance.
  local skill_inst = {}
  skill_inst.cd = 0                     -- Force apply buff at next update.
  skill_inst.hits = buff.Hits
  skill_inst.target_id = param.target_id
  skill_inst.skill_id = param.skill_id
  param.skill_inst[param.skill_id] = skill_inst
  -- Wait for next skill.
  param.skill_id = nil
  param.step = OnHeroIdle
end

-- Func.

function CenterTextAnchor(s)
  local c = Good.GetChildCount(s)
  local half = math.floor(c / 2)
  for  i = 0, half do
    local o = Good.GetChild(s, i)
    Good.SetAnchor(o, 1, 0.5)
  end
  for  i = half, c do
    local o = Good.GetChild(s, i)
    Good.SetAnchor(o, 0, 0.5)
  end
end

function AddAnimHpObj(o, str, color, bgcolor, script)
  local x, y = Good.GetPos(o)
  local s = Good.GenTextObj(map_id, str, TILE_W/2, script)
  CenterTextAnchor(s)
  local w = GetTextObjWidth(s)
  Good.SetPos(s, x + (TILE_W - w)/2, y)
  if (nil ~= bgcolor) then
    SetTextObjColor(s, bgcolor)
    s = Good.GenTextObj(s, str, TILE_W/2)
    CenterTextAnchor(s)
    Good.SetPos(s, -1, -1)
  end
  SetTextObjColor(s, color)
end

function AddDamageObj(o, damage)
  local s = string.format('%d', damage)
  AddAnimHpObj(o, s, 0xffff0000, 0xff7f0000, 'AnimDamageHpObj')
end

function AddEnemyHeroObj(o)
  table.insert(EnemyHeroes, o)
end

function AddHealObj(o, heal)
  local s = string.format('+%d', heal)
  AddAnimHpObj(o, s, 0xff00ff00, 0xff007f00, 'AnimHealHpObj')
end

function AddMyHero(hero_id, pos, lv)
  if (0 ~= OccupyMap[pos]) then
    return -1
  end
  -- Gen hero obj.
  local o = GenHeroObj(hero_id, pos, MY_HP_COLOR, true, lv)
  if (-1 == o) then
    return -1
  end
  OccupyMap[pos] = o
  table.insert(MyHeroes, o)
  return o
end

function ApplyDamageBuffEffect(target, damage)
  local target_id = target._id
  target.hp = math.max(target.hp - damage, 0)
  AddDamageObj(target_id, damage)
  UpdateHeroHpObj(target)
  if (0 >= target.hp) then
    KillHero(target)
  else
    local dummy = Good.GetParent(target_id)
    local param = Good.GetParam(dummy)
    if (nil == param.k) then
      Good.SetScript(dummy, 'AnimDamageBounce')
    end
  end
end

function ApplyHealBuffEffect(target, amount)
  target.hp = math.min(target.hp + amount, target.max_hp)
  AddHealObj(target._id, amount)
  UpdateHeroHpObj(target)
end

function ApplyParalysisBuffEffect(target, effect)
  local target_id = target._id
  target.paralysis_time = target.paralysis_time + effect.Duration + 3 * math.min(40, target.lv)
  Good.SetBgColor(target_id, 0xffffd800)
  if (-1 == Good.FindChild(target_id, 'paralysis')) then
    local o = Good.GenObj(target_id, 25) -- Attach a paralysis effect obj to target.
    Good.SetAnchor(o, 0.5, 0.5)
    local l,t,w,h = Good.GetDim(o)
    Good.SetPos(o, (TILE_W - w)/2, (TILE_H - h)/2)
  end
end

function ApplyBuffEffect(lv, hero_id, target_id, skill_id, effect_id)
  local target = Good.GetParam(target_id)
  local hero = HeroData[hero_id]
  local skill = SkillData[skill_id]
  local effect = EffectData[effect_id]
  local damage = GetLevelValue(lv, hero.Atk + skill.Atk)
  if (EFFECT_DAMAGE == effect.Effect) then
    ApplyDamageBuffEffect(target, damage)
  elseif (EFFECT_HEAL == effect.Effect) then
    ApplyHealBuffEffect(target, damage)
  elseif (EFFECT_PARALYSIS == effect.Effect) then
    ApplyParalysisBuffEffect(target, effect)
  end
end

function GenEnemyHeroObj(hero_id, pos, lv)
  return GenHeroObj(hero_id, pos, ENEMY_HP_COLOR, false, lv)
end

function GenHeroObj(hero_id, pos, hp_color, red, lv)
  local hero = HeroData[hero_id]
  local dummy = Good.GenDummy(map_id)
  local o = GenHeroPieceObj(dummy, hero.Face, red, 'Hero')
  local x, y = GetXyFromPos(pos)
  Good.SetPos(o, x, y)
  SetTextObjColor(o, hero.Color)
  -- Init hero.
  local param = Good.GetParam(o)
  param.pos = pos
  param.hero_id = hero_id
  param.skill_inst = {}                 -- <skill_id, skill_inst>
  param.cd = {}                         -- <skill_id, cd>
  local rand_cd = math.random(INIT_RANDOM_CD)
  for i = 1, #hero.Skill do
    local skill_id = hero.Skill[i]
    local skill = SkillData[skill_id]
    if (red) then
      param.cd[skill_id] = skill.Cd
    else
      param.cd[skill_id] = rand_cd
    end
  end
  param.skill_id = nil                  -- Curr selected skill.(SkillData)
  param.max_hp = GetLevelValue(lv, hero.Hp)
  param.hp = param.max_hp
  param.hp_obj = nil
  param.hp_color = hp_color
  param.lv = lv
  param.paralysis_time = 0              -- if >0 then in paralysis status, can't do anything.
  UpdateHeroHpObj(param)
  return o
end

function GenHeroPieceObj(parent, name, red, script)
  if (red) then
    return GenTexObj(parent, chess_tex_id, TILE_W, TILE_H, name * TILE_W, COLOR_RED * TILE_H, script)
  else
    return GenTexObj(parent, chess_tex_id, TILE_W, TILE_H, name * TILE_W, COLOR_BLACK * TILE_H, script)
  end
end

function FindSkillTarget(param)
  if (nil == param.skill_id) then
    return
  end
  local skill = SkillData[param.skill_id]
  local o = param._id
  local target = nil
  local heroes = nil
  if (SKILL_TARGET_ENEMY == skill.Target) then
    heroes = GetEnemyHeroes(o)
  elseif (SKILL_TARGET_SELF == skill.Target) then
    heroes = GetMyHeroes(o)
  end
  if (SKILL_TARGET_TYPE_NEAR == skill.Type) then
    target = GetMinDistTarget(o, heroes)
  elseif (SKILL_TARGET_TYPE_FAR == skill.Type) then
    target = GetMaxDistTarget(o, heroes, skill.Dist)
  elseif (SKILL_TARGET_TYPE_RANDOM == skill.Type) then
    target = GetRandomTarget(o, heroes)
  elseif (SKILL_TARGET_TYPE_MIN_HP == skill.Type) then
    target = GetMinHpTarget(o, heroes)
  elseif (SKILL_TARGET_TYPE_SELF == skill.Type) then
    target = param._id
  end
  return target
end

function GetEnemyHeroes(o)
  for i = 1, #MyHeroes do
    if (MyHeroes[i] == o) then
      return EnemyHeroes
    end
  end
  return MyHeroes
end

function GetManhattanDist(o, target)
  local pos1 = Good.GetParam(o).pos
  local pos2 = Good.GetParam(target).pos
  return GetManhattanDistByPos(pos1, pos2)
end

function GetManhattanDistByPos(pos1, pos2)
  local c1, r1 = pos1 % MAP_W, math.floor(pos1 / MAP_W)
  local c2, r2 = pos2 % MAP_W, math.floor(pos2 / MAP_W)
  return math.abs(c1 - c2) + math.abs(r1 - r2)
end

function GetMaxDistTarget(o, heroes, Dist)
  -- Find max dist target in Dist first.
  local MaxDistTarget = nil
  local MaxDist = 0
  for i = 1, #heroes do
    local target = heroes[i]
    if (IsHeroAlive(target)) then
      local dist = GetManhattanDist(o, target)
      if (dist > MaxDist and dist <= Dist) then
        MaxDist = dist
        MaxDistTarget = target
      end
    end
  end
  return MaxDistTarget
end

function GetMinDistTarget(o, heroes)
  -- Find min dist target in heroes.
  local MinDistTarget = nil
  local MinDist = 1000
  for i = 1, #heroes do
    local target = heroes[i]
    if (IsHeroAlive(target)) then
      local dist = GetManhattanDist(o, target)
      if (dist < MinDist) then
        MinDist = dist
        MinDistTarget = target
      end
    end
  end
  return MinDistTarget
end

function GetMinHpTarget(o, heroes)
  -- Find min hp target in heroes.
  local MinHpTarget = nil
  local MinHp = 1000000
  for i = 1, #heroes do
    local target = heroes[i]
    if (IsHeroAlive(target)) then
      local param = Good.GetParam(target)
      if (param.hp < param.max_hp and param.hp < MinHp) then
        MinHp = param.hp
        MinHpTarget = target
      end
    end
  end
  return MinHpTarget
end

function GetMyHeroes(o)
  for i = 1, #MyHeroes do
    if (MyHeroes[i] == o) then
      return MyHeroes
    end
  end
  return EnemyHeroes
end

function GetNextMoveToTargetPos(o, target)
  local pos1 = Good.GetParam(o).pos
  local c1, r1 = pos1 % MAP_W, math.floor(pos1 / MAP_W)
  local pos2 = Good.GetParam(target).pos
  local c2, r2 = pos2 % MAP_W, math.floor(pos2 / MAP_W)
  local MinDist = 1000
  local dir
  local MOVE_OFFSET
  if (1 == math.random(1,2)) then
    MOVE_OFFSET = NEXT_MOVE_OFFSET
  else
    MOVE_OFFSET = NEXT_MOVE_OFFSET_REVERT
  end
  for i = 1, #MOVE_OFFSET do
    local NewPos = pos1 + MOVE_OFFSET[i]
    if (0 == OccupyMap[NewPos] and 0 <= NewPos and MAP_W * MAP_H > NewPos) then
      local c, r = NewPos % MAP_W, math.floor(NewPos / MAP_W)
      local distToPos = math.abs(c - c1) + math.abs(r - r1)
      if (2 >= distToPos) then
        local distToTarget = math.abs(c - c2) + math.abs(r - r2)
        if (distToTarget < MinDist) then
          MinDist = distToTarget
          dir = i
        end
      end
    end
  end
  if (1000 > MinDist) then
    local NewPos = pos1 + MOVE_OFFSET[dir]
    OccupyMap[pos1] = 0
    OccupyMap[NewPos] = o
    return NewPos
  else
    return pos1
  end
end

function GetRandomTarget(o, heroes)
  if 0 == #heroes then
    return nil
  else
    return heroes[math.random(#heroes)]
  end
end

function InitHero()
  MyHeroes = {}
  EnemyHeroes = {}
end

function InitNextWaveHero(o)
  local x, y = Good.GetPos(o)
  Good.SetPos(o, x, y - 4 * TILE_H)
  Good.SetScript(o, 'AnimHeroInitNextWave')
end

function IsHeroAlive(o)
  for i = 1, #MyHeroes do
    if (o == MyHeroes[i]) then
      return true
    end
  end
  for i = 1, #EnemyHeroes do
    if (o == EnemyHeroes[i]) then
      return true
    end
  end
  return false
end

function KillHero(param)
  if (ENEMY_HP_COLOR == param.hp_color) then
    AddCoinObj(param._id)
    CurrKillEnemy[param.hero_id] = CurrKillEnemy[param.hero_id] + 1
    TotalKillEnemy[param.hero_id] = TotalKillEnemy[param.hero_id] + 1
  else
    KillSelHero(param.hero_id)
  end
  OccupyMap[param.pos] = 0
  local id = param._id
  RemoveTableItem(MyHeroes, id)
  RemoveTableItem(EnemyHeroes, id)
  Good.SetScript(id, 'AnimKillHero')
  param.k = nil
  local dummy = Good.GetParent(id)
  Good.SetScript(dummy, '')
end

function SetHeroIdle(param)
  Good.SetScript(param._id, 'Hero')
  param.step = OnHeroIdle
  param.k = nil
end

function SetNextWaveHero(o, next_wave_pos)
  local param = Good.GetParam(o)
  param.pos = param.pos + next_wave_pos
  local orig_pos = param.pos
  if (0 ~= OccupyMap[orig_pos]) then
    -- Try to find a nearest empty start pos if curr start pos is occupied.
    local MinPos = orig_pos
    local MinDist = 1000
    local pos = math.floor(orig_pos/9) * 9
    for i = 0, MAP_W * MAP_H - 1 do
      if (0 == OccupyMap[pos]) then
        local dist = GetManhattanDistByPos(orig_pos, pos)
        if (dist < MinDist) then
          MinDist = dist
          MinPos = pos
        end
      end
      pos = (pos + 1) % (MAP_W * MAP_H)
    end
    param.pos = MinPos
  end
  OccupyMap[param.pos] = param._id
  param.dist = math.max(1, GetManhattanDistByPos(param.pos, orig_pos))
  Good.SetScript(param._id, 'AnimHeroBeginNextWave')
end

function SetHeroBeginNextWave(param)
  AddEnemyHeroObj(param._id)
  Good.SetScript(param._id, 'Hero')
  param.step = OnHeroIdle
  param.k = nil
end

function SetHeroWaitNextWave(param)
  Good.SetScript(param._id, 'Hero')
  param.step = OnHeroWaitNextWave
  param.k = nil
end

function RemoveTableItem(t, id)
  for i = 1, #t do
    if (t[i] == id) then
      table.remove(t, i)
      break
    end
  end
end

function ApplyFlyBuffEffect(param, skill_inst, effect_id, effect)
  local o = Good.GenDummy(map_id, 'AnimFlyBuffEffect')
  local c = Good.GenObj(o, effect.FlyObj)
  Good.SetPos(c, 0, 0)
  local l,t,w,h = Good.GetDim(c)
  local x, y = GetXyFromPos(param.pos)
  Good.SetPos(o, x + (TILE_W - w)/2, y + (TILE_H - h)/2)
  local p = Good.GetParam(o)
  p.lv = param.lv
  p.hero_id = param.hero_id
  p.target_id = skill_inst.target_id
  p.skill_id = skill_inst.skill_id
  p.effect_id = effect_id
  p.pos = param.pos
end

function UpdateHeroSkill(param)
  local NewSkillInst = {}
  for skill_id, skill_inst in pairs(param.skill_inst) do
    if (IsHeroAlive(skill_inst.target_id)) then
      local skill = SkillData[skill_inst.skill_id]
      local buff = BuffData[skill.Buff]
      local effect_id = buff.Effect
      skill_inst.cd = skill_inst.cd - 1
      if (0 >= skill_inst.cd) then
        local effect = EffectData[effect_id]
        if (EFFECT_TYPE_STRIKE == effect.Type) then
          ApplyBuffEffect(param.lv, param.hero_id, skill_inst.target_id, skill_inst.skill_id, effect_id)
        elseif (EFFECT_TYPE_FLY == effect.Type) then
          ApplyFlyBuffEffect(param, skill_inst, effect_id, effect)
        end
        skill_inst.cd = math.floor(buff.Time / buff.Hits)
        skill_inst.hits = skill_inst.hits - 1
      end
      if (0 <= skill_inst.hits) then
        NewSkillInst[skill_inst.skill_id] = skill_inst
      end
    end
  end
  param.skill_inst = NewSkillInst
end

function UpdateHeroCd(param)
  -- If already select a skill then skip update cd.
  if (nil ~= param.skill_id) then
    return
  end
  -- Update cd and select the skill which cd is 0.
  for skill_id, cd in pairs(param.cd) do
    if (0 < cd) then
      cd = cd - 1
      param.cd[skill_id] = cd
    end
    -- Set currect select skill.
    if (0 >= cd and nil == param.skill_id) then
      local skill = SkillData[skill_id]
      param.skill_id = skill_id
      param.cd[skill_id] = skill.Cd     -- Reset CD.
    end
  end
end

function UpdateHeroHpObj(param)
  if (nil == param.hp_obj) then
    param.hp_obj = GenColorObj(param._id, (param.hp / param.max_hp) * (TILE_W - 4), 3, param.hp_color, '')
    Good.SetPos(param.hp_obj, 2, TILE_H - 2)
  else
    Good.SetDim(param.hp_obj, 0, 0, (param.hp / param.max_hp) * (TILE_W - 4), 3)
  end
end

function UpgradeHeroOnField(hero_id)
  local hero = HeroData[hero_id]
  for i = 1, #MyHeroes do
    local o = MyHeroes[i]
    if (IsHeroAlive(o)) then
      local param = Good.GetParam(o)
      if (hero_id == param.hero_id) then
        param.lv = param.lv + 1
        param.max_hp = GetLevelValue(param.lv, hero.Hp)
        param.hp = param.max_hp
        AddAnimHpObj(o, 'LvUp', 0xff00ff00, 0xff007f00, 'AnimHealHpObj')
        UpdateHeroHpObj(param)
      end
    end
  end
end
