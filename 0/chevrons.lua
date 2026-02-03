---@diagnostic disable: undefined-global
sg = peripheral.find("stargate")
sleep(1)
sg.spinRing()
sg.toggleIris()
for i=0,8 do
    sg.openChevron(i)
    sleep(0.5)
    sg.activateChevron(i)
    sleep(0.5)
    sg.deactivateChevron(i)
    sg.closeChevron(i)
    sleep(0.5)
end
sleep(1)
sg.stopRingSpin()
sg.toggleIris()
