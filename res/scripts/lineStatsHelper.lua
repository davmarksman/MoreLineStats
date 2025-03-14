local timetableHelper = require "timetableHelper"

local lineStatsHelper = {}


-------------------------------------------------------------
---------------------- Vehicle related ----------------------
-------------------------------------------------------------

-- returns table where index is vehicle id, and value is time since last depature
function lineStatsHelper.FindLostVehicles()
    local gameTime = lineStatsHelper.getTime()
    local vehicles = lineStatsHelper.getAllVehiclesEnRoute()
    local res = {}

    for i, vehicleId in pairs(vehicles) do
        local vehicle = lineStatsHelper.getVehicle(vehicleId)
        if vehicle and vehicle.carrier and vehicle.line then
            if vehicle.carrier == api.type.enum.JournalEntryCarrier.RAIL then
                local lastDeparture = lineStatsHelper.getLastDepartureTimeFromVeh(vehicle)
                local timeSinceDep = gameTime - lastDeparture

                if lastDeparture > 0 and timeSinceDep >  120 then
                    local lineLegTimes = lineStatsHelper.getLegTimes(vehicle.line)
                    if lineLegTimes and lineLegTimes[1] then
                        -- Use leg times to work out if vehicle is lost
                        local maxLegTime = timetableHelper.maximumArray(lineLegTimes)

                        if maxLegTime > 0 and timeSinceDep > 2 * maxLegTime then
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

-- returns [vehicleID:number]
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
-- returns bool
function lineStatsHelper.getVehicleName(vehicleID) 
    if type(vehicleID) == "string" then vehicleID = tonumber(vehicleID) end
    if not(type(vehicleID) == "number") then print("Expected String or Number") return false end

    local err, res = pcall(function()
        return api.engine.getComponent(vehicleID, api.type.ComponentType.NAME)
    end)
    if err and res then return res.name else return "ERROR" end
end

---@param vehicleID number | string
-- returns bool
function lineStatsHelper.getLineNameOfVehicle(vehicleID) 
    local vehicle = lineStatsHelper.getVehicle(vehicleID)
    if vehicle and vehicle.line then
        return timetableHelper.getLineName(vehicle.line)     
    else
        return "Unknown"
    end
end





-------------------------------------------------------------
---------------------- Line related -------------------------
-------------------------------------------------------------

-- Modified from timetableHelper to try second vehicle too
---@param line number | string
-- returns [time: Number] Array indexed by station index in sec starting with index 1
function lineStatsHelper.getLegTimes(line)
    if type(line) == "string" then line = tonumber(line) end
    if not(type(line) == "number") then return {} end

    local vehicleLineMap = api.engine.system.transportVehicleSystem.getLine2VehicleMap()
    if vehicleLineMap[line] == nil or vehicleLineMap[line][1] == nil then return {}end
    local vehicle = vehicleLineMap[line][1]
    local vehicleObject = api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
    if vehicleObject and vehicleObject.sectionTimes then
        return vehicleObject.sectionTimes
    else
        -- try second vehicle
        if vehicleLineMap[line][2] == nil then             
            return {}
        end
        local vehicle2 = vehicleLineMap[line][1]
        local vehicleObject2 = api.engine.getComponent(vehicle2, api.type.ComponentType.TRANSPORT_VEHICLE)

        if vehicleObject2 and vehicleObject2.sectionTimes then
            return vehicleObject2.sectionTimes
        else
            return {}
        end
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

    print("getLinesThroughStation " .. startStationId .. " - " .. endStationId )
    local startStationLines = api.engine.system.lineSystem. getLineStops(startStationId)
    local endStationLines = api.engine.system.lineSystem. getLineStops(endStationId)


    local linesBetweenStation = lineStatsHelper.intersect(startStationLines, endStationLines)

    local res = {}
    for _, lineId in pairs(linesBetweenStation) do
        -- local stationLegTime = lineStatsHelper.getLegTimes(lineId)
        -- for idx, lineStationId in pairs(timetableHelper.getAllStations(lineId)) do
        --     local jurneyTime = ""
        --     if (stationLegTime and stationLegTime[idx]) then
        --         jurneyTime = "Journey Time: " .. os.date('%M:%S', stationLegTime[idx])
        --     else
        --         jurneyTime = ""
        --     end
        --     print("idx " .. idx .. " - lineStationId " .. lineStationId .. " stationLegTime " .. jurneyTime)
        -- end
   
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

    for s, sidx in pairs(startStopNos) do
        for e, eidx in pairs(endStopNos) do
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
-- peopleAtStop = [Number], number of people waiting at stops
-- stopAvgWaitTimes = [Number], average wait time at stops
function lineStatsHelper.getPassengerStatsForLine(lineId)
    if type(lineId) == "string" then line = tonumber(lineId) end
    if not(type(lineId) == "number") then return "ERROR" end 

    local gameTime = lineStatsHelper.getTime()
    local personsForLineArr = api.engine.system.simPersonSystem.getSimPersonsForLine(lineId)
    local noOfStops = #api.engine.getComponent(lineId, api.type.ComponentType.LINE).stops

    local res = {}
    res.totalCount = 0
    res.waitingCount = 0
    res.inVehCount = 0
    res.peopleAtStop = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    res.peopleAtStop5m = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    -- res.peopleMoving = lineStatsHelper.createZeroBasedArray(noOfStops, 0)
    local stopWaitTimes = lineStatsHelper.createOneBasedArray(noOfStops, 0)
    res.stopAvgWaitTimes = lineStatsHelper.createOneBasedArray(noOfStops, 0)

    for i, personId in pairs(personsForLineArr) do 
        local simEntityAtTerminal = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_TERMINAL)
        local simEntityMoving = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_MOVING)
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
                if (waitTime < 300) then
                    res.peopleAtStop5m[stopNo] =  res.peopleAtStop5m[stopNo] + 1
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

        -- Walking towards terminal
        -- if simEntityMoving then      
        --     if simEntityMoving.line == lineId then      
        --         --res.totalCount = res.totalCount + 1
        --         --res.atStopCount = res.atStopCount + 1
        --         local stopNo = simEntityMoving.lineStop0
        --         res.peopleMoving[stopNo] = res.peopleMoving[stopNo] + 1
        --     end
        -- end
    end

    for stopNo, count in pairs(res.peopleAtStop) do
        res.stopAvgWaitTimes[stopNo] = lineStatsHelper.safeDivide(stopWaitTimes[stopNo], count)
    end

    return res
end


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

    return intersectVals
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
-- returns a zero based array with all values set to defaultVal
function lineStatsHelper.createZeroBasedArray(count, defaultVal)
    local arr={}
    for i=0,count do
        arr[i]=defaultVal
    end
    return arr
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

-- returns Number, current GameTime in seconds

function lineStatsHelper.getTime()
    local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
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

function lineStatsHelper.safeDivide(num, denom)
    if denom == 0 then
        return 0
    else
        return num / denom
    end
end


return lineStatsHelper


