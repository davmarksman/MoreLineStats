local vehiclesHelper = require "vehiclesHelper"
local luaUtils = require "luaUtils"

local journeyHelper = {}


--- Distance between two points
function journeyHelper.distance(x1, y1, z1, x2, y2, z2 )
  local dx = x1 - x2
  local dy = y1 - y2
  local dz = z1 - z2
  return math.sqrt ( dx * dx + dy * dy + dz*dz )
end

---@param lineId number | string
-- returns leg Times for line
function journeyHelper.getLegTimes(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return {} end

    local vehiclesForLine = vehiclesHelper.getVehicles(lineId)
    local noOfVeh = #vehiclesForLine
    local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
    local noOfStops = #lineComp.stops

    -- Create a matrix[leg][vehicleLegTime]. 
    -- Legs are the first index. We then store the value for the vehicle legtimes for that leg in the second index
    local legTimes = luaUtils.createOneBasedArrayOfArrays(noOfStops, noOfVeh, 0)

    for vehIdx, vehicleId in pairs(vehiclesForLine) do
        local sectionTimes = vehiclesHelper.getSectionTimesFromVeh(vehicleId)
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

    local toReturn = luaUtils.createOneBasedArray(noOfStops, 0)
    for i=1, #legTimes do
        toReturn[i] = luaUtils.avgNonZeroValuesInArray(legTimes[i])
    end

    return toReturn
end

return  journeyHelper