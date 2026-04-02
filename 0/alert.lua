while true do
  if redstone.getInput("top") == true or redstone.getInput("bottom") == true or redstone.getInput("left") == true or redstone.getInput("right") == true or redstone.getInput("front") == true or redstone.getInput("back") == true then
shell.run("test.lua")
  sleep(2)
  end
  sleep(0.1)
end