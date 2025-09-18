local gameApiUtils = require "gameApiUtils"
local lineStatsHelper = require "lineStatsHelper"
local stationsHelper = require "stationsHelper"
local luaUtils = require "luaUtils"

local passengerChoice = {}


-------------------------------------------------------------
---------------------- Issues:      -------------------------
--- 1. Not very performant: On map with 45k passengers: 0.02 - 0.2 seconds to record
--- 2. Some passengers have no arrival time (arrivalTime = 0). When the platform is full and they use the shared platform space.
--- Solutions:
--- store passengerIds seen as dict instead. Had worse performance (but was creating full objects then so maybe better now)
--- Give user button to pick stations to record stats on.
-------------------------------------------------------------

-- these are in game time
local pollInterval = 10 -- every 10 seconds
local cleanupInterval = 10 * 60 -- every 10 minutes
-- local cleanupAfter = 60 * 60 -- cleanup data older than 60 minutes
local cleanupAfter = 730 * 4 -- cleanup data older than 4 game years

local gameYearLen = 730


function passengerChoice.compute(stationId, state)
  print("Passenger Choice Compute for station " .. stationId)
  local res = {}


  for i = 0, 3, 1 do
    local bucketNo = math.floor(state.lastUpdated/gameYearLen) - i
    print("Bucket " .. bucketNo)
    if state.arrivalCounts[bucketNo] then
      local stationData = state.arrivalCounts[bucketNo][stationId]
      if stationData ~= nil then
        for lineId, lineStops in pairs(stationData) do
          for stopNo, stopCount in pairs(lineStops) do
            local key = lineId .. "_" .. stopNo
            if not res[key] then
              res[key] = {
                lineId = lineId,
                stopNo = stopNo,
                counts = {},
              }
            end
            local toUpdate = res[key]
            toUpdate.counts[i + 1] = stopCount
          end
        end
      end
    end
  end

  return res
end


function passengerChoice.record(state)
  local gameTime = gameApiUtils.getTime()
  if gameTime < state.lastUpdated + pollInterval then
    return
  end

  local bucket = math.floor(gameTime/gameYearLen)
  if state.lastUpdated == 0 then
    print("skip the first run")
    -- skip the first run
    state.lastUpdated = gameTime
    state.startDate[bucket] = "Start"
    return
  end

  -- Check if bucket change then store this as the start of bucket & delete old bucket
  local prevBucket = math.floor(state.lastUpdated/gameYearLen)
  if bucket ~= prevBucket then
    local date = game.interface.getGameTime().date
    state.startDate[bucket] = date.month .. "/" .. date.year
    -- Delete old data
    state.arrivalCounts[bucket -4] = nil
  end

  local lastRunTime = state.lastUpdated
  state.lastUpdated = gameTime

  local start_time = os.clock()
  local linesIds = lineStatsHelper.getAllPassengerLines()
  if state.arrivalCounts[bucket] == nil then
    state.arrivalCounts[bucket] = {}
  end
  bucket = state.arrivalCounts[bucket]

  for _, lineId in pairs(linesIds) do
    if lineStatsHelper.getLineTypeStr(lineId) == "RAIL" then
      local psgWaitingForLine = passengerChoice.getNewPassengersWaitingForLine(lineId, lastRunTime, state.lastUpdated)
      if psgWaitingForLine.found == true then
        local stationsList = stationsHelper.getAllStations(lineId)
        for stopNo, count in pairs(psgWaitingForLine.counts) do
          local stationId = stationsList[stopNo]
          if bucket[stationId] == nil then
            -- new station
            bucket[stationId] = {}
          end
          if bucket[stationId][lineId] == nil then
            -- new line
            bucket[stationId][lineId] = {}
          end
          if bucket[stationId][lineId][stopNo] == nil then
            -- new stop for line
            bucket[stationId][lineId][stopNo] = 0
          end

          bucket[stationId][lineId][stopNo] = bucket[stationId][lineId][stopNo] + count
        end
      end
    end
  end

  print("passengerChoice.record: " .. tostring(gameTime) .. string.format(". Elapsed time: %.4f", os.clock() - start_time))
end

-- local seenNoTime = {}

function passengerChoice.getNewPassengersWaitingForLine(lineId, lastRunTime, thisRunTime)

  if lineId == 625078 then
    print("getPassengersWaitingForLine" .. lineId)
  end

  local lineComp = gameApiUtils.getLineComponent(lineId)
  if not lineComp then
    -- print("passengerChoice.getNewPassengersWaitingForLine: Invalid lineId: " .. tostring(lineId))
    return {}
  end

  local noOfStops = #lineComp.stops
  local personsForLineArr = api.engine.system.simPersonSystem.getSimPersonsForLine(lineId)
  local res =  {}
  res.counts = luaUtils.createOneBasedArray(noOfStops, 0)
  res.found = false
  -- local count = 0

  for _, personId in pairs(personsForLineArr) do
    local simEntityAtTerminal = api.engine.getComponent(personId, api.type.ComponentType.SIM_ENTITY_AT_TERMINAL)

    -- Waiting at terminal
    if simEntityAtTerminal then
      -- count = count + 1

      local arrivalTime = luaUtils.getTimeInSecs(simEntityAtTerminal.arrivalTime)

      -- include last run time but exclude this run time (as all may not have arrived yet for this second)
      if simEntityAtTerminal.line == lineId and arrivalTime >= lastRunTime and arrivalTime < thisRunTime then
        local stopNo = simEntityAtTerminal.lineStop0 + 1
        res.counts[stopNo] = res.counts[stopNo] + 1
        res.found = true
     
        -- if lineId == 625078 then
        --   print("Process Person " .. personId .. " at terminal for line " .. simEntityAtTerminal.line .. " arrivalTime " .. arrivalTime .. " lastRunTime " .. lastRunTime)
        -- end
        -- seen[personId] = true
      -- elseif arrivalTime == 0 then
        -- print("Person " .. personId .. " at terminal for line " .. simEntityAtTerminal.line .. " has no arrival time: " .. simEntityAtTerminal.arrivalTime)
        -- local personNoTimeLineId = seenNoTime[personId]
        -- if personNoTimeLineId == nil then
        --   personNoTimeLineId[personId] = lineId
        --   if lineId == 625078 then
        --     print("Person " .. personId .. " at terminal for line " .. simEntityAtTerminal.line .. " has no arrival time")
        --   end

        --   local stopNo = simEntityAtTerminal.lineStop0 + 1
        --   res.counts[stopNo] = res.counts[stopNo] + 1
        --   res.found = true
        -- elseif personNoTimeLineId ~= lineId then
        --   -- changed line
        --   seenNoTime[personId] = lineId
        --   if lineId == 625078 then
        --     print("Person " .. personId .. " at terminal changed line from " .. personNoTimeLineId .. " to " .. lineId)
        --   end
          
        --   local stopNo = simEntityAtTerminal.lineStop0 + 1
        --   res.counts[stopNo] = res.counts[stopNo] + 1
        --   res.found = true
        -- end
      -- else
        -- if lineId == 625078 then
        --   print("Skipping person " .. personId .. " at terminal for line " .. simEntityAtTerminal.line .. " arrivalTime " .. arrivalTime .. " lastRunTime " .. lastRunTime)
        -- end
        -- if seen[personId] == nil then
        --   -- print("Oops " .. personId)
        -- end
      end
    end
  end

  -- if lineId == 625078 then
  --   print("count " .. count)
  -- end

  return res
end

return passengerChoice