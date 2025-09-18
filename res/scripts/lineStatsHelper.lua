local luaUtils = require "luaUtils"
local gameApiUtils = require "gameApiUtils"
local stationsHelper = require "stationsHelper"
local vehiclesHelper = require "vehiclesHelper"
local journeyHelper = require "journeyHelper"
local lineStatsHelper = {}

-------------------------------------------------------------
---------------------- All stats about line -----------------
-------------------------------------------------------------

--- Gets the stats for all lines
---@return [table] --array of line stats
function lineStatsHelper.getPassengerStatsForAllLines()
    local lines = lineStatsHelper.getAllPassengerLines()
    local res = {}
    local stationsCache = {}

    for _, lineId in pairs(lines) do
       local success, returnedData = xpcall(function()
            return lineStatsHelper.getPassengerStatsForLine(lineId, stationsCache)
        end, function()
            print('Line Id: ' .. tostring(lineId) .. " failed")
        end)

        if success == true and returnedData then
            table.insert(res, returnedData)
        end
    end
    return res
end

---@param lineId number | string
---@return table |nil -- {lineId,lineName,noOfStops,vehicleTypeStr,lineFreq,lineFreqStr,stationLegTimes,lineCapacity,
--vehiclePositions,stationInfos,totalCount,waitingCount,inVehCount,peopleAtStop,
--peopleAtStopLongWait,stopAvgWaitTimes,legDemand }
function lineStatsHelper.getPassengerStatsForLine(lineId, stationsLocCache)
    if type(lineId) == "string" then line = tonumber(lineId) end
    if not(type(lineId) == "number") then return nil end

    if not stationsLocCache then
        stationsLocCache = {}
    end

    local lineComp = gameApiUtils.getLineComponent(lineId)
    if not lineComp then
        print("lineStatsHelper.getPassengerStatsForLine: Invalid lineId: " .. tostring(lineId))
        return nil
    end

    local lineEntity = game.interface.getEntity(lineId)
    if not lineEntity then
        print("lineStatsHelper.getPassengerStatsForLine: Invalid entity for lineId: " .. tostring(lineId))
        return nil
    end

    local noOfStops = #lineComp.stops

    local lineFreq = 0
    if lineEntity.frequency then
        lineFreq = luaUtils.safeDivide(1, lineEntity.frequency)
    end

    local res = {}
    res.lineId = lineId
    res.lineName = lineEntity.name
    res.noOfStops = noOfStops
    res.vehicleTypeStr = lineStatsHelper.getLineTypeStr(lineId)
    res.lineFreq = lineFreq
    res.lineFreqStr = luaUtils.getTimeStr(lineFreq)
    res.stationLegTimes = journeyHelper.getLegTimes(lineId)
    res.lineCapacity = lineStatsHelper.getLineCapacity(lineId)
    res.vehiclePositions = lineStatsHelper.getAggregatedVehLocs(lineId)
    res.stationInfos = stationsHelper.getStationInfo(lineId, stationsLocCache)
    res.vehicleCount = lineStatsHelper.getVehicleCount(lineId)

    lineStatsHelper.calcDistanceAndSpeeds(res)
    lineStatsHelper.fillPassengerInfo(res, lineId, noOfStops, lineFreq)
    return res
end

function lineStatsHelper.calcDistanceAndSpeeds(res)
    local totalDistance = 0
    local totalLegTime = 0
    local haveAllInfo = true;
    local haveAllDistInfo = true;
    for stnIdx, stationInfo in pairs(res.stationInfos) do
        if res.stationLegTimes[stnIdx] and res.stationLegTimes[stnIdx] > 0 and stationInfo.distance > 0 then
            totalDistance = totalDistance + stationInfo.distance
            totalLegTime = totalLegTime + res.stationLegTimes[stnIdx]
            local avgSpeed = luaUtils.safeDivide(stationInfo.distance, res.stationLegTimes[stnIdx])
            stationInfo.avgSpeed = avgSpeed
            stationInfo.avgSpeedStr = string.format("%d km/h", avgSpeed * 3.6 ) -- convert m/s to km/h
        elseif stationInfo.distance > 0 then
            haveAllInfo = false
            totalDistance = totalDistance + stationInfo.distance
            stationInfo.avgSpeed = 0
            stationInfo.avgSpeedStr = "??? km/h"
        else
            haveAllInfo = false
            haveAllDistInfo = false
            stationInfo.avgSpeed = 0
            stationInfo.avgSpeedStr = "??? km/h"
        end
    end

    -- Defaults
    res.totalDistance = 0
    res.totalDistanceKm = 0
    res.totalAvgSpeed = 0
    res.totalAvgSpeedStr = "??? km/h"
    res.totalLegTime = 0

    -- Set if have data
    if haveAllInfo then
        res.totalDistance = totalDistance
        res.totalDistanceKm = totalDistance/1000
        res.totalAvgSpeed = luaUtils.safeDivide(totalDistance, totalLegTime)
        res.totalAvgSpeedStr = string.format("%d km/h", res.totalAvgSpeed  * 3.6) -- convert m/s to km/h
        res.totalLegTime = totalLegTime
    elseif haveAllDistInfo then
        res.totalDistance = totalDistance
        res.totalDistanceKm = totalDistance/1000
    end
end

-------------------------------------------------------------
---------------------- Line related -------------------------
-------------------------------------------------------------

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

    if gameApiUtils.entityExists(lineId) then
        local vehiclesForLine = vehiclesHelper.getVehicles(lineId)
        local lastStopOnLineIdx = #stationsHelper.getAllStations(lineId)
        local res = {}

        for _,vehicleId in pairs(vehiclesForLine) do
            local vehicle = gameApiUtils.getVehicleComponent(vehicleId)
            if vehicle then
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
        end
        return res
    else
        print("lineId no longer exists: ")
        return {}
    end
end

---Based off timetableHelper.getAllLines
---@return table -- array [id : number]
function lineStatsHelper.getAllPassengerLines()
    local res = {}
    local lines = api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer())

    for _,lineId in pairs(lines) do
        local isPassenger = lineStatsHelper.isPassengerLine(lineId)
        if isPassenger == true then
            table.insert(res, lineId)
        end
    end

    -- print("Found " .. #res .. " passenger lines")
    return res
end

---@param lineId number | string
---@return number
-- returns Line capacity
function lineStatsHelper.getLineCapacity(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return 0 end

    local vehiclesForLine = vehiclesHelper.getVehicles(lineId)
    local totalCapcity = 0
    for _, vehicleId in pairs(vehiclesForLine) do
        local capacity = vehiclesHelper.getVehicleCapacity(vehicleId)
        totalCapcity = totalCapcity + capacity
    end
    return totalCapcity
end

---returns api.type.enum.Carrier
---@param lineId number | string
---@return number --api.type.enum.Carrier
function lineStatsHelper.getLineTypeEnum(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return 0 end

    local vehiclesForLine = vehiclesHelper.getVehicles(lineId)
    if vehiclesForLine and vehiclesForLine[1] then
        return vehiclesHelper.getVehicleType(vehiclesForLine[1])
    end
    return 0
end

---@param lineId number | string
---@return number
function lineStatsHelper.getVehicleCount(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return 0 end

    local vehiclesForLine = vehiclesHelper.getVehicles(lineId)
    if vehiclesForLine then
        return #vehiclesForLine
    end
    return 0
end

---Gets line type as a string 
---@param lineId number | string
---@return string -- one of "RAIL", "ROAD", "TRAM", "WATER", "AIR"
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

---Gets if a line is a passenger line 
---@param lineId number | string
---@return boolean
function lineStatsHelper.isPassengerLine(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return false end

    -- Short cut
    -- local start_time = os.clock()
    local lineEntity = game.interface.getEntity(lineId)
    if lineEntity and lineEntity.itemsTransported and lineEntity.itemsTransported["PASSENGERS"] then
        if lineEntity.itemsTransported["PASSENGERS"] > 0 then
            -- print(string.format("lineStatsHelper.isPassengerLine, Entity, Elapsed time: %.5f", os.clock() - start_time))
            return true
        end
    end

    -- Try using vehicles
    -- local start_time2 = os.clock()
    local vehiclesForLine = vehiclesHelper.getVehicles(lineId)
    if vehiclesForLine and vehiclesForLine[1] then
        local vehicleId = vehiclesForLine[1]

        local vehicle = gameApiUtils.getVehicleComponent(vehicleId)
        if not vehicle or not vehicle.config or not vehicle.config.capacities then
            return false
        end

        local passengers = vehicle.config.capacities[1] -- (PASSENGERS)
        return passengers > 0
    end
    -- print(string.format("lineStatsHelper.isPassengerLine, Veh, Elapsed time: %.5f", os.clock() - start_time2))

    return false
end

-------------------------------------------------------------
---------------------- Passengers Functions -----------------
-------------------------------------------------------------
function lineStatsHelper.fillPassengerInfo(res, lineId, noOfStops, lineFreq)
    local gameTime = gameApiUtils.getTime()
    local personsForLineArr = api.engine.system.simPersonSystem.getSimPersonsForLine(lineId)
    res.totalCount = 0
    res.waitingCount = 0
    res.inVehCount = 0
    res.peopleAtStop = luaUtils.createOneBasedArray(noOfStops, 0)
    res.peopleAtStopLongWait = luaUtils.createOneBasedArray(noOfStops, 0)
    res.legDemand = luaUtils.createOneBasedArray(noOfStops, 0)

    for _, personId in pairs(personsForLineArr) do 
        local simEntityAtTerminal = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_TERMINAL)
        local simEntityAtVeh = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_VEHICLE)

        -- Waiting at terminal
        if simEntityAtTerminal then 
            if simEntityAtTerminal.line == lineId then
                local stopNo = simEntityAtTerminal.lineStop0 + 1

                res.totalCount = res.totalCount + 1
                res.waitingCount  = res.waitingCount + 1
                res.peopleAtStop[stopNo] = res.peopleAtStop[stopNo] + 1
                local waitTime = gameTime - luaUtils.getTimeInSecs(simEntityAtTerminal.arrivalTime)

                if lineFreq > 60  and waitTime > lineFreq + 60 then
                    res.peopleAtStopLongWait[stopNo] =  res.peopleAtStopLongWait[stopNo] + 1
                elseif lineFreq < 60 and waitTime > 5 * 60 then
                    -- Default to 5 min if no line frequency
                    res.peopleAtStopLongWait[stopNo] =  res.peopleAtStopLongWait[stopNo] + 1
                end
                lineStatsHelper.recordSimJourney(simEntityAtTerminal, res.legDemand, noOfStops)

            end
        end
        -- On Vehicle
        if simEntityAtVeh then
            if simEntityAtVeh.line == lineId then
                res.totalCount = res.totalCount + 1
                res.inVehCount = res.inVehCount + 1
                lineStatsHelper.recordSimJourney(simEntityAtVeh, res.legDemand, noOfStops)
            end
        end
    end

    res.maxAtStop = luaUtils.maximumArray(res.peopleAtStop)
    res.maxLongWait = luaUtils.maximumArray(res.peopleAtStopLongWait)

    return res
end

function lineStatsHelper.recordSimJourney(simEntity, legCounts, noOfStations) 
    local startStop = simEntity.lineStop0 + 1
    local destStop = simEntity.lineStop1 + 1
    local curIdx = startStop
    while curIdx ~= destStop and curIdx > 0 do
        legCounts[curIdx] = legCounts[curIdx] + 1
        curIdx = stationsHelper.getNextStopFromStns(curIdx, noOfStations)
    end
end

-------------------------------------------------------------
---------------------- Issues Locating Functions ------------
-------------------------------------------------------------

-- Stop with more people than train capacity (divide line capacity/no of vehicles)
-- 2x more people waiting than loaded

return lineStatsHelper