local vehiclesHelper = require "vehiclesHelper"
local journeyHelper = require "journeyHelper"
local luaUtils = require "luaUtils"
local gameApiUtils = require "gameApiUtils"

local lostTrainsHelper = {}

--- returns table where index is vehicle id, and value is time since last depature
function lostTrainsHelper.findLostTrains()
    -- TODO: Also compare last 2 financial periods. If hasn't earned any money probably problem
    local gameTime = gameApiUtils.getTime()
    local vehicles = vehiclesHelper.getAllVehiclesEnRoute()
    local res = {}
    local linesLegTimesCache = {}

    local trains = vehiclesHelper.getTrains(vehicles)

    for vehicleId, vehicle in pairs(trains) do
        local lastDeparture = vehiclesHelper.getLastDepartureTimeFromVeh(vehicle)
        local timeSinceDep = gameTime - lastDeparture

        if lastDeparture > 0 and timeSinceDep >  60 * 4 then
            if not linesLegTimesCache[vehicle.line] then
                linesLegTimesCache[vehicle.line] = journeyHelper.getLegTimes(vehicle.line)
            end

            local lineLegTimes = linesLegTimesCache[vehicle.line]
            if lineLegTimes and lineLegTimes[1] then
                -- Use leg times to work out if vehicle is lost
                local maxLegTime = luaUtils.maximumArray(lineLegTimes)
                local avgLegTime = luaUtils.avgNonZeroValuesInArray(lineLegTimes)
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

function lostTrainsHelper.resetAllTrains()
  local vehicleIds = vehiclesHelper.getAllVehiclesEnRoute()
  lostTrainsHelper.resetTrains(vehicleIds)
end


---Resets all trains on a line
---@param lineId any
function lostTrainsHelper.resetAllTrainsOnLine(lineId)
  local vehicleIds = vehiclesHelper.getVehicles(lineId)
  lostTrainsHelper.resetTrains(vehicleIds)
end

---Resets all lost trains
function lostTrainsHelper.resetLostTrains()
  local lostVehicles = lostTrainsHelper.findLostTrains();

  for vehicleId, _ in pairs(lostVehicles) do
    local vehComp = gameApiUtils.getVehicleComponent(vehicleId)
    if vehComp and vehComp.state then
      lostTrainsHelper.restTrain(vehicleId, vehComp)
    end
  end
end

---Resets all visible trains
function lostTrainsHelper.resetVisibleTrains()
  local camera = game.gui.getCamera()
  local coord = {camera[1],camera[2]}
  local rad = camera[3]

  local vehicles = game.interface.getEntities({pos=coord, radius = rad}, {type="VEHICLE"})
  lostTrainsHelper.resetTrains(vehicles)
end

---Reset vehicles in array of vehicleIds that are trains
---@param vehicleIds  [string] | [number]
function lostTrainsHelper.resetTrains(vehicleIds)
  local trains = vehiclesHelper.getTrains(vehicleIds)

  for vehicleId, vehComp in pairs(trains) do
    lostTrainsHelper.restTrain(vehicleId, vehComp)
  end
end

---Resets a single vehicle
---@param vehicleId number | string
---@param vehComp table
function lostTrainsHelper.restTrain(vehicleId, vehComp)
  -- Only reset trains if not at terminal
  if vehComp.state ~= api.type.enum.TransportVehicleState.AT_TERMINAL then
    api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId), function(res, success)
      if success then
        api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId))
      end
    end)
  end
end



return lostTrainsHelper