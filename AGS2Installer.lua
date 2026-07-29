print("Downloading AGS2.0")
sleep(1)
shell.run("delete /startup.lua")
shell.run("delete /IDCEditor.lua")
shell.run("delete /AddressEditor.lua")
shell.run("delete /selftest.cfg")
shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/SGDialer.lua startup.lua")
shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/IDCEditor.lua IDCEditor.lua")
shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/AddressEditor.lua AddressEditor.lua")
shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/selftest.cfg selftest.cfg")
if not fs.exists("/GateEntries.ff") then
    shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/GateEntries.ff GateEntries.ff")
end
if not fs.exists("/IrisCodes.ff") then
    shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/IrisCodes.ff IrisCodes.ff")
end
if not fs.exists("/smartdial.cfg") then
    shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/smartdial.cfg smartdial.cfg")
end
if not fs.exists("/UIColoring.cfg") then
    shell.run("wget https://raw.githubusercontent.com/TheRedCreations/AGS2/refs/heads/main/0/UIColoring.cfg UIColoring.cfg")
end
shell.run("alias AGS /startup.lua")
print("Download complete")
sleep(5)
term.clear()
print("Rebooting")
shell.run("reboot")
