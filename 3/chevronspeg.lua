---@diagnostic disable: undefined-global
stargate = peripheral.find("stargate")
stargate.spinRing()
  stargate.toggleIris()
  for i=0,8 do
    stargate.openChevron(i)
    sleep(0.5)
    stargate.activateChevron(i)
    sleep(0.5)
    stargate.deactivateChevron(i)
    stargate.closeChevron(i)
    sleep(0.5)
  end
  sleep(1)
  stargate.stopRingSpin()
  stargate.toggleIris()