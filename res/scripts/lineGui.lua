local lineStatsHelper = require "lineStatsHelper"
local stationsHelper = require "stationsHelper"
local vehiclesHelper = require "vehiclesHelper"
local uiUtil = require "uiUtil"
local luaUtils = require "luaUtils"
local gameApiUtils = require "gameApiUtils"
local lostTrainsHelper = require "lostTrainsHelper"

local lineGui = {}
local vehicle2cargoMapCache = {}

local lineWindows = {}
local stationTables = {}
local lineVehTables = {}
local stnConxTables = {}
local detailsTables = {}
local lineImgsForLine = {}

function lineGui.createGui(lineId)
    local start_time = os.clock()

    local lineIdStr =  tostring(lineId)
    print("Line " .. lineIdStr)
    local lineGuiId = "lineInfo.lineUi.floatingLayout." .. lineIdStr

    if lineWindows[lineId] then
        print("already created")
        -- Cache the list of vehicles for use later
        vehicle2cargoMapCache = api.engine.system.simEntityAtVehicleSystem.getVehicle2Cargo2SimEntitesMap()

        lineWindows[lineId]:setVisible(true, true)
        lineGui.fillStationTable(lineId, stationTables[lineId])
        detailsTables[lineId]:deleteAll()
        lineVehTables[lineId]:deleteAll()
        stnConxTables[lineId]:deleteAll()
        
        print(string.format("lineGui.createGui (reopen). Elapsed time: %.4f\n", os.clock() - start_time))

        -- this didn't work
        -- local oldLineWindow = api.gui.util.downcast(api.gui.util.getById(lineGuiId))
        -- print(oldLineWindow)
        -- oldLineWindow:setVisible(true, true)
        return
    end

    local lineFloatLayout = api.gui.layout.FloatingLayout.new(0,1)
    lineFloatLayout:setId(lineGuiId)
    lineFloatLayout:setGravity(-1,-1)

    local stationTable = lineGui.createStationsTable()
    local stationScrollArea = lineGui.createStationsArea(lineIdStr, stationTable)
    lineFloatLayout:addItem(stationScrollArea,0,0)

    local lineVehTable = api.gui.comp.Table.new(1, 'SINGLE')
    local scrollAreaVeh = lineGui.createVehArea(lineIdStr, lineVehTable)
    lineFloatLayout:addItem(scrollAreaVeh,1,0)

    local detailsTable = lineGui.createDetailsTable()
    local scrollAreaDetails = lineGui.createDetailsArea(lineIdStr, detailsTable)
    lineFloatLayout:addItem(scrollAreaDetails,1,0.5)

    local stnConxTable = api.gui.comp.Table.new(1, 'SINGLE')
    local scrollAreaConx = lineGui.createConnectionsArea(lineIdStr, stnConxTable)
    lineFloatLayout:addItem(scrollAreaConx,1,1)


    local refreshDataBtn = uiUtil.createButton("Refresh Data")
	refreshDataBtn:onClick(function ()
        lineGui.createGui(lineId)
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
            print(tostring(tableIndex))
            lineGui.fillDetailsTable(tableIndex, lineId, detailsTables[lineId])
            lineGui.fillConxTable(tableIndex, lineId, stnConxTables[lineId])
            lineGui.fillVehTableForSection(tableIndex, lineId, lineVehTables[lineId])
        end
    end)

    lineGui.fillStationTable(lineId, stationTable)

    -- Cache the list of vehicles for use later
    vehicle2cargoMapCache = api.engine.system.simEntityAtVehicleSystem.getVehicle2Cargo2SimEntitesMap()

    print("create window ")
    local lineName = gameApiUtils.getEntityName(lineId)
    local lineWindow =  uiUtil.createWindow("Line Details: " .. lineName, lineFloatLayout, 965, 650, false)
    lineWindow:setId("lineInfo.lineUi.lineWindow."  .. lineIdStr)
    lineWindow:setPosition(200,400)

    lineWindows[lineId] = lineWindow
    stationTables[lineId] = stationTable
    lineVehTables[lineId] = lineVehTable
    stnConxTables[lineId] = stnConxTable
    detailsTables[lineId] = detailsTable

    print(string.format("lineGui.createGui. Elapsed time: %.4f\n", os.clock() - start_time))
end

function lineGui.createStationsTable()
    print("createStationsTable")
    local stationTable = api.gui.comp.Table.new(7, 'SINGLE')
    stationTable:setColWidth(0,40)
    stationTable:setColWidth(1,260)
    stationTable:setColWidth(2,80)
    stationTable:setColWidth(3,80)
    stationTable:setColWidth(4,80)
    stationTable:setColWidth(5,80)
    stationTable:setColWidth(6,50)
    return stationTable
end

function lineGui.createStationsArea(lineIdStr, stationTable)
    print("createStationsArea ")
    local stationScrollArea = api.gui.comp.ScrollArea.new(stationTable, "lineInfo.lineUi.stationScrollArea".. lineIdStr)
    stationScrollArea:setMinimumSize(api.gui.util.Size.new(670, 580))
    stationScrollArea:setMaximumSize(api.gui.util.Size.new(670, 580))
    return stationScrollArea
end

local rightWidth = 280
--- Sets up UI Elements for the Details Area (Right) table
function lineGui.createVehArea(lineIdStr, lineVehTable)
    local scrollAreaVeh = api.gui.comp.ScrollArea.new(lineVehTable, "lineInfo.lineUi.scrollAreaVeh" .. lineIdStr)
    scrollAreaVeh:setMinimumSize(api.gui.util.Size.new(rightWidth, 170))
    scrollAreaVeh:setMaximumSize(api.gui.util.Size.new(rightWidth, 170))
    return scrollAreaVeh
end

function lineGui.createConnectionsArea(lineIdStr, stnConnectTable)
    local scrollAreaConx = api.gui.comp.ScrollArea.new(stnConnectTable, "lineInfo.lineUi.scrollAreaConx" .. lineIdStr)
    scrollAreaConx:setMinimumSize(api.gui.util.Size.new(rightWidth, 170))
    scrollAreaConx:setMaximumSize(api.gui.util.Size.new(rightWidth, 170))
    return scrollAreaConx
end

function lineGui.createDetailsTable()
    local detailsTable = api.gui.comp.Table.new(2, 'SINGLE')
    detailsTable:setColWidth(0,60)
    return detailsTable
end

function lineGui.createDetailsArea(lineIdStr, detailsTable)
    local scrollAreaDetails = api.gui.comp.ScrollArea.new(detailsTable, "lineInfo.lineUi.scrollAreaDetails".. lineIdStr)
    scrollAreaDetails:setMinimumSize(api.gui.util.Size.new(rightWidth, 270))
    scrollAreaDetails:setMaximumSize(api.gui.util.Size.new(rightWidth, 270))
    return scrollAreaDetails
end

function lineGui.fillStationTable(lineId, stationTable)
    -- Clear the table
    stationTable:deleteAll()

    -- Data
    local lineStats = lineStatsHelper.getPassengerStatsForLine(lineId)
    if not lineStats then
        local header1 = api.gui.comp.TextView.new("ERROR")
        local header2 = api.gui.comp.TextView.new("")
        local header3 = api.gui.comp.TextView.new("")
        local header4 = api.gui.comp.TextView.new("")
        local header5 = api.gui.comp.TextView.new("")
        local header6 = api.gui.comp.TextView.new("")
        local header7 = api.gui.comp.TextView.new("")
        stationTable:setHeader({header1,header2, header3, header4, header5, header6, header7})
        return
    end

    local lineStatsTxt = "Freq: " .. lineStats.lineFreqStr .. " | Demand: " .. lineStats.totalCount .. " | Cap: " .. lineStats.inVehCount .. "/" .. lineStats.lineCapacity

    local header1 = api.gui.comp.TextView.new(lineStatsTxt)
    local header2 = api.gui.comp.TextView.new("")
    local header3 = api.gui.comp.TextView.new("Avg Wait")
    local header4 = api.gui.comp.TextView.new("Wait: " .. lineStats.waitingCount)
    local header5 = api.gui.comp.TextView.new("Journey")
    local header6 = api.gui.comp.TextView.new("Distance")-- to swap
    local header7 = api.gui.comp.TextView.new("")
    stationTable:setHeader({header1,header2, header6, header3,header4, header5, header7})

    --iterate over all stations to display them
    local lineImage = {}
    local vehicleType = string.lower(lineStats.vehicleTypeStr)

    print("station loop ")
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

        -- Wait time col
        local lblAvgWaitTime = api.gui.comp.TextView.new(luaUtils.getTimeStr(lineStats.stopAvgWaitTimes[stnIdx]))

        -- Passenger Waiting col 
        local compTotalWaiting = uiUtil.makeIconText(tostring(lineStats.peopleAtStop[stnIdx]), "ui/hud/cargo_passengers.tga")

        local compLongWait
        if lineStats.peopleAtStopLongWait[stnIdx] > 0 then
            compLongWait = uiUtil.makeIconText(tostring(lineStats.peopleAtStopLongWait[stnIdx]), "ui/clock_small@2x.tga")
        else
            compLongWait = api.gui.comp.TextView.new("")
        end
        local compPplWaiting =  uiUtil.makeVertical(compTotalWaiting, compLongWait)

        -- Journey column
        local lblJurneyTime
        if lineStats.stationLegTimes[stnIdx] then
            lblJurneyTime = api.gui.comp.TextView.new(luaUtils.getTimeStr(lineStats.stationLegTimes[stnIdx]))
        else
            lblJurneyTime = api.gui.comp.TextView.new("")
        end
        local compJourneyPpl
        if lineStats.legDemand[stnIdx] then
            compJourneyPpl = uiUtil.makeIconText(tostring(lineStats.legDemand[stnIdx]), "ui/passengers_dest.tga")
        else
            compJourneyPpl = api.gui.comp.TextView.new("")
        end
        local compJurney = uiUtil.makeVertical(lblJurneyTime,compJourneyPpl)

        -- Distance column
        local lblDistance = api.gui.comp.TextView.new(string.format("%.1f km", stationInfo.distanceKm))
        local lblSpeed = api.gui.comp.TextView.new(stationInfo.avgSpeedStr)
        local compDist = uiUtil.makeVertical(lblDistance,lblSpeed)

        stationTable:addRow({lblStationNumber, compStationNames, compDist, lblAvgWaitTime, compPplWaiting, compJurney, lineImage[stnIdx]})
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

            print('lineImage update lineId ' .. tostring(lineId))

            local vehiclePositionsUpdate = lineStatsHelper.getAggregatedVehLocs(lineId)
            if not vehiclePositionsUpdate then
                print("ERROR - vehiclePositionsUpdate is nil")
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

--- Displays Competing lines
function lineGui.fillDetailsTable(index, lineId, detailsTable)
    -- index is 0 based. Stop indexes are 1 based
    detailsTable:deleteAll()

    local stopIdx = index+1
    local nextStopIdx = stationsHelper.getNextStop(lineId, stopIdx)
    if nextStopIdx == -1 then
        return
    end

    local lblEmpty = api.gui.comp.TextView.new("")
    local lblCompetingLInes = api.gui.comp.TextView.new("Competing Lines")
    detailsTable:addRow({lblEmpty, lblCompetingLInes})

    local timesToStations = stationsHelper.getLineTimesFromStation(lineId, stopIdx)

    -- To Station
    for _, timeToStn in pairs(timesToStations) do
        local station = stationsHelper.getStationNameWithId(timeToStn.toStationId)
        local lblHeadFrom = api.gui.comp.TextView.new("To")
        local shortenedStnName = luaUtils.shortenToPixels(station.name, rightWidth-60-40)
        local lblHeadStnName = uiUtil.makeLocateText(station.id, shortenedStnName)

        -- Lines competing to that station
        detailsTable:addRow({lblHeadFrom, lblHeadStnName})
        for _, competingLines in pairs(timeToStn.sortedTimes) do
            local competingLineId = competingLines.key

            local time = competingLines.value
            local lineName = gameApiUtils.getEntityName(competingLineId)
            local timeStr = luaUtils.getTimeStr(time)

            local lblJurneyTime = api.gui.comp.TextView.new(timeStr)
            local shortenedLineName = luaUtils.shortenToPixels(lineName, rightWidth-60)

            local lineComp
            if competingLineId == lineId then
                lineComp = api.gui.comp.TextView.new(shortenedLineName)
            else
                lineComp = lineGui.createLineButton(competingLineId, shortenedLineName)
            end

            detailsTable:addRow({lblJurneyTime, lineComp})
        end
        -- Blank row
        detailsTable:addRow({api.gui.comp.TextView.new(""), api.gui.comp.TextView.new("")})
    end
end

--- Displays all line connections at that station
function lineGui.fillConxTable(index, lineId, conxTable)
    conxTable:deleteAll()
    local lineStopIdx = index+1

    local connectingLinesHeaderRow = api.gui.comp.TextView.new("              <-> Connections")
    conxTable:addRow({connectingLinesHeaderRow})
    local stationId = stationsHelper.GetStationGroupIdForStop(lineId, lineStopIdx)
    local stationLines = stationsHelper.GetLinesThatStopAtStation(stationId)

    for lineThroughStnLineId, lineThroughStnLineName in pairs(stationLines) do
        if lineThroughStnLineId ~= lineId  then
            local shortenedLineName = luaUtils.shortenToPixels(lineThroughStnLineName, rightWidth-10)
            local lineBtn = lineGui.createLineButton(lineThroughStnLineId, shortenedLineName)
            conxTable:addRow({lineBtn})
        end
    end
end

--- Displays all vehicles on the section in a table
function lineGui.fillVehTableForSection(index, lineId, lineVehTable)
    -- index is 0 based. Stop indexes are 1 based
    lineVehTable:deleteAll()
    local lineStopIdx = index+1

    local headerRow = api.gui.comp.TextView.new("              Vehicles On Section")
    lineVehTable:addRow({headerRow})

    local vehiclesForSection = lineStatsHelper.getVehiclesForSection(lineId, lineStopIdx)
    for _, vehicleId in pairs(vehiclesForSection) do
        local vehicleName = luaUtils.shortenName(vehiclesHelper.getVehicleName(vehicleId), 25)
        local vehiclePassengers = vehiclesHelper.getVehiclePassengerCountStr(vehicleId, vehicle2cargoMapCache)

        local vehicleLocateRow = uiUtil.makeLocateText(vehicleId, vehicleName .. " (" .. vehiclePassengers .. ")")
        lineVehTable:addRow({vehicleLocateRow})
    end
end

function lineGui.createLineButton(lineId, lineName)
    local lineBtn = uiUtil.createButton(lineName)
    local function openLine()
        lineGui.createGui(lineId)
    end

    lineBtn:onClick(function ()
        local success, err = pcall(openLine)
        if err then
            print(err)
        end
    end)

    return lineBtn
end

return lineGui