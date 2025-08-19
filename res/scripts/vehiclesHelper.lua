local luaUtils = require "luaUtils"
local gameApiUtils = require "gameApiUtils"

local vehiclesHelper = {}
-------------------------------------------------------------
---------------------- Vehicle related ----------------------
-------------------------------------------------------------


--- @param vehicleIds [string] | [number]
--- @return table
--- returns table with key vehicle Id, and value vehicles (api.type.ComponentType.TRANSPORT_VEHICLE, not vehicle Id)
function vehiclesHelper.getTrains(vehicleIds)
    local matrix={}
    for _, vehicleId in pairs(vehicleIds) do
        local vehicle = gameApiUtils.getVehicleComponent(vehicleId)
        if vehicle and vehicle.carrier and vehicle.line then
            if vehicle.carrier == api.type.enum.JournalEntryCarrier.RAIL then
                matrix[vehicleId] = vehicle
            end
        end
    end
    return matrix
end

---@param vehicleId number | string
-- returns departure time of previous vehicle. 0 if no depature times
function vehiclesHelper.getLastDepartureTime(vehicleId)
    local lineVehicle = gameApiUtils.getVehicleComponent(vehicleId)
    return vehiclesHelper.getLastDepartureTimeFromVeh(lineVehicle)
end

---@param lineVehicle any -- https://transportfever2.com/wiki/api/modules/api.type.html#TransportVehicle 
-- returns departure time of previous vehicle. 0 if no depature times
function vehiclesHelper.getLastDepartureTimeFromVeh(lineVehicle)
    local lastDepartureTime = 0
    if lineVehicle and lineVehicle.lineStopDepartures then
        lastDepartureTime = luaUtils.maximumArray(lineVehicle.lineStopDepartures)
    end

    return luaUtils.getTimeInSecs(lastDepartureTime)
end

-- returns arr:[vehicleId:number]
function vehiclesHelper.getAllVehiclesEnRoute()
    return api.engine.system.transportVehicleSystem.getVehiclesWithState(api.type.enum.TransportVehicleState.EN_ROUTE)
end

---gets vehicle type as api.type.enum.Carrier. Defaults to 0 (ROAD) if not known
---@param vehicleId number | string
---@return number
function vehiclesHelper.getVehicleType(vehicleId)
    local lineVehicle = gameApiUtils.getVehicleComponent(vehicleId)
    if lineVehicle and lineVehicle.carrier then
        return lineVehicle.carrier
    end

    -- default to road if not known
    return 0
end

---@param vehicleId number | string
-- returns vehicle name
function vehiclesHelper.getVehicleName(vehicleId)
    return gameApiUtils.getEntityName(vehicleId)
end

---@param vehicleId number | string
-- returns vehicle name
function vehiclesHelper.getVehicleCapacity(vehicleId)
    local vehicle = gameApiUtils.getVehicleComponent(vehicleId)
    if not vehicle or not vehicle.config or not vehicle.config.capacities then
        return 0
    end

    local totalCapcity = 0
    for _, cap in pairs(vehicle.config.capacities) do
        totalCapcity = totalCapcity + cap
    end
    return totalCapcity

end

---@param vehicleId number | string
---@param vehicle2cargoMap table
-- returns string with vehicle passenger count / total
function vehiclesHelper.getVehiclePassengerCountStr(vehicleId, vehicle2cargoMap) 
    if type(vehicleId) == "string" then vehicleId = tonumber(vehicleId) end
    if not(type(vehicleId) == "number") then print("Expected String or Number") return false end

    local totalCapcity = vehiclesHelper.getVehicleCapacity(vehicleId)
    
    if not vehicle2cargoMap or #vehicle2cargoMap <= 0 then
        return "???/" .. totalCapcity
    end

    local vehCargo = vehicle2cargoMap[vehicleId]
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

---@param vehicleId number | string
-- returns returns line name of vehicel
function vehiclesHelper.getLineNameOfVehicle(vehicleId)
    local vehicle = gameApiUtils.getVehicleComponent(vehicleId)
    if vehicle and vehicle.line then
        return gameApiUtils.getEntityName(vehicle.line)
    else
        return "Unknown"
    end
end

---@param lineId number | string
-- returns [vehicleId] arr - vehicles for line 
function vehiclesHelper.getVehicles(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
    return vehiclesForLine
end

---Get's section times from a vehicle
---@param vehicleId number | string
---@return table| nil
function vehiclesHelper.getSectionTimesFromVeh(vehicleId)
    local vehicleObject = gameApiUtils.getVehicleComponent(vehicleId)
    if vehicleObject and vehicleObject.sectionTimes then
        return vehicleObject.sectionTimes
    else
        return nil
    end
end

return vehiclesHelper