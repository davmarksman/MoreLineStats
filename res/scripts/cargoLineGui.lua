local lineStatsHelper = require "lineStatsHelper"
local vehiclesHelper = require "vehiclesHelper"
local uiUtil = require "uiUtil"
local luaUtils = require "luaUtils"
local gameApiUtils = require "gameApiUtils"
local lostTrainsHelper = require "lostTrainsHelper"

local cargoLineGui = {}
local vehicle2cargoMapCache = {}

local lineWindows = {}
local stationTables = {}
local lineVehTables = {}
local lineImgsForLine = {}

function cargoLineGui.createGui(lineId)
    local start_time = os.clock()

    local lineIdStr =  tostring(lineId)
    print("Cargo Line " .. lineIdStr)
    local cargoLineGuiId = "lineInfo.cargolineUi.floatingLayout." .. lineIdStr

    if gameApiUtils.entityExists(lineId) then
        if lineWindows[lineId] then
            -- Cache the list of vehicles for use later
            vehicle2cargoMapCache = api.engine.system.simEntityAtVehicleSystem.getVehicle2Cargo2SimEntitesMap()

            cargoLineGui.fillStationTable(lineId, stationTables[lineId])
            lineVehTables[lineId]:deleteAll()
            lineWindows[lineId]:setVisible(true, true)

            return
        end

        local lineFloatLayout = api.gui.layout.FloatingLayout.new(0,1)
        lineFloatLayout:setId(cargoLineGuiId)
        lineFloatLayout:setGravity(-1,-1)

        local stationTable = cargoLineGui.createStationsTable()
        local stationScrollArea = cargoLineGui.createStationsArea(lineIdStr, stationTable)
        lineFloatLayout:addItem(stationScrollArea,0,0)

        local lineVehTable = api.gui.comp.Table.new(1, 'SINGLE')
        local scrollAreaVeh = cargoLineGui.createVehArea(lineIdStr, lineVehTable)
        lineFloatLayout:addItem(scrollAreaVeh,1,0)


        local refreshDataBtn = uiUtil.createButton("Reload Data")
        refreshDataBtn:onClick(function ()
            cargoLineGui.createGui(lineId)
        end)

        local resetTrainsButton = uiUtil.createButton("Reset Trains")
        resetTrainsButton:onClick(function ()
            lostTrainsHelper.resetAllTrainsOnLine(lineId)
        end)
        local compActions = uiUtil.makeHorizontal(refreshDataBtn, resetTrainsButton)
        lineFloatLayout:addItem(compActions, 0,1)

        -- Station/leg details (Right Column)
        stationTable:onSelect(function (tableIndex)
            if not (tableIndex == -1) then
                local success, res = pcall(function()
                    if gameApiUtils.entityExists(lineId) then
                        cargoLineGui.fillVehTableForSection(tableIndex, lineId, lineVehTables[lineId])
                    else
                        print("Entity does not exist anymore: " .. tostring(lineId))
                    end
                end)

                if not success then
                    print("stationTable:onSelect - ERROR: " .. tostring(res))
                end
            end
        end)

        cargoLineGui.fillStationTable(lineId, stationTable)

        -- Cache the list of vehicles for use later
        vehicle2cargoMapCache = api.engine.system.simEntityAtVehicleSystem.getVehicle2Cargo2SimEntitesMap()

        local lineName = gameApiUtils.getEntityName(lineId)
        local lineWindow =  uiUtil.createWindow("Line Details: " .. lineName, lineFloatLayout, 890, 650, false)
        lineWindow:setId("lineInfo.cargoLineUi.lineWindow."  .. lineIdStr)
        lineWindow:setPosition(200,400)

        lineWindows[lineId] = lineWindow
        stationTables[lineId] = stationTable
        lineVehTables[lineId] = lineVehTable

        print(string.format("cargoLineGui.createGui. Elapsed time: %.4f", os.clock() - start_time))
    else
        print("Line does not exist anymore")
    end
end

function cargoLineGui.createStationsTable()
    local stationTable = api.gui.comp.Table.new(6, 'SINGLE')
    stationTable:setColWidth(0,40)
    stationTable:setColWidth(1,260)
    stationTable:setColWidth(2,80)
    stationTable:setColWidth(3,80)
    stationTable:setColWidth(4,80)
    stationTable:setColWidth(5,50)
    return stationTable
end

function cargoLineGui.createStationsArea(lineIdStr, stationTable)
    local stationScrollArea = api.gui.comp.ScrollArea.new(stationTable, "lineInfo.cargoLineUi.stationScrollArea".. lineIdStr)
    stationScrollArea:setMinimumSize(api.gui.util.Size.new(600, 580))
    stationScrollArea:setMaximumSize(api.gui.util.Size.new(600, 580))
    return stationScrollArea
end

local rightWidth = 280
--- Sets up UI Elements for the Right table
function cargoLineGui.createVehArea(lineIdStr, lineVehTable)
    local scrollAreaVeh = api.gui.comp.ScrollArea.new(lineVehTable, "lineInfo.cargoLineUi.scrollAreaVeh" .. lineIdStr)
    scrollAreaVeh:setMinimumSize(api.gui.util.Size.new(rightWidth, 170))
    scrollAreaVeh:setMaximumSize(api.gui.util.Size.new(rightWidth, 170))
    return scrollAreaVeh
end


function cargoLineGui.fillStationTable(lineId, stationTable)
    -- Clear the table
    stationTable:deleteAll()

    -- Data
    local lineStats = lineStatsHelper.getCargoStatsForLine(lineId, {})
    if not lineStats then
        local header1 = api.gui.comp.TextView.new("ERROR")
        local header2 = api.gui.comp.TextView.new("")
        local header3 = api.gui.comp.TextView.new("")
        local header4 = api.gui.comp.TextView.new("")
        local header5 = api.gui.comp.TextView.new("")
        local header6 = api.gui.comp.TextView.new("")
        stationTable:setHeader({header1,header2, header3, header4, header5, header6})
        return
    end

    local lineStatsTxt = "Freq: " .. lineStats.lineFreqStr .. " | Demand: " .. lineStats.lineDemand .. " | Cargo: " .. lineStats.inVehCount .. "/" .. lineStats.lineCapacity

    local header1 = api.gui.comp.TextView.new(lineStatsTxt)
    local header2 = api.gui.comp.TextView.new("")
    -- local header3 = api.gui.comp.TextView.new("<->")
    local header3 = api.gui.comp.TextView.new(string.format("%.1f km", lineStats.totalDistanceKm))
    local header4 = api.gui.comp.TextView.new("Wait: " .. lineStats.waitingCount)
    local header5 = api.gui.comp.TextView.new("Journey")
    local header6 = api.gui.comp.TextView.new("")
    stationTable:setHeader({header1,header2, header3, header4, header5, header6})

    --iterate over all stations to display them
    local lineImage = {}
    local vehicleType = string.lower(lineStats.vehicleTypeStr)

    for stnIdx, stationInfo in pairs(lineStats.stationInfos) do

        -- Vehicles on Line image(s)
        local imageFile = uiUtil.getVehiclesOnSectionImageFile(lineStats.vehiclePositions, stnIdx, vehicleType)
        lineImage[stnIdx] = api.gui.comp.ImageView.new(imageFile)

        -- Station Idx No
        local lblStationNumber = api.gui.comp.TextView.new(tostring(stnIdx))
        lblStationNumber:setMinimumSize(api.gui.util.Size.new(30, 30))

        -- Station Col
        local lblStartStn = uiUtil.makeLocateText(stationInfo.station.id, luaUtils.shortenName(stationInfo.station.name, 33))
        local lblEndStn = uiUtil.makeLocateText(stationInfo.nextStation.id, "> " .. luaUtils.shortenName(stationInfo.nextStation.name, 30))
        local compStationNames =  uiUtil.makeVertical(lblStartStn, lblEndStn)
 
        -- Distance column
        local lblDistance = api.gui.comp.TextView.new(string.format("%.1f km", stationInfo.distanceKm))
        local lblSpeed = api.gui.comp.TextView.new(stationInfo.avgSpeedStr)
        lblDistance:setTooltip("Distance between the stations (as the crow flies)")
        lblSpeed:setTooltip("Average speed between the stations (as the crow flies)")
        local compDist = uiUtil.makeVertical(lblSpeed,lblDistance)

        -- Cargo Waiting col 
        -- local compTotalWaiting = uiUtil.makeIconText(tostring(lineStats.cargoAtStop[stnIdx]), "ui/hud/cargo_goods.tga")
        local compTotalWaiting = api.gui.comp.TextView.new(tostring(lineStats.cargoAtStop[stnIdx]))
        compTotalWaiting:setTooltip(_("Cargo"))

        local compLongWait
        if lineStats.cargoAtStopLongWait[stnIdx] > 0 then
            compLongWait = uiUtil.makeIconText(tostring(lineStats.cargoAtStopLongWait[stnIdx]), "ui/clock_small@2x.tga")
            if lineStats.lineFreq > 60 then
                compLongWait:setTooltip("Cargo waiting longer than " .. lineStats.lineFreqStr)
            else
                compLongWait:setTooltip("Cargo waiting longer than 5 minutes")    
            end
        else
            compLongWait = api.gui.comp.TextView.new("")
        end
        local compPplWaiting =  uiUtil.makeVertical(compTotalWaiting, compLongWait)

        -- Journey column
        local lblJurneyTime
        if lineStats.stationLegTimes[stnIdx] then
            lblJurneyTime = api.gui.comp.TextView.new(luaUtils.getTimeStr(lineStats.stationLegTimes[stnIdx]))
            lblJurneyTime:setTooltip("Time taken between stations.\n This is an average of completed vehicle journeys between these 2 stations and is used by the game in passenger routing calculations.")
        else
            lblJurneyTime = api.gui.comp.TextView.new("")
        end
        local compJourneyPpl
        if lineStats.legDemand[stnIdx] then
            compJourneyPpl = uiUtil.makeIconText(tostring(lineStats.legDemand[stnIdx]), "ui/cargo_dest.tga")
            compJourneyPpl:setTooltip("Cargo travelling between the stations on this line. Similar to the Cargo Layer")
        else
            compJourneyPpl = api.gui.comp.TextView.new("")
        end
        local compJurney = uiUtil.makeVertical(lblJurneyTime,compJourneyPpl)

        stationTable:addRow({lblStationNumber, compStationNames, compDist, compPplWaiting, compJurney, lineImage[stnIdx]})
    end

    lineImgsForLine[lineId] = lineImage
    local count = 0
    -- Call back to update the line vehicles image
    -- onStep is the update callback that is called in every step. (see: https://www.transportfever2.com/wiki/doku.php?id=modding:userinterface)
    stationTable:onStep(function()
        -- This gets executed too frequently. This reduces it to roughly once every 3 seconds. Varies based on frame rate
        count = count + 1
        if count % 100 == 0 then
            if not lineImgsForLine[lineId] then print("ERRROR") return end


            local vehiclePositionsUpdate = lineStatsHelper.getAggregatedVehLocs(lineId)
            if not vehiclePositionsUpdate then
                return
            end

            for stnIdx, img in pairs(lineImgsForLine[lineId]) do
                if not img then print("ERRROR") return end

                local imageFile2 = uiUtil.getVehiclesOnSectionImageFile(vehiclePositionsUpdate, stnIdx, vehicleType)
                img:setImage(imageFile2, false)
            end
        end
    end)
end


--- Displays all vehicles on the section in a table
function cargoLineGui.fillVehTableForSection(index, lineId, lineVehTable)
    -- index is 0 based. Stop indexes are 1 based
    lineVehTable:deleteAll()
    local lineStopIdx = index+1

    local headerRow = api.gui.comp.TextView.new("              Vehicles On Section")
    lineVehTable:addRow({headerRow})

    local vehiclesForSection = lineStatsHelper.getVehiclesForSection(lineId, lineStopIdx)
    for _, vehicleId in pairs(vehiclesForSection) do
        local vehicleName = luaUtils.shortenName(vehiclesHelper.getVehicleName(vehicleId), 25)
        local vehiclePassengers = vehiclesHelper.getVehicleCargoCountStr(vehicleId, vehicle2cargoMapCache)

        local vehicleLocateRow = uiUtil.makeLocateText(vehicleId, vehicleName .. " (" .. vehiclePassengers .. ")")
        lineVehTable:addRow({vehicleLocateRow})
    end
end

function cargoLineGui.createCargoLineButton(lineId, btnName)
    local lineBtn = uiUtil.createButton(btnName)
    local function openLine()
        cargoLineGui.createGui(lineId)
    end

    lineBtn:onClick(function ()
        local success, err = pcall(openLine)
        if err then
            print(err)
        end
    end)

    return lineBtn
end

return cargoLineGui