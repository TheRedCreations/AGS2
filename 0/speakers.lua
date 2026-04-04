speakers = {peripheral.find("speaker")}
    for i=1, #speakers do
		speakers[i].playSound("jsg:record.siren.sgc.dialing",1)
	end
return true
