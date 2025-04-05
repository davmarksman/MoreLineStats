local timetableHelper = require "timetableHelper"

local lineStatsHelper = {}


-------------------------------------------------------------
---------------------- Vehicle related ----------------------
-------------------------------------------------------------

-- returns table where index is vehicle id, and value is time since last depature
function lineStatsHelper.findLostTrains()
    local gameTime = lineStatsHelper.getTime()
    local vehicles = lineStatsHelper.getAllVehiclesEnRoute()
    local res = {}

    for i, vehicleId in pairs(vehicles) do
        local vehicle = lineStatsHelper.getVehicle(vehicleId)
        if vehicle and vehicle.carrier and vehicle.line then
            if vehicle.carrier == api.type.enum.JournalEntryCarrier.RAIL then
                local lastDeparture = lineStatsHelper.getLastDepartureTimeFromVeh(vehicle)
                local timeSinceDep = gameTime - lastDeparture

                if lastDeparture > 0 and timeSinceDep >  180 then
                    local lineLegTimes = lineStatsHelper.getLegTimes(vehicle.line)
                    if lineLegTimes and lineLegTimes[1] then
                        -- Use leg times to work out if vehicle is lost
                        local maxLegTime = timetableHelper.maximumArray(lineLegTimes)
                        local avgLegTime = lineStatsHelper.avgNonZeroValuesInArray(lineLegTimes)

                        if maxLegTime > 0 and timeSinceDep > 2 * maxLegTime then
                            res[vehicleId] = timeSinceDep
                        -- Sometimes max leg time is high as train was lost and it's updated legTime to be 
                        -- how long it took lost train to find station
                        -- Estimate as lost using average leg time
                        elseif maxLegTime > 8 * 60 and timeSinceDep > 3 * avgLegTime then
                            res[vehicleId] = timeSinceDep
                        end
                    else
                        -- Estimate as lost if > 10 minutes since last station
                        if timeSinceDep > 10 * 60 then
                            res[vehicleId] = timeSinceDep
                        end
                    end
                end
            end
        end 
    end

    return res
end

---@param vehicleID number | string
-- returns https://transportfever2.com/wiki/api/modules/api.type.html#TransportVehicle
function lineStatsHelper.getVehicle(vehicleID) 
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return false end

    local lineVehicle = api.engine.getComponent(vehicleID, api.type.ComponentType.TRANSPORT_VEHICLE)
    if lineVehicle and lineVehicle.carrier then
        return lineVehicle
    else
        return {}
    end
end

---@param vehicleID number | string
-- returns departure time of previous vehicle. 0 if no depature times
function lineStatsHelper.getLastDepartureTime(vehicleID)
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return false end

    local lineVehicle = api.engine.getComponent(vehicleID, api.type.ComponentType.TRANSPORT_VEHICLE) 
    return lineStatsHelper.getLastDepartureTimeFromVeh(lineVehicle)
end

---@param lineVehicle any -- https://transportfever2.com/wiki/api/modules/api.type.html#TransportVehicle 
-- returns departure time of previous vehicle. 0 if no depature times
function lineStatsHelper.getLastDepartureTimeFromVeh(lineVehicle)
    local lastDepartureTime = 0
    if lineVehicle and lineVehicle.lineStopDepartures then
        lastDepartureTime = timetableHelper.maximumArray(lineVehicle.lineStopDepartures)
    end
    
    return lineStatsHelper.getTimeInSecs(lastDepartureTime)
end

-- returns arr:[vehicleID:number]
function lineStatsHelper.getAllVehiclesEnRoute()
    return api.engine.system.transportVehicleSystem.getVehiclesWithState(api.type.enum.TransportVehicleState.EN_ROUTE)
end

---@param vehicleID number | string
-- returns bool
function lineStatsHelper.isTrain(vehicleID) 
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return false end

    local lineVehicle = api.engine.getComponent(vehicleID, api.type.ComponentType.TRANSPORT_VEHICLE)
    if lineVehicle and lineVehicle.carrier then
        return lineVehicle.carrier == api.type.enum.JournalEntryCarrier.RAIL
    end

    return false
end


---@param vehicleID number | string
-- returns vehicle name
function lineStatsHelper.getVehicleName(vehicleID) 
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return false end

    local err, res = pcall(function()
        return api.engine.getComponent(vehicleID, api.type.ComponentType.NAME)
    end)
    if err and res then return res.name else return "ERROR" end
end

---@param vehicleID number | string
-- returns returns line name of vehicel
function lineStatsHelper.getLineNameOfVehicle(vehicleID) 
    local vehicle = lineStatsHelper.getVehicle(vehicleID)
    if vehicle and vehicle.line then
        return timetableHelper.getLineName(vehicle.line)     
    else
        return "Unknown"
    end
end


---@param lineId number | string
-- returns vehicles for line
function lineStatsHelper.getVehicles(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
    return vehiclesForLine
end




-------------------------------------------------------------
---------------------- Line related -------------------------
-------------------------------------------------------------

---@param lineId number | string
-- returns leg Times for line
function lineStatsHelper.getLegTimes(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
    local noOfVeh = #vehiclesForLine
    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    local noOfStops = #lineComp.stops

    -- Create a matrix[leg][vehicleLegTime]. 
    -- Legs are the first index. We then store the value for the vehicle legtimes for that leg in the second index
    local legTimes = lineStatsHelper.createOneBasedArrayOfArrays(noOfStops, noOfVeh, 0)
    
    for vehIdx, vehicleId in pairs(vehiclesForLine) do
        local sectionTimes = lineStatsHelper.getSectionTimesFromVeh(vehicleId)
        if sectionTimes then
            
            -- Noticed a bug where when do `for .. pairs(sectionTimes)`, that there are sometimes additional entries and an infinite loop
            -- aka a memory leak. Can't see what's causing it as it happens on a lineIds that worked fine seconds ago
            -- We'll play defensive do a for loop on noOfStops
            for legIdx = 1, noOfStops do
                local legTime = sectionTimes[legIdx]
                if legTime and legTime > 0 then
                    legTimes[legIdx][vehIdx] = legTime
                end
            end
        end
    end

    local toReturn = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    for i=1, #legTimes do
        toReturn[i] = lineStatsHelper.avgNonZeroValuesInArray(legTimes[i])
    end

    return toReturn
end

function lineStatsHelper.getSectionTimesFromVeh(vehicleId)
    local vehicleObject = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
    if vehicleObject and vehicleObject.sectionTimes then
        return vehicleObject.sectionTimes
    else
        return nil
    end
end


---@param line number | string
-- returns lineFrequency : String, formatted '%M:%S'
function lineStatsHelper.getFrequencyNum(line)
    if type(line) == "string" then line = tonumber(line) end
    if not(type(line) == "number") then return "ERROR" end

    local lineEntity = game.interface.getEntity(line)
    if lineEntity and lineEntity.frequency then
        if lineEntity.frequency == 0 then return 0 end
        return 1 / lineEntity.frequency
    else
        return 0
    end
end

-------------------------------------------------------------
---------------------- Station related ----------------------
-------------------------------------------------------------


---@param stationId number | string
-- returns {id:number , name : String}
function timetableHelper.getStationNameWithId(stationId)
    if type(stationId) == "string" then stationId = tonumber(stationId) end
    if not(type(stationId) == "number") then return "ERROR" end

    local stationObject = api.engine.getComponent(stationId, api.type.ComponentType.NAME)
    if stationObject and stationObject.name then
        return { id = stationId, name = stationObject.name }
    else
        return { id = stationId, name = "ERROR"}
    end
end


function lineStatsHelper.getLineTimesBetweenStation(startStationId, endStationId)
    if not startStationId or not endStationId then
        return {}
    end

    local startStationLines = api.engine.system.lineSystem. getLineStops(startStationId)
    local endStationLines = api.engine.system.lineSystem. getLineStops(endStationId)


    local linesBetweenStation = lineStatsHelper.intersect(startStationLines, endStationLines)

    local res = {}
    for _, lineId in pairs(linesBetweenStation) do   
        local time = lineStatsHelper.getTimeBetweenStations(lineId, startStationId, endStationId)
        res[lineId] = time
    end

    return res
end

-- Doesn't do error checking so parameters need to be correct
function lineStatsHelper.getTimeBetweenStations(lineId, startStationId, endStationId)
    local stationLegTime = lineStatsHelper.getLegTimes(lineId)
    local toReturnTime = 0

    if not stationLegTime then
        return toReturnTime
    end

    local startStopNos = {}
    local endStopNos = {}

    local stationsArr = timetableHelper.getAllStations(lineId)
    -- find the stop Number(s) of the start and end stations. 
    -- May be > 1 as station may be stopped at multiple times
    for idx, lineStationId in pairs(stationsArr) do  
        if lineStationId == startStationId then
            table.insert(startStopNos, idx)
        elseif lineStationId == endStationId then
            table.insert(endStopNos, idx)
        end
    end

    for _, sidx in pairs(startStopNos) do
        for _, eidx in pairs(endStopNos) do
            local i = sidx
            local totalTime = 0
            while i ~= eidx do
                if (stationLegTime[i]) then
                    local legTime = stationLegTime[i]
                    if type(legTime) == "string" then legTime = tonumber(legTime) end
                    if not(type(legTime) == "number") then
                        print("Expected String or Number")
                        return 0
                    end

                    totalTime = totalTime + legTime
                else
                    return 0
                end

                if i == #stationsArr then
                    i = 1
                else
                    i = i + 1
                end
            end

            if toReturnTime == 0 or totalTime < toReturnTime then
                toReturnTime = totalTime
            end
        end
    end

    return toReturnTime
end


-------------------------------------------------------------
---------------------- Passengers Functions -------------
-------------------------------------------------------------
---@param lineId number | string
-- returns object
-- Fields
-- totalCount= Number
-- waitingCount = Number
-- inVehCount = Number
-- peopleAtStop = [Number], arr: number of people waiting at each stop
-- peopleAtStopLongWait = [Number], arr: number of people waiting for a long time at each stop
-- stopAvgWaitTimes = [Number], arr: average wait time at each stop
function lineStatsHelper.getPassengerStatsForLine(lineId)
    if type(lineId) == "string" then line = tonumber(lineId) end
    if not(type(lineId) == "number") then return "ERROR" end 

    local gameTime = lineStatsHelper.getTime()
    local personsForLineArr = api.engine.system.simPersonSystem.getSimPersonsForLine(lineId)

    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    local noOfStops = #lineComp.stops
    local lineFreq = lineStatsHelper.getFrequencyNum(lineId)

    local res = {}
    res.totalCount = 0
    res.waitingCount = 0
    res.inVehCount = 0
    res.peopleAtStop = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    res.peopleAtStopLongWait = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    local stopWaitTimes = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    res.stopAvgWaitTimes = lineStatsHelper.createOneBasedArray(noOfStops, 0)

    for _, personId in pairs(personsForLineArr) do 
        local simEntityAtTerminal = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_TERMINAL)
        local simEntityAtVeh= api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_VEHICLE)

        -- Waiting at terminal
        if simEntityAtTerminal then 
            if simEntityAtTerminal.line == lineId then
                res.totalCount = res.totalCount + 1
                res.waitingCount  = res.waitingCount + 1
                local stopNo = simEntityAtTerminal.lineStop0 + 1
                res.peopleAtStop[stopNo] = res.peopleAtStop[stopNo] + 1
                local waitTime = gameTime - lineStatsHelper.getTimeInSecs(simEntityAtTerminal.arrivalTime)
                stopWaitTimes[stopNo] = stopWaitTimes[stopNo] + waitTime
                if lineFreq > 60  and waitTime > lineFreq * 1.5 then
                    res.peopleAtStopLongWait[stopNo] =  res.peopleAtStopLongWait[stopNo] + 1
                end
            end
        end 
        -- On Vehicle
        if simEntityAtVeh then     
            if simEntityAtVeh.line == lineId then    
                res.totalCount = res.totalCount + 1   
                res.inVehCount = res.inVehCount + 1
            end
        end
    end

    for stopNo, count in pairs(res.peopleAtStop) do
        res.stopAvgWaitTimes[stopNo] = lineStatsHelper.safeDivide(stopWaitTimes[stopNo], count)
    end

    return res
end

-------------------------------------------------------------
---------------------- Issues Locating Functions ------------
-------------------------------------------------------------

-- Stop with more people than train capacity (divide line capacity/no of vehicles)


-- 2x more people waiting than loaded



-------------------------------------------------------------
---------------------- Util Functions ----------------------
-------------------------------------------------------------



---@param a table
---@param b table
-- returns Array, the intersect of a and b
function lineStatsHelper.intersect(a,b)
    local intersectVals = {}

    if a == nil then return {} end
    if b == nil then return {} end

    for _, av in pairs(a) do 
        for _, bv in pairs(b) do 
            if av == bv then
                table.insert(intersectVals, av)
            end
        end
	end

    return lineStatsHelper.distinctArr(intersectVals)
end

---@param arr table
-- Removes Duplicate elements https://stackoverflow.com/questions/20066835/lua-remove-duplicate-elements
function  lineStatsHelper.distinctArr(arr)
    
    if arr == nil then return {} end

    local hash = {}
    local res = {}

    for _,v in ipairs(arr) do
        if (not hash[v]) then
            res[#res+1] = v
            hash[v] = true
        end
    end

    return res
end

---@param tab table
-- returns the sorted keys of the table
-- https://www.lua.org/pil/19.3.html
function lineStatsHelper.getKeysAsSortedTable(tab)
	local keys = {} 
	for k, v in pairs(tab) do 
		table.insert(keys,k)
	end
	table.sort(keys)
	return keys
end

---@param tab table
-- returns the table sorted by values
-- https://www.lua.org/pil/19.3.html
function lineStatsHelper.sortByValues(tab)
    local entities = {}
 
    for key, value in pairs(tab) do
        table.insert(entities, {key = key, value = value})
    end
     
    table.sort(entities, function(a, b) return a.value < b.value end)

    return entities
end


---@param count number
---@param defaultVal number | string | any
-- returns a index one based array with all values set to defaultVal
function lineStatsHelper.createOneBasedArray(count, defaultVal)
    local arr={}
    for i=1,count do
        arr[i]=defaultVal
    end
    return arr
end

---@param n number
---@param m number
---@param defaultVal number | string | any
-- returns a Matrices/Multi-Dimensional Array. See https://www.lua.org/pil/11.2.html
function lineStatsHelper.createOneBasedArrayOfArrays(n,m, defaultVal)
    local matrix={}
    for i=1,n do
        matrix[i]={}
        for j=1,m do
            matrix[i][j] = defaultVal
        end
    end
    return matrix
end

-- returns Number, current GameTime in seconds
function lineStatsHelper.getTime()
    local gameTimeComp = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
    local time = gameTimeComp.gameTime
    return lineStatsHelper.getTimeInSecs(time)
end

---@param time number
-- returns Number, time in seconds
function lineStatsHelper.getTimeInSecs(time)
    if time then
        time = math.floor(time/ 1000)
        return time
    else
        return 0
    end
end


---@param time number
-- returns Formated time string
function lineStatsHelper.getTimeStr(time)
    if not(type(time) == "number") then return "ERROR" end 

    local timeStr = os.date('%M:%S', time)
    if(time == 0) then
        timeStr = "--:--"
    end
    return timeStr
end


---@param num number
---@param denom number
---Returns 0 if denominator is 0, the num/denom otherwise
function lineStatsHelper.safeDivide(num, denom)
    if denom == 0 then
        return 0
    else
        return num / denom
    end
end

---@param arr table
-- returns the avearge of non zero values
function lineStatsHelper.avgNonZeroValuesInArray(arr)
    local total = 0
    local count = 0
    for k,_ in pairs(arr) do
        if (arr[k] > 0) then
            total = total + arr[k]
            count = count + 1
        end
    end
    return lineStatsHelper.safeDivide(total, count)
end



return lineStatsHelper

