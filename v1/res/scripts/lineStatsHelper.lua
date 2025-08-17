local timetableHelper = require "timetableHelper"
local lineStatsUtils = require "lineStatsUtils"

local lineStatsHelper = {}


-------------------------------------------------------------
---------------------- Vehicle related ----------------------
-------------------------------------------------------------

-- returns table where index is vehicle id, and value is time since last depature
-- Also compare last 2 financial periods. If hasn't earned any money probably problem
function lineStatsHelper.findLostTrains()
    local gameTime = lineStatsUtils.getTime()
    local vehicles = lineStatsHelper.getAllVehiclesEnRoute()
    local res = {}

    local trains = lineStatsHelper.getTrains(vehicles)

    for vehicleId, vehicle in pairs(trains) do
        local lastDeparture = lineStatsHelper.getLastDepartureTimeFromVeh(vehicle)
        local timeSinceDep = gameTime - lastDeparture

        if lastDeparture > 0 and timeSinceDep >  60 * 4 then
            local lineLegTimes = lineStatsHelper.getLegTimes(vehicle.line)
            if lineLegTimes and lineLegTimes[1] then
                -- Use leg times to work out if vehicle is lost
                local maxLegTime = timetableHelper.maximumArray(lineLegTimes)
                local avgLegTime = lineStatsUtils.avgNonZeroValuesInArray(lineLegTimes)
                if maxLegTime < 120 then
                    maxLegTime = 240
                end
                if avgLegTime < 120 then
                    avgLegTime = 120
                end

                if timeSinceDep > 1.5 * maxLegTime then
                    res[vehicleId] = timeSinceDep
                -- Sometimes max leg time is high as train was lost and it's updated legTime to be 
                -- how long it took lost train to find station
                -- Estimate as lost using average leg time
                elseif avgLegTime > 0 and timeSinceDep > 3 * avgLegTime then
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

    return res
end

--- @param vehicleIds [string] | [number]
--- @return table
--- returns table with key vehicle Id, and value vehicles (api.type.ComponentType.TRANSPORT_VEHICLE, not vehicle Id)
function lineStatsHelper.getTrains(vehicleIds)
    local matrix={}
    for i, vehicleId in pairs(vehicleIds) do
        local vehicle = lineStatsHelper.getVehicle(vehicleId)
        if vehicle and vehicle.carrier and vehicle.line then
            if vehicle.carrier == api.type.enum.JournalEntryCarrier.RAIL then
                matrix[vehicleId] = vehicle
            end
        end
    end
    return matrix
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

    return lineStatsUtils.getTimeInSecs(lastDepartureTime)
end

-- returns arr:[vehicleID:number]
function lineStatsHelper.getAllVehiclesEnRoute()
    return api.engine.system.transportVehicleSystem.getVehiclesWithState(api.type.enum.TransportVehicleState.EN_ROUTE)
end

---@param vehicleID number | string
---@return boolean
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

---gets vehicle type as api.type.enum.Carrier. Defaults to 0 (ROAD) if not known
---@param vehicleID number | string
---@return number
function lineStatsHelper.getVehicleType(vehicleID) 
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return 0 end

    local lineVehicle = api.engine.getComponent(vehicleID, api.type.ComponentType.TRANSPORT_VEHICLE)
    if lineVehicle and lineVehicle.carrier then
        return lineVehicle.carrier
    end

    -- default to road if not known
    return 0
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
-- returns vehicle name
function lineStatsHelper.getVehicleCapacity(vehicleID)
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return 0 end

    local vehicle = api.engine.getComponent(vehicleID, api.type.ComponentType.TRANSPORT_VEHICLE)
    if not vehicle or not vehicle.config or not vehicle.config.capacities then
        return 0
    end

    local totalCapcity = 0
    for _, cap in pairs(vehicle.config.capacities) do
        totalCapcity = totalCapcity + cap
    end
    return totalCapcity

end

---@param vehicleID number | string
---@param vehicle2cargoMap table
-- returns string with vehicle passenger count / total
function lineStatsHelper.getVehiclePassengerCount(vehicleID, vehicle2cargoMap) 
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return false end

    local totalCapcity = lineStatsHelper.getVehicleCapacity(vehicleID)
    
    if not vehicle2cargoMap or #vehicle2cargoMap <= 0 then
        return "???/" .. totalCapcity
    end

    local vehCargo = vehicle2cargoMap[vehicleID]
    if not vehCargo or #vehCargo <= 0 then
        return "0/" .. totalCapcity
    end

    local passengers = #vehCargo[1] -- (PASSENGERS)
    local cargo = 0
    for i = 2, #vehCargo do
        cargo = cargo + #vehCargo[i]
    end

    if passengers > 0 then
        return passengers .. "/" .. totalCapcity
    else
        return cargo .. "/" .. totalCapcity
    end
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
-- returns [vehicleId] arr - vehicles for line 
function lineStatsHelper.getVehicles(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
    return vehiclesForLine
end

---@param lineId number | string
---@param lineStopIdx number
---returns [vehicleId] arr - vehicles which are in the start stop or between the start stop and the next stop
function lineStatsHelper.getVehiclesForSection(lineId, lineStopIdx)
    local vehicleLocs = lineStatsHelper.getVehicleLocations(lineId)

    local res = {}
    if vehicleLocs[lineStopIdx] then 
        for _, value in pairs(vehicleLocs[lineStopIdx]) do
            table.insert(res, value.vehicleId)
        end
    end

    return res
end

---@param lineId any
---returns [key: lineStopIdx: value: "SINGLE_MOVING" | "SINGLE_AT_TERMINAL" | "MANY_MOVING" | "MANY_AT_TERMINAL" | "MOVING_AND_AT_TERMINAL"]
---Note sparse array so a line stop idx may not be present
function lineStatsHelper.getAggregatedVehLocs(lineId)
    local res = {}

    local vehicleLocs = lineStatsHelper.getVehicleLocations(lineId)
    for lineStopIdx, vehicleAtStopDets in pairs(vehicleLocs) do
        local atTermCount = 0
        local movingCount = 0
        for _, vehDetails in pairs(vehicleAtStopDets) do
            if vehDetails.atTerminal == true then
                atTermCount = atTermCount + 1
            else 
                movingCount = movingCount + 1
            end
        end

        -- Both Moving and at terminal
        if movingCount == 1 and atTermCount > 0 then
            res[lineStopIdx] = "SINGLE_MOVING_AND_AT_TERMINAL"
        elseif movingCount > 1 and atTermCount > 0 then
            res[lineStopIdx] = "MANY_MOVING_AND_AT_TERMINAL"

        -- Moving
        elseif movingCount == 1 then
            res[lineStopIdx] = "SINGLE_MOVING"
        elseif movingCount > 1 then
            res[lineStopIdx] = "MANY_MOVING"

        -- At Terminal
        elseif atTermCount == 1 then
            res[lineStopIdx] = "SINGLE_AT_TERMINAL"
        elseif atTermCount > 1 then
            res[lineStopIdx] = "MANY_AT_TERMINAL" 
        else
            res[lineStopIdx] = "ERR"
        end
    end

    return res
end

---@param lineId number | string
---returns [key: lineStopIdx, value: [{vehicleId:number, atTerminal:boolean]]. 
---Note sparse array so a line stop idx may not be present
function lineStatsHelper.getVehicleLocations(lineId)
    -- vehicle.stopIndex is 0 based, while lineStopIdx is 1 based (from api.engine.getComponent(line, api.type.ComponentType.LINE))
    -- Given:
    -- Line stop idx 1 = Station B
    -- Line stop idx 2 = Station A
    -- When the vehicle is:
    --   . atTerminal at A. Vehicle stop Idx = 0. Want lineIdx = 1
    --   -> Heading from A to B. Vehicle stop Idx = 1. Want lineIdx = 1 (we are between stop 1 & 2)
    --   . atTerminal at B. Vehicle stop Idx = 1. Want lineIdx = 2
    --   -> Heading from B and A. Vehicle stop Idx = 0. Want lineIdx = 2 (the last stop on the line)

    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = lineStatsHelper.getVehicles(lineId)
    local lastStopOnLineIdx = #timetableHelper.getAllStations(lineId)
    local res = {}

    for _,vehicleId in pairs(vehiclesForLine) do
        local vehicle = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
        local atTerminal = vehicle.state == api.type.enum.TransportVehicleState.AT_TERMINAL

        local lineStopIdx = vehicle.stopIndex
        if atTerminal == true then
            lineStopIdx = vehicle.stopIndex + 1
        elseif vehicle.stopIndex == 0 then
            lineStopIdx = lastStopOnLineIdx
        end
    
        if not res[lineStopIdx] then
            res[lineStopIdx] = {}
        end
        table.insert(res[lineStopIdx], {
            vehicleId = vehicleId,
            atTerminal = atTerminal
        })
    end

    return res
end

-------------------------------------------------------------
---------------------- Line related -------------------------
-------------------------------------------------------------

---Based off timetableHelper.getAllLines
---Returns array [{id : number, name : String}]
---@return table
function lineStatsHelper.getAllPassengerLines()
    local res = {}
    local lines = api.engine.system.lineSystem.getLines()

    for _,lineId in pairs(lines) do
        local isPassenger = lineStatsHelper.isPassengerLine(lineId)
        if isPassenger then
            local lineName = api.engine.getComponent(lineId, api.type.ComponentType.NAME)
            local lineType = lineStatsHelper.getLineTypeEnum(lineId)

            if lineName and lineName.name then
                table.insert(res, {id = lineId, name = lineName.name, lineType = lineType })
            else
                table.insert(res, {id = lineId, name = "ERROR", lineType = lineType})
            end
        end
    end

    print("Found " .. #res .. " passenger lines")
    return res
end

---@param lineId number | string
---@return number
-- returns Line capacity
function lineStatsHelper.getLineCapacity(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return 0 end

    local vehiclesForLine = lineStatsHelper.getVehicles(lineId)
    local totalCapcity = 0
    for _, vehicleId in pairs(vehiclesForLine) do
        local capacity = lineStatsHelper.getVehicleCapacity(vehicleId)
        totalCapcity = totalCapcity + capacity
    end
    return totalCapcity
end

---returns api.type.enum.Carrier
---@param lineId number | string
---@return number 
function lineStatsHelper.getLineTypeEnum(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return 0 end


    local vehiclesForLine = lineStatsHelper.getVehicles(lineId)
    if vehiclesForLine and vehiclesForLine[1] then
        return lineStatsHelper.getVehicleType(vehiclesForLine[1])
    end
    return 0
end

---comment 
---@param lineId number | string
---@return string 
function lineStatsHelper.getLineTypeStr(lineId)
    local lineTypes = {"RAIL", "ROAD", "TRAM", "WATER", "AIR"}
    local lineTypeEnum = lineStatsHelper.getLineTypeEnum(lineId)

	for _,currentLineType in pairs(lineTypes) do
		if api.type.enum.Carrier[currentLineType] == lineTypeEnum then
			return currentLineType
		end
	end

    -- default to Road if unknown
    return "ROAD"
end


---comment 
---@param lineId number | string
---@return boolean
function lineStatsHelper.isPassengerLine(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return false end

    local vehiclesForLine = lineStatsHelper.getVehicles(lineId)
    if vehiclesForLine and vehiclesForLine[1] then
        local vehicleId = vehiclesForLine[1]

        local vehicle = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
        if not vehicle or not vehicle.config or not vehicle.config.capacities then
            return false
        end

        local passengers = vehicle.config.capacities[1] -- (PASSENGERS)
        return passengers > 0
    end
    return false
end

---@param lineId number | string
-- returns leg Times for line
function lineStatsHelper.getLegTimes(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = lineStatsHelper.getVehicles(lineId)
    local noOfVeh = #vehiclesForLine
    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    local noOfStops = #lineComp.stops

    -- Create a matrix[leg][vehicleLegTime]. 
    -- Legs are the first index. We then store the value for the vehicle legtimes for that leg in the second index
    local legTimes = lineStatsUtils.createOneBasedArrayOfArrays(noOfStops, noOfVeh, 0)

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

    local toReturn = lineStatsUtils.createOneBasedArray(noOfStops, 0)
    for i=1, #legTimes do
        toReturn[i] = lineStatsUtils.avgNonZeroValuesInArray(legTimes[i])
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

---@param lineId number | string
---@return number - lineFrequency
function lineStatsHelper.getFrequencyNum(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return 0 end

    local lineEntity = game.interface.getEntity(lineId)
    if lineEntity and lineEntity.frequency then
        if lineEntity.frequency == 0 then return 0 end
        return 1 / lineEntity.frequency
    else
        return 0
    end
end

---@param lineId number | string
---@param stopIdx number
---@return number - the next stop idx. -1 if it can't find the next stop index
function lineStatsHelper.getNextStop(lineId, stopIdx)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return "ERROR" end 

    local stations = timetableHelper.getAllStations(lineId)
    return lineStatsHelper.getNextStopFromStns(stopIdx, #stations)
end

---@param stopIdx number
---@param noOfStations number
---@return number - the next stop idx. -1 if it can't find the next stop index
function lineStatsHelper.getNextStopFromStns(stopIdx, noOfStations)
    if stopIdx < 1 or stopIdx > noOfStations then
        return -1
    end

    if stopIdx == noOfStations then
        return 1
    else
        return stopIdx + 1
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

---Gets the times for competing lines between a station and all other stations on the line
---@param lineId number
---@param stopIdx number
---@return table -- array [{ toStationId , sortedTimes = table }]
function lineStatsHelper.getLineTimesFromStation(lineId, stopIdx)
    local stations = timetableHelper.getAllStations(lineId)
    local startStationId = stations[stopIdx]
    local startStationLines = api.engine.system.lineSystem.getLineStops(startStationId)
    local res = {}
    local curIdx = lineStatsHelper.getNextStopFromStns(stopIdx, #stations)
    local seenStns = {}
    seenStns[startStationId] = true

    while curIdx ~= stopIdx and curIdx > 0 do
        local toStationId = stations[curIdx]

        -- If stop is seen then don't calc
        if lineStatsUtils.tableHasKey(seenStns, toStationId) == false then
            seenStns[toStationId] = true
            local toStationLines = api.engine.system.lineSystem.getLineStops(toStationId)
            local linesBetweenStation = lineStatsUtils.intersect(startStationLines, toStationLines)
            local legRes = {}
            for _, competingLineId in pairs(linesBetweenStation) do
                local time = lineStatsHelper.getTimeBetweenStations(competingLineId, startStationId, toStationId)
                legRes[competingLineId] = time
            end
            local noOfEntriesInTable = lineStatsUtils.tablelength(legRes)
            if noOfEntriesInTable > 1 then
                table.insert(res, { toStationId = toStationId, sortedTimes = lineStatsUtils.sortByValues(legRes) })
            end
        end
        curIdx = lineStatsHelper.getNextStopFromStns(curIdx, #stations)
    end

    return res
end

function lineStatsHelper.getLineTimesBetweenStation(startStationId, endStationId)
    if not startStationId or not endStationId then
        return {}
    end

    local startStationLines = api.engine.system.lineSystem.getLineStops(startStationId)
    local endStationLines = api.engine.system.lineSystem.getLineStops(endStationId)

    local linesBetweenStation = lineStatsUtils.intersect(startStationLines, endStationLines)

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

    for _, startIdx in pairs(startStopNos) do
        for _, endIdx in pairs(endStopNos) do
            local i = startIdx
            local totalTime = 0
            while i ~= endIdx do
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


function lineStatsHelper.getLegDemands(lineId)
    if type(lineId) == "string" then line = tonumber(lineId) end
    if not(type(lineId) == "number") then return "ERROR" end 


    -- array stop, travelling on segment
    local personsForLineArr = api.engine.system.simPersonSystem.getSimPersonsForLine(lineId)
    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    local noOfStops = #lineComp.stops
    local legCounts = lineStatsUtils.createOneBasedArray(noOfStops, 0)
    local stations = timetableHelper.getAllStations(lineId)

    for _, personId in pairs(personsForLineArr) do 
        local simEntityAtTerminal = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_TERMINAL)
        local simEntityAtVeh= api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_VEHICLE)

        -- Waiting at terminal
        if simEntityAtTerminal then
            if simEntityAtTerminal.line == lineId then
                lineStatsHelper.recordSimJourney(simEntityAtTerminal, legCounts, #stations)
            end
        end
        -- On Vehicle
        if simEntityAtVeh then     
            if simEntityAtVeh.line == lineId then    
                lineStatsHelper.recordSimJourney(simEntityAtVeh, legCounts, #stations)
            end
        end
    end

    print("Leg Counts for line " .. lineId .. ": " .. lineStatsUtils.dump(legCounts))
    return legCounts;
end

function lineStatsHelper.recordSimJourney(simEntity, legCounts, noOfStations) 
    local startStop = simEntity.lineStop0 + 1
    local destStop = simEntity.lineStop1 + 1
    local curIdx = startStop
    while curIdx ~= destStop and curIdx > 0 do
        legCounts[curIdx] = legCounts[curIdx] + 1
        curIdx = lineStatsHelper.getNextStopFromStns(curIdx, noOfStations)
    end
end


---@param lineId number | string
-- returns object
-- Fields
-- totalCount= Number
-- waitingCount = Number
-- inVehCount = Number
-- lineFreq = Number, frequency of the line in seconds
-- peopleAtStop = [Number], arr: number of people waiting at each stop
-- peopleAtStopLongWait = [Number], arr: number of people waiting for a long time at each stop
-- stopAvgWaitTimes = [Number], arr: average wait time at each stop
function lineStatsHelper.getPassengerStatsForLine(lineId)
    if type(lineId) == "string" then line = tonumber(lineId) end
    if not(type(lineId) == "number") then return "ERROR" end 

    local gameTime = lineStatsUtils.getTime()
    local personsForLineArr = api.engine.system.simPersonSystem.getSimPersonsForLine(lineId)

    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    local noOfStops = #lineComp.stops
    local lineFreq = lineStatsHelper.getFrequencyNum(lineId)

    local res = {}
    res.totalCount = 0
    res.waitingCount = 0
    res.inVehCount = 0
    res.lineFreq = lineFreq
    res.lineCapacity = lineStatsHelper.getLineCapacity(lineId)
    res.peopleAtStop = lineStatsUtils.createOneBasedArray(noOfStops, 0)
    res.peopleAtStopLongWait = lineStatsUtils.createOneBasedArray(noOfStops, 0)
    local stopWaitTimes = lineStatsUtils.createOneBasedArray(noOfStops, 0)
    res.stopAvgWaitTimes = lineStatsUtils.createOneBasedArray(noOfStops, 0)

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
                local waitTime = gameTime - lineStatsUtils.getTimeInSecs(simEntityAtTerminal.arrivalTime)
                stopWaitTimes[stopNo] = stopWaitTimes[stopNo] + waitTime
                if lineFreq > 60  and waitTime > lineFreq + 60 then
                    res.peopleAtStopLongWait[stopNo] =  res.peopleAtStopLongWait[stopNo] + 1
                elseif lineFreq < 60 and waitTime > 5 * 60 then
                    -- Default to 5 min if no line frequency
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
        res.stopAvgWaitTimes[stopNo] = lineStatsUtils.safeDivide(stopWaitTimes[stopNo], count)
    end

    return res
end

-------------------------------------------------------------
---------------------- Issues Locating Functions ------------
-------------------------------------------------------------

-- Stop with more people than train capacity (divide line capacity/no of vehicles)


-- 2x more people waiting than loaded

return lineStatsHelper

