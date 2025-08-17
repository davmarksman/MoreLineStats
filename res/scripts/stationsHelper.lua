local journeyHelper = require "journeyHelper"
local luaUtils = require "luaUtils"
local gameApiUtils = require "gameApiUtils"

local stationsHelper = {}

-------------------------------------------------------------
---------------------- Station related ----------------------
-------------------------------------------------------------


---Gets stations information for a line
---@param lineId number | string
---@return table
function stationsHelper.getStationInfo(lineId)
    local toReturn = {}
    local stationsList = stationsHelper.getAllStations(lineId)
    for stnIdx, stnGpId in pairs(stationsList) do
        toReturn[stnIdx] = {}
        toReturn[stnIdx].station = stationsHelper.getStationNameWithId(stnGpId)
        local nextStopIdx = stationsHelper.getNextStopFromStns(stnIdx, #stationsList)
        toReturn[stnIdx].nextStopIdx = nextStopIdx
        toReturn[stnIdx].nextStation = stationsHelper.getStationNameWithId(stationsList[nextStopIdx])
    
        -- Distance
        local stationLoc = stationsHelper.getStationLocation(stnGpId)
        local nextStnLoc = stationsHelper.getStationLocation(stationsList[nextStopIdx])

        if stationLoc and nextStnLoc then
            toReturn[stnIdx].distance = journeyHelper.distance(
                stationLoc.x, stationLoc.y, stationLoc.z,
                nextStnLoc.x, nextStnLoc.y, nextStnLoc.z
            )
        else
            toReturn[stnIdx].distance = 0
        end
        toReturn[stnIdx].distanceKm = toReturn[stnIdx].distance / 1000
    end
    return toReturn
end

-- Gets all stations group ids on a line. Code sourced from Timetables Mod
---@param lineId number | string
-- returns [id : Number] Array of stationGroupIds. This is a 1 based index
function stationsHelper.getAllStations(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    return stationsHelper.getAllStationsFromLineComponent(lineComp)
end

-- Gets all stations group ids on a line. Code sourced from Timetables Mod
---@param lineComp table
-- returns [id : Number] Array of stationGroupIds. This is a 1 based index
function stationsHelper.getAllStationsFromLineComponent(lineComp)
    if lineComp and lineComp.stops then
        local res = {}
        for k, v in pairs(lineComp.stops) do
            res[k] = v.stationGroup
        end
        return res
    else
        return {}
    end
end


---@param lineId number | string
---@param stopIdx number
---@return number - the next stop idx. -1 if it can't find the next stop index
function stationsHelper.getNextStop(lineId, stopIdx)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return "ERROR" end 

    local stations = stationsHelper.getAllStations(lineId)
    return stationsHelper.getNextStopFromStns(stopIdx, #stations)
end

---@param stopIdx number
---@param noOfStations number
---@return number - the next stop idx. -1 if it can't find the next stop index
function stationsHelper.getNextStopFromStns(stopIdx, noOfStations)
    if stopIdx < 1 or stopIdx > noOfStations then
        return -1
    end

    if stopIdx == noOfStations then
        return 1
    else
        return stopIdx + 1
    end
end


---@param stationGroupId number | string
---@return table  -- {id:number , name : String}
function stationsHelper.getStationNameWithId(stationGroupId)
    if type(stationGroupId) == "string" then stationGroupId = tonumber(stationGroupId) end
    if not(type(stationGroupId) == "number") then return "ERROR" end

    local stationObject = api.engine.getComponent(stationGroupId, api.type.ComponentType.NAME)
    if stationObject and stationObject.name then
        return { id = stationGroupId, name = stationObject.name }
    else
        return { id = stationGroupId, name = "ERROR"}
    end
end

---Gets the times for competing lines between a station and all other stations on the line
---@param lineId number
---@param stopIdx number
---@return table -- array [{ toStationId , sortedTimes = table }]
function stationsHelper.getLineTimesFromStation(lineId, stopIdx)
    local stations = stationsHelper.getAllStations(lineId)
    local startStationId = stations[stopIdx]
    local startStationLines = api.engine.system.lineSystem.getLineStops(startStationId)
    local res = {}
    local curIdx = stationsHelper.getNextStopFromStns(stopIdx, #stations)
    local seenStns = {}
    seenStns[startStationId] = true

    while curIdx ~= stopIdx and curIdx > 0 do
        local toStationId = stations[curIdx]

        -- If stop is seen then don't calc
        if luaUtils.tableHasKey(seenStns, toStationId) == false then
            seenStns[toStationId] = true
            local toStationLines = api.engine.system.lineSystem.getLineStops(toStationId)
            local linesBetweenStation = luaUtils.intersect(startStationLines, toStationLines)
            local legRes = {}
            for _, competingLineId in pairs(linesBetweenStation) do
                local time = stationsHelper.getTimeBetweenStations(competingLineId, startStationId, toStationId)
                legRes[competingLineId] = time
            end
            local noOfEntriesInTable = luaUtils.tablelength(legRes)
            if noOfEntriesInTable > 1 then
                table.insert(res, { toStationId = toStationId, sortedTimes = luaUtils.sortByValues(legRes) })
            end
        end
        curIdx = stationsHelper.getNextStopFromStns(curIdx, #stations)
    end

    return res
end

---Gets the journey times for all lines between two stations
---@param startStationId any
---@param endStationId any
---@return table
function stationsHelper.getLineTimesBetweenStation(startStationId, endStationId)
    if not startStationId or not endStationId then
        return {}
    end

    local startStationLines = api.engine.system.lineSystem.getLineStops(startStationId)
    local endStationLines = api.engine.system.lineSystem.getLineStops(endStationId)

    local linesBetweenStation = luaUtils.intersect(startStationLines, endStationLines)

    local res = {}
    for _, lineId in pairs(linesBetweenStation) do
        local time = stationsHelper.getTimeBetweenStations(lineId, startStationId, endStationId)
        res[lineId] = time
    end

    return res
end

-- Doesn't do error checking so parameters need to be correct
function stationsHelper.getTimeBetweenStations(lineId, startStationId, endStationId)
    local stationLegTime = journeyHelper.getLegTimes(lineId)
    local toReturnTime = 0

    if not stationLegTime then
        return toReturnTime
    end

    local startStopNos = {}
    local endStopNos = {}

    local stationsArr = stationsHelper.getAllStations(lineId)
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

---@param lineId number
---@param lineStopIdx number note this is 1 based as opposed to vehicle stop index that is 0 based
---@return string stationGroupId 
function stationsHelper.GetStationGroupIdForStop(lineId, lineStopIdx)
    local stations = stationsHelper.getAllStations(lineId)
    return stations[lineStopIdx]
end

---Get all lines that stop at a station group
---@param stationGroupId any
function stationsHelper.GetLinesThatStopAtStation(stationGroupId)
    local lineIds = api.engine.system.lineSystem.getLineStops(stationGroupId)
    local res = {}

    -- ToDo filter to passenger lines only
    for _, lineId in pairs(lineIds) do
        res[lineId] = gameApiUtils.getEntityName(lineId)
    end

    return res
end


---Get Station Location
---@param stationGroupId any
---@return table | nil  -- returns { x = -2,  y = -2, z = 90.708602905273, w = 1} or nil if no station found
function stationsHelper.getStationLocation(stationGroupId)
    local success, returnedData = xpcall(function()
        return stationsHelper.getStationLocationInternal(stationGroupId)
    end, function()
        print('Unable to get location for stationGroupId: ' .. tostring(stationGroupId))
    end)

    if success == true then
        return returnedData
    else
        return nil
    end
end

function stationsHelper.getStationLocationInternal(stationGroupId)
    local stationGroupComp = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)

    if stationGroupComp.stations and stationGroupComp.stations[1] then
        local stationId = stationGroupComp.stations[1]

        -- Get station construction
        local stationConstrId = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(stationId)
        if stationConstrId and stationConstrId ~= -1 then
            -- Get construction using that
            local stationConstr = api.engine.getComponent(stationConstrId, api.type.ComponentType.CONSTRUCTION)
            -- Get coords
            if stationConstr and stationConstr.transf then
                return stationConstr.transf:cols(3)
            end
        else
            -- probably a bus stop
            local busStopEntityId = api.engine.getComponent(stationId, api.type.ComponentType.STATION).terminals[1].vehicleNodeId.entity
            local edge = api.engine.getComponent(busStopEntityId, api.type.ComponentType.BASE_EDGE)
            local node = api.engine.getComponent(edge.node0, api.type.ComponentType.BASE_NODE)
            if node.position then
                return node.position
            end
        end
    end

    return nil
end

return stationsHelper