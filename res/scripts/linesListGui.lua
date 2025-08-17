local lineStatsHelper = require "lineStatsHelper"
local lostTrainsHelper = require "lostTrainsHelper"
local vehiclesHelper = require "vehiclesHelper"
local uiUtil = require "uiUtil"
local lineGui = require "lineGui"
local luaUtils = require "luaUtils"

local linesListGui = {}
local uiElems = {
    window = nil,
    floatLayoutLines = nil,
    scrollAreaLines = nil,
    lineTable = nil,
    lineTableItems = nil,
    tabWidget = nil,
    floatLayoutLost = nil,
    scrollAreaLostTrains = nil,
    lostTrainsTable = nil,
    toggleBtns = nil,
    lineFilter = nil,
}
local uiState = {
    lastSelectedFilter = "ALL", -- Default filter
    allLinesCache = {}, -- Cache for all lines
}

function linesListGui.showLineList()
    linesListGui.showOrCreateUi()
    linesListGui.fillLostLines()
    linesListGui.fillLineTable()
end

function linesListGui.showOrCreateUi()
    print("-- showLineList --")
    if uiElems.window ~= nil then
        print("-- init window --")
        uiElems.window:setVisible(true, true)
        uiElems.window:setPinned(true)
        linesListGui.filterToLinesOfType(uiState.lastSelectedFilter, uiElems.toggleBtns)
        return
    end

    print("-- Create Tabs --")
    uiElems.floatLayoutLines = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutLines")
    print("-- Create createLineFilter --")
    linesListGui.createLineFilter()
    print("-- Create createLineTable --")
    linesListGui.createLineTable()

    uiElems.floatLayoutLost = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutlostTrains")
    linesListGui.createLostTrainsTable()

    print("-- Create Window --")
    -- Setting up Tabs
    uiElems.tabWidget = api.gui.comp.TabWidget.new("NORTH")
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLines, "Lines")
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLost, "Lost Trains")

    -- create final window
    uiElems.window = uiUtil.createWindow("Passenger Line Statistics", uiElems.tabWidget, 1000, 680, true)
end


function linesListGui.createLineTable()
    uiElems.lineTable = api.gui.comp.Table.new(10, 'SINGLE')
    uiElems.lineTable:setColWidth(0,260)
    uiElems.lineTable:setColWidth(1,80)
    uiElems.lineTable:setColWidth(2,100)
    uiElems.lineTable:setColWidth(3,80)
    uiElems.lineTable:setColWidth(4,80)
    uiElems.lineTable:setColWidth(5,100)
    uiElems.lineTable:setColWidth(6,80)
    uiElems.lineTable:setColWidth(7,80)
    uiElems.lineTable:setColWidth(8,80)
    uiElems.lineTable:setColWidth(9,80)

    uiElems.scrollAreaLines = uiUtil.createScrollArea(uiElems.lineTable, 1000, 550, "lineInfo.mainUi.scrollAreaLines")

    print("-- add uiElems.scrollAreaLines --")
    uiElems.floatLayoutLines:addItem(uiElems.scrollAreaLines,0,1)
end

function linesListGui.createLostTrainsTable()
    uiElems.lostTrainsTable = api.gui.comp.Table.new(3, 'SINGLE')
    uiElems.lostTrainsTable:setColWidth(0,340)
    uiElems.lostTrainsTable:setColWidth(1,340)
    uiElems.lostTrainsTable:setColWidth(2,200)

    uiElems.scrollAreaLostTrains = uiUtil.createScrollArea(uiElems.lostTrainsTable, 900, 550, "lineInfo.mainUi.scrollAreaLostTrains")

    local resetLostTrainsButton = uiUtil.createButton("Reset Lost Trains")
	resetLostTrainsButton:onClick(lostTrainsHelper.resetLostTrains)

    uiElems.floatLayoutLost:addItem(uiElems.scrollAreaLostTrains,0,1)
    uiElems.floatLayoutLost:addItem(resetLostTrainsButton,0,0)
end

function linesListGui.createLineFilter()
    uiElems.lineFilter = api.gui.comp.Table.new(6, 'None')
    local toggleBtns = {}
    toggleBtns["ALL"] = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new("All"))
    toggleBtns["ROAD"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_road_vehicles.tga"))
    toggleBtns["TRAM"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/tram/TimetableTramIcon.tga"))
    toggleBtns["RAIL"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_trains.tga"))
    toggleBtns["WATER"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_ships.tga"))
    toggleBtns["AIR"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_planes.tga"))
    uiElems.lineFilter:addRow({ toggleBtns["ALL"], toggleBtns["ROAD"], toggleBtns["TRAM"], toggleBtns["RAIL"], toggleBtns["WATER"], toggleBtns["AIR"] })

    print("-- Filter Functions --")
    -- Filter Functions
    toggleBtns["ALL"]:onToggle(function()
        linesListGui.filterToLinesOfType("ALL", toggleBtns)
    end)

    toggleBtns["ROAD"]:onToggle(function()
        linesListGui.filterToLinesOfType("ROAD", toggleBtns)
    end)

    toggleBtns["TRAM"]:onToggle(function()
        linesListGui.filterToLinesOfType("TRAM", toggleBtns)
    end)

    toggleBtns["RAIL"]:onToggle(function()
        linesListGui.filterToLinesOfType("RAIL", toggleBtns)
    end)

    toggleBtns["WATER"]:onToggle(function()
        linesListGui.filterToLinesOfType("WATER", toggleBtns)
    end)

    toggleBtns["AIR"]:onToggle(function()
        linesListGui.filterToLinesOfType("AIR", toggleBtns)
    end)

    uiElems.toggleBtns = toggleBtns
    uiElems.floatLayoutLines:addItem(uiElems.lineFilter,0,0)
end

---This filters the list of lines based on the line type
---@param typeOfLine string
function linesListGui.filterToLinesOfType(typeOfLine, toggleButtons)
    uiState.lastSelectedFilter = typeOfLine

    if typeOfLine == "ALL" then
        for _, elemsForLine in pairs(uiElems.lineTableItems) do
            for _, uiEl in pairs(elemsForLine) do
                uiEl:setVisible(true,false)
            end
        end
    else
        for _,lineStats in pairs(uiState.allLinesCache) do
            if uiElems.lineTableItems[lineStats.lineId] then
                local elemsForLine = uiElems.lineTableItems[lineStats.lineId]
                if lineStats.vehicleTypeStr == typeOfLine then
                    for _, uiEl in pairs(elemsForLine) do
                        uiEl:setVisible(true,false)
                    end
                else
                    for _, uiEl in pairs(elemsForLine) do
                        uiEl:setVisible(false,false)
                    end
                end
            end
        end
    end

    -- set all other toggle buttons as unselected
    for _, toggleButton in pairs(toggleButtons) do
        toggleButton:setSelected(false,false)
    end
    -- set only the selected toggle Button as selected
    if toggleButtons[typeOfLine] then
        toggleButtons[typeOfLine]:setSelected(true,false)
    end
end


function linesListGui.fillLostLines()
    print("Find Lost Vehicles")
    uiElems.lostTrainsTable:deleteRows(0,uiElems.lostTrainsTable:getNumRows())

    local lostTrains = lostTrainsHelper.findLostTrains()

    local lblCol1 = api.gui.comp.TextView.new("Line")
    local lblCol2 = api.gui.comp.TextView.new("Name")
    local lblCol3 = api.gui.comp.TextView.new("Time Since Departure")
    uiElems.lostTrainsTable:addRow({lblCol1, lblCol2,lblCol3 })

    if lostTrains then
        for vehicleId, timeSinceDep in pairs(lostTrains) do
            local vehicleName = luaUtils.shortenName(vehiclesHelper.getVehicleName(vehicleId), 40)
            local lineName = luaUtils.shortenName(vehiclesHelper.getLineNameOfVehicle(vehicleId), 50)

            local lblLineName = api.gui.comp.TextView.new(lineName)
            local lblVehicleName = uiUtil.makeLocateText(vehicleId, vehicleName)
            local timeStr = luaUtils.getTimeStr(timeSinceDep)
            local lblTimeSinceDep = api.gui.comp.TextView.new(timeStr)

            uiElems.lostTrainsTable:addRow({lblLineName, lblVehicleName,lblTimeSinceDep })
        end
    end
end

function linesListGui.fillLineTable()
    local start_time = os.clock()
    uiElems.lineTable:deleteRows(0,uiElems.lineTable:getNumRows())
    uiElems.lineTableItems = {}
    uiState.allLinesCache = {}

    local lblCol1 = api.gui.comp.TextView.new("Line Name")
    local lblCol2 = api.gui.comp.TextView.new("Demand")
    local lblCol3 = api.gui.comp.TextView.new("Load/Cap")
    local lblCol4 = api.gui.comp.TextView.new("Waiting")
    local lblCol5 = api.gui.comp.TextView.new("Max Stn") -- Overcrowded stn??
    local lblCol6 = api.gui.comp.TextView.new("Max Miss")
    local lblCol7 = api.gui.comp.TextView.new("Avg Speed")
    local lblCol8 = api.gui.comp.TextView.new("Journey")
    local lblCol9 = api.gui.comp.TextView.new("Freq.")
    local lblCol10 = api.gui.comp.TextView.new("Vehicles")
    -- TODO: more info button to right

    uiElems.lineTable:addRow({lblCol1, lblCol2,lblCol3,lblCol4,lblCol5,lblCol6,lblCol7,lblCol8,lblCol9,lblCol10 })

    local tempLines = lineStatsHelper.getPassengerStatsForAllLines()
    local sortedLinesArr = {}
    for _, lineStats in pairs(tempLines) do
        table.insert(sortedLinesArr, lineStats)
    end
    table.sort(sortedLinesArr, function(a,b) return string.lower(a.lineName) < string.lower(b.lineName) end)
    uiState.allLinesCache = sortedLinesArr

    for _, lineStats in pairs(uiState.allLinesCache) do
        local lineId = lineStats.lineId
        local shortenedLineName = luaUtils.shortenName(lineStats.lineName, 35)
        local maxStn = luaUtils.maximumArray(lineStats.peopleAtStop)
        local maxMissedTrain = luaUtils.maximumArray(lineStats.peopleAtStopLongWait)

        local journeyTimeStr = luaUtils.getTimeStr(lineStats.totalLegTime)

        -- Ui Elements
        local lineBtn = lineGui.createLineButton(lineId, shortenedLineName)
        local lblDemand = api.gui.comp.TextView.new(tostring( lineStats.totalCount))
        local lblLoadCap = api.gui.comp.TextView.new(lineStats.inVehCount .. "/" .. lineStats.lineCapacity)
        local compWaiting = uiUtil.makeIconText(tostring(lineStats.waitingCount), "ui/hud/cargo_passengers.tga")

        local lblMaxStn
        if maxStn and maxStn > 0 then
            lblMaxStn = api.gui.comp.TextView.new(tostring(maxStn))
        else
            lblMaxStn = api.gui.comp.TextView.new("")
        end

        local compLongWait
        if maxMissedTrain and maxMissedTrain > 0 then
            compLongWait = uiUtil.makeIconText(tostring(maxMissedTrain), "ui/clock_small@2x.tga")
        else
            compLongWait = api.gui.comp.TextView.new("")
        end

        local lblAvgSpeed = api.gui.comp.TextView.new(lineStats.totalAvgSpeedStr)
        local lblJourneyTime = api.gui.comp.TextView.new(journeyTimeStr)
        local lblFrequency = api.gui.comp.TextView.new(lineStats.lineFreqStr)
        local lblVehCount = api.gui.comp.TextView.new(tostring(lineStats.vehicleCount))

        -- Add the row to the table
        uiElems.lineTable:addRow({lineBtn, lblDemand, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblFrequency,lblVehCount})
        uiElems.lineTableItems[lineId] = {lineBtn, lblDemand, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblFrequency,lblVehCount}
    end

    print(string.format("linesListGui.fillLineTable. Elapsed time: %.4f\n", os.clock() - start_time))
end

return linesListGui


