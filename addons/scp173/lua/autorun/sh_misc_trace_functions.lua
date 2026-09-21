
AddCSLuaFile()

function util.TraceLineEx(data)
	local newData = {}
	
	for k, v in pairs(data) do
		newData[k] = v
	end
	
	local traceResults = {}
	local excludedEnts
	
	if istable(newData.filter) then
		excludedEnts = newData.filter
	elseif newData.filter then
		excludedEnts = {newData.filter}
	else
		excludedEnts = {}
	end
	
	local tracedEnts = {}
	
	local entsLeft = true
	
	while entsLeft do
		local currData = {}
		
		for k, v in pairs(newData) do
			if ((k != "output") and (k != "filter")) then
				currData[k] = v
			end
		end
		
		currData.filter = excludedEnts
		
		local result = util.TraceLine(currData)
		
		table.insert(traceResults, (#traceResults + 1), result)
		
		if result.Entity then
			if (not tracedEnts[result.Entity]) then
				if (result.Entity:IsValid() or result.Entity:IsWorld()) then
					if (not result.Entity:IsWorld()) then
						table.insert(excludedEnts, (#excludedEnts + 1), result.Entity)
					else
						newData.ignoreworld = true
					end
					
					tracedEnts[result.Entity] = true
				else
					entsLeft = false
				end
			else
				entsLeft = false
			end
		else
			entsLeft = false
		end
	end
	
	if newData.output then
		for k, v in pairs(traceResults) do
			newData.output[k] = v
		end
	end
	
	return traceResults
end

function util.TraceEntityEx(data, ent)
	local newData = {}
	
	for k, v in pairs(data) do
		newData[k] = v
	end
	
	local traceResults = {}
	local excludedEnts
	
	if istable(newData.filter) then
		excludedEnts = newData.filter
	elseif newData.filter then
		excludedEnts = {newData.filter}
	else
		excludedEnts = {}
	end
	
	local tracedEnts = {}
	
	local entsLeft = true
	
	while entsLeft do
		local currData = {}
		
		for k, v in pairs(newData) do
			if ((k != "output") and (k != "filter")) then
				currData[k] = v
			end
		end
		
		currData.filter = excludedEnts
		
		local result = util.TraceEntity(currData, ent)
		
		table.insert(traceResults, (#traceResults + 1), result)
		
		if result.Entity then
			if (not tracedEnts[result.Entity]) then
				if (result.Entity:IsValid() or result.Entity:IsWorld()) then
					if (not result.Entity:IsWorld()) then
						table.insert(excludedEnts, (#excludedEnts + 1), result.Entity)
					else
						newData.ignoreworld = true
					end
					
					tracedEnts[result.Entity] = true
				else
					entsLeft = false
				end
			else
				entsLeft = false
			end
		else
			entsLeft = false
		end
	end
	
	if newData.output then
		for k, v in pairs(traceResults) do
			newData.output[k] = v
		end
	end
	
	return traceResults
end

function util.TraceHullEx(data)
	local newData = {}
	
	for k, v in pairs(data) do
		newData[k] = v
	end
	
	local traceResults = {}
	local excludedEnts
	
	if istable(newData.filter) then
		excludedEnts = newData.filter
	elseif newData.filter then
		excludedEnts = {newData.filter}
	else
		excludedEnts = {}
	end
	
	local tracedEnts = {}
	
	local entsLeft = true
	
	while entsLeft do
		local currData = {}
		
		for k, v in pairs(newData) do
			if ((k != "output") and (k != "filter")) then
				currData[k] = v
			end
		end
		
		currData.filter = excludedEnts
		
		local result = util.TraceHull(currData)
		
		table.insert(traceResults, (#traceResults + 1), result)
		
		if result.Entity then
			if (not tracedEnts[result.Entity]) then
				if (result.Entity:IsValid() or result.Entity:IsWorld()) then
					if (not result.Entity:IsWorld()) then
						table.insert(excludedEnts, (#excludedEnts + 1), result.Entity)
					else
						newData.ignoreworld = true
					end
					
					tracedEnts[result.Entity] = true
				else
					entsLeft = false
				end
			else
				entsLeft = false
			end
		else
			entsLeft = false
		end
	end
	
	if newData.output then
		for k, v in pairs(traceResults) do
			newData.output[k] = v
		end
	end
	
	return traceResults
end
