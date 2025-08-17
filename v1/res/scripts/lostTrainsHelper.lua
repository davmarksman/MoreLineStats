local lineStatsHelper = require "lineStatsHelper"

local lostTrainsHelper = {}

function lostTrainsHelper.resetAllTrains()
  local vehicles = lineStatsHelper.getAllVehiclesEnRoute()
  for i, vehicleId in pairs(vehicles) do
    lostTrainsHelper.restTrain(vehicleId)
  end
end


function lostTrainsHelper.resetLostTrains()
  local lostVehicles = lineStatsHelper.findLostTrains();

  for vehicleId , timeSinceDep in pairs(lostVehicles) do
    lostTrainsHelper.restTrain(vehicleId)
  end
end

---@param vehicleId number | string
-- returns Formated time string
function lostTrainsHelper.restTrain(vehicleId)
  api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId), function(res, success)
    if success then
      api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId))
    end
  end)
end

function lostTrainsHelper.resetVisibleTrains()
  local camera = game.gui.getCamera()
  local coord = {camera[1],camera[2]}
  local rad = camera[3]

  local vehicles = game.interface.getEntities({pos=coord, radius = rad}, {type="VEHICLE"})
  local trains = lineStatsHelper.getTrains(vehicles)

  for vehicleId, vehicle in pairs(trains) do
    lostTrainsHelper.restTrain(vehicleId)
  end
end


return lostTrainsHelper