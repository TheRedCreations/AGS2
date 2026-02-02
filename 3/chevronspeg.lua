---@diagnostic disable: undefined-global
sg = peripheral.find("stargate")
sleep(5)
sg.spinRing()
sg.toggleIris()
for i=0,8 do
    sg.openChevron(i)
    sleep(0.5)
end
for i=0,8 do
    sg.activateChevron(i)
    sleep(0.5)
end
for i=0,8 do
    sg.closeChevron(i)
    sleep(0.5)
end

for i=0,8 do
    sg.openChevron(i)
    sleep(0.5)
end
for i=0,8 do
    sg.deactivateChevron(i)
    sleep(0.5)
end
for i=0,8 do
    sg.closeChevron(i)
    sleep(0.5)
end
sg.stopRingSpin()
sg.toggleIris()