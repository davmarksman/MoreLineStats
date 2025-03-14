-- Code sourced from Timetables Mod

local timetableHelper = {}


-------------------------------------------------------------
---------------------- Vehicle related ----------------------
-------------------------------------------------------------


---@param line number
-- returns [{stopIndex: Number, vehicle: Number, atTerminal: Bool, countStr: "SINGLE"| "MANY" }]
--         indext by StopIndes : string
function timetableHelper.getTrainLocations(line)
    local res = {}
    local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
    for _,v in pairs(vehicles) do
        local vehicle = api.engine.getComponent(v, api.type.ComponentType.TRANSPORT_VEHICLE)
        local atTerminal = vehicle.state == api.type.enum.TransportVehicleState.AT_TERMINAL
        if res[vehicle.stopIndex] then
            local prevAtTerminal = res[vehicle.stopIndex].atTerminal
            res[vehicle.stopIndex] = {
                stopIndex = vehicle.stopIndex,
                vehicle = v,
                atTerminal = (atTerminal or prevAtTerminal),
                countStr = "MANY"
            }
        else
            res[vehicle.stopIndex] = {
                stopIndex = vehicle.stopIndex,
                vehicle = v,
                atTerminal = atTerminal,
                countStr = "SINGLE"
            }
        end
    end
    return res
end





-------------------------------------------------------------
---------------------- Line related -------------------------
-------------------------------------------------------------
---
---@param lineType string, eg "RAIL", "ROAD", "TRAM", "WATER", "AIR"
-- returns Bool
function timetableHelper.isLineOfType(lineType)
    local lines = api.engine.system.lineSystem.getLines()
    local res = {}
    for k,l in pairs(lines) do
        res[k] = timetableHelper.lineHasType(l, lineType)
    end
    return res
end

---@param line number | string
-- returns lineName : String
function timetableHelper.getLineName(line)
    if type(line) == "string" then line = tonumber(line) end
    if not(type(line) == "number") then return "ERROR" end

    local err, res = pcall(function()
        return api.engine.getComponent(line, api.type.ComponentType.NAME)
    end)
    local component = res
    if err and component and component.name then
        return component.name
    else
        return "ERROR"
    end
end

---@param line number | string
-- returns lineFrequency : String, formatted '%M:%S'
function timetableHelper.getFrequency(line)
    if type(line) == "string" then line = tonumber(line) end
    if not(type(line) == "number") then return "ERROR" end

    local lineEntity = game.interface.getEntity(line)
    if lineEntity and lineEntity.frequency then
        if lineEntity.frequency == 0 then return "--" end
        local x = 1 / lineEntity.frequency
        return math.floor(x / 60) .. ":" .. os.date('%S', x)
    else
        return "--"
    end
end

-- returns [{id : number, name : String}]
function timetableHelper.getAllLines()
    local res = {}
    local ls = api.engine.system.lineSystem.getLines()

    for k,l in pairs(ls) do
        local lineName = api.engine.getComponent(l, api.type.ComponentType.NAME)
        if lineName and lineName.name then
            res[k] = {id = l, name = lineName.name}
        else
            res[k] = {id = l, name = "ERROR"}
        end
    end

    return res
end


-------------------------------------------------------------
---------------------- Station related ----------------------
-------------------------------------------------------------


---@param line number | string
-- returns [id : Number] Array of stationIds
function timetableHelper.getAllStations(line)
    if type(line) == "string" then line = tonumber(line) end
    if not(type(line) == "number") then return "ERROR" end

    local lineObject = api.engine.getComponent(line, api.type.ComponentType.LINE)
    if lineObject and lineObject.stops then
        local res = {}
        for k, v in pairs(lineObject.stops) do
            res[k] = v.stationGroup
        end
        return res
    else
        return {}
    end
end

---@param station number | string
-- returns stationName : String
function timetableHelper.getStationName(station)
    if type(station) == "string" then station = tonumber(station) end
    if not(type(station) == "number") then return "ERROR" end

    local err, res = pcall(function()
        return api.engine.getComponent(station, api.type.ComponentType.NAME)
    end)
    if err and res then return res.name else return "ERROR" end
end


---@param line number | string
---@param stopNumber number
-- returns stationGroupID : Number and -1 in Error Case
function timetableHelper.getStationGroupID(line, stopNumber)
    if type(line) == "string" then line = tonumber(line) end
    if not(type(line) == "number") then return -1 end

    local lineObject = api.engine.getComponent(line, api.type.ComponentType.LINE)
    if lineObject and lineObject.stops and lineObject.stops[stopNumber] then
        return lineObject.stops[stopNumber].stationGroup
    else
        return -1
    end
end

-------------------------------------------------------------
---------------------- Array Functions ----------------------
-------------------------------------------------------------

---@param arr table
-- returns [Number], an Array where the index it the source element and the number is the target position
function timetableHelper.getOrderOfArray(arr)
    local toSort = {}
    for k,v in pairs(arr) do
        toSort[k] = {key =  k, value = v}
    end
    table.sort(toSort, function(a,b)
        return string.lower(a.value) < string.lower(b.value)
    end)
    local res = {}
    for k,v in pairs(toSort) do
        res[k-1] = v.key-1
    end
    return res
end

---@param a table
---@param b table
-- returns Array, the merged arrays a,b
function timetableHelper.mergeArray(a,b)
    if a == nil then return b end
    if b == nil then return a end
    local ab = {}
    for _, v in pairs(a) do
        table.insert(ab, v)
    end
    for _, v in pairs(b) do
        table.insert(ab, v)
    end
    return ab
end


-- returns [{vehicleID: lineID}]
function timetableHelper.getAllVehiclesAtTerminal()
    return api.engine.system.transportVehicleSystem.getVehiclesWithState(api.type.enum.TransportVehicleState.AT_TERMINAL)
    --[[local res = {}
    local vehicleMap = api.engine.system.transportVehicleSystem.getLine2VehicleMap()
    for k,v in pairs(vehicleMap) do
        if (hasTimetable(k)) then
            for _,v2 in pairs(v) do
                res[v2] = k
            end
        end
    end
    return res]]--
end


-- returns Number, current GameTime in seconds
function timetableHelper.getTime()
    local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
    if time then
        time = math.floor(time/ 1000)
        return time
    else
        return 0
    end
end

---@param tab table
---@param val any
-- returns Bool,
function timetableHelper.hasValue(tab, val)
    for _, v in pairs(tab) do
        if v == val then
            return true
        end
    end

    return false
end

---@param arr table
-- returns a, the maximum element of the array
function timetableHelper.maximumArray(arr)
    local max = arr[1]
    for k,_ in pairs(arr) do
        if max < arr[k] then
            max = arr[k]
        end
    end
    return max
end



return timetableHelper
