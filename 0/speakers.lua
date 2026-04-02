speakers = {peripheral.find("speaker")}
    for i=1, #speakers do
		speakers[i].playSound("jsg:record.siren.sgc.dialing")
	end
return true