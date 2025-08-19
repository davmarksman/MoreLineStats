local luaUtils = require "luaUtils"

local gameApiUtils = {}
-------------------------------------------------------------
--- General Game Api methods that don't fit anywhere else ---
-------------------------------------------------------------

--- Current GameTime in seconds
---@return integer --Current GameTime in seconds
function gameApiUtils.getTime()
    local gameTimeComp = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
    local time = gameTimeComp.gameTime
    return luaUtils.getTimeInSecs(time)
end


--- Gets the name of an entity
---@param entityId number | string : the id of the entity
---@return string : entityName
function gameApiUtils.getEntityName(entityId)
    if type(entityId) == "string" then entityId = tonumber(entityId) end
    if not(type(entityId) == "number") then return "ERROR" end

    local exists = api.engine.entityExists(entityId)

    if exists then
        local entity = api.engine.getComponent(entityId, api.type.ComponentType.NAME)
        if entity and entity.name then
            return entity.name
        end
    end

    return "ERROR"
end

function gameApiUtils.entityExists(entityId)
    if type(entityId) == "string" then entityId = tonumber(entityId) end
    if not(type(entityId) == "number") then return nil end

    return api.engine.entityExists(entityId)
end


--- Gets the Line component (api.engine.getComponent(lineId, api.type.ComponentType.LINE)) safely
---@param lineId number | string : the id of the entity
---@return table|nil -- line component
function gameApiUtils.getLineComponent(lineId)
    if type(lineId) == "string" then lineId = tonumber(lineId) end
    if not(type(lineId) == "number") then return nil end

    local exists = api.engine.entityExists(lineId)

    if exists then
        local lineComp = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
        if lineComp then
            return lineComp
        end
    end

    return nil
end

--- Gets the Vehicle component (api.engine.getComponent(lineId, api.type.ComponentType.TRANSPORT_VEHICLE)) safely
---@param vehicleId number | string : the id of the entity
---@return table| nil -- Vehicle component
function gameApiUtils.getVehicleComponent(vehicleId)
    if type(vehicleId) == "string" then vehicleId = tonumber(vehicleId) end
    if not(type(vehicleId) == "number") then return nil end

    local exists = api.engine.entityExists(vehicleId)

    if exists then
        local vehComp = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
        if vehComp and vehComp.config then
            return vehComp
        end
    end

    return nil
end


return gameApiUtils