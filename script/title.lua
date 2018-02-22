local map_lvl_id = 39

Title = {}

Title.OnStep = function(param)
  if (Input.IsKeyPressed(Input.LBUTTON)) then
    Good.GenObj(-1, map_lvl_id)
  end
end
