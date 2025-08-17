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


return gameApiUtils