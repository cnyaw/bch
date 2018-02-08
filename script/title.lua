Title = {}

local stage_lvl_id = 14

Title.OnStep = function(param)
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    Good.GenObj(-1, stage_lvl_id)
  end
end
