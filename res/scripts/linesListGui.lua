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
    lineHeaderTable = nil,
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
    allLinesCache = {}, -- Cache for all lines. Array
}

function linesListGui.showLineList()
    linesListGui.showOrCreateUi()
    linesListGui.fillLostLines()
    linesListGui.fillLineTable()
    linesListGui.filterToLinesOfType(uiState.lastSelectedFilter, uiElems.toggleBtns)
end

function linesListGui.showOrCreateUi()
    print("-- showLineList --")
    if uiElems.window ~= nil then
        uiElems.window:setVisible(true, true)
        uiElems.window:setPinned(true)
        return
    end

    uiElems.floatLayoutLines = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutLines")
    linesListGui.createLineFilter()
    linesListGui.createLineTableHeader()
    linesListGui.createLineTable()

    uiElems.floatLayoutLost = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutlostTrains")
    linesListGui.createLostTrainsTable()

    -- Setting up Tabs
    uiElems.tabWidget = api.gui.comp.TabWidget.new("NORTH")
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLines, "Lines")
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLost, "Lost Trains")

    -- create final window
    uiElems.window = uiUtil.createWindow("Passenger Line Statistics", uiElems.tabWidget, 1000, 680, true)
end

function linesListGui.createLostTrainsTable()
    uiElems.lostTrainsTable = api.gui.comp.Table.new(3, 'SINGLE')
    uiElems.lostTrainsTable:setColWidth(0,380)
    uiElems.lostTrainsTable:setColWidth(1,380)
    uiElems.lostTrainsTable:setColWidth(2,200)

    uiElems.scrollAreaLostTrains = uiUtil.createScrollArea(uiElems.lostTrainsTable, 1000, 550, "lineInfo.mainUi.scrollAreaLostTrains")

    local resetLostTrainsButton = uiUtil.createButton("Reset Lost Trains")
	resetLostTrainsButton:onClick(lostTrainsHelper.resetLostTrains)

    uiElems.floatLayoutLost:addItem(uiElems.scrollAreaLostTrains,0,1)
    uiElems.floatLayoutLost:addItem(resetLostTrainsButton,0,0)
end

function linesListGui.createLineTable()
    uiElems.lineTable = api.gui.comp.Table.new(10, 'SINGLE')
    uiElems.lineTable:setColWidth(0,260)
    uiElems.lineTable:setColWidth(1,80)
    uiElems.lineTable:setColWidth(2,100)
    uiElems.lineTable:setColWidth(3,80)
    uiElems.lineTable:setColWidth(4,80)
    uiElems.lineTable:setColWidth(5,80)
    uiElems.lineTable:setColWidth(6,100)
    uiElems.lineTable:setColWidth(7,80)
    uiElems.lineTable:setColWidth(8,60)
    uiElems.lineTable:setColWidth(9,60)

    uiElems.scrollAreaLines = uiUtil.createScrollArea(uiElems.lineTable, 1000, 530, "lineInfo.mainUi.scrollAreaLines")
    uiElems.floatLayoutLines:addItem(uiElems.scrollAreaLines,0,1)
end

function linesListGui.createLineTableHeader()
    -- Needs to match uiElems.lineTable
    uiElems.lineHeaderTable = api.gui.comp.Table.new(10, 'SINGLE')
    uiElems.lineHeaderTable:setColWidth(0,260)
    uiElems.lineHeaderTable:setColWidth(1,80)
    uiElems.lineHeaderTable:setColWidth(2,100)
    uiElems.lineHeaderTable:setColWidth(3,80)
    uiElems.lineHeaderTable:setColWidth(4,80)
    uiElems.lineHeaderTable:setColWidth(5,80)
    uiElems.lineHeaderTable:setColWidth(6,100)
    uiElems.lineHeaderTable:setColWidth(7,80)
    uiElems.lineHeaderTable:setColWidth(8,60)
    uiElems.lineHeaderTable:setColWidth(9,60)

    local nameBtn =  uiUtil.createButton("Line Name")
    nameBtn:onClick(linesListGui.sortByNameAlpha)

    local demandBtn =  uiUtil.createButton("Demand")
    demandBtn:onClick(linesListGui.sortByDemand)

    local loadBtn = uiUtil.createButton("Load/Cap")
    loadBtn:onClick(linesListGui.sortByLoad)

    local waitingBtn =  uiUtil.createButton("Waiting")
    waitingBtn:onClick( linesListGui.sortByWaiting)

    local maxStnBtn =  uiUtil.createButton("Max Stn") -- Overcrowded stn??
    maxStnBtn:onClick( linesListGui.sortByMaxAtStop)

    local maxMissBtn =  uiUtil.createButton("Max Miss")
    maxMissBtn:onClick( linesListGui.sortByMaxMiss)

    local avgSpdBtn =  uiUtil.createButton("Avg Speed")
    avgSpdBtn:onClick( linesListGui.sortBySpd)

    local journeyBtn =  uiUtil.createButton("Journey")
    journeyBtn:onClick( linesListGui.sortByJourney)

    local freqBtn =  uiUtil.createButton("Freq.")
    freqBtn:onClick( linesListGui.sortByFreq)

    local vehBtn =  uiUtil.createButton("Veh")
    vehBtn:onClick( linesListGui.sortByVehCount)

    --Add filter then the column headers
    uiElems.lineHeaderTable:addRow({uiElems.lineFilter, api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new("") })
    uiElems.lineHeaderTable:addRow({nameBtn, demandBtn,loadBtn,waitingBtn,maxStnBtn,maxMissBtn,avgSpdBtn,journeyBtn,freqBtn,vehBtn })

    uiElems.floatLayoutLines:addItem(uiElems.lineHeaderTable,0,0)
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

    uiState.allLinesCache = lineStatsHelper.getPassengerStatsForAllLines()

    for _, lineStats in pairs(uiState.allLinesCache) do
        local lineId = lineStats.lineId
        local shortenedLineName = luaUtils.shortenName(lineStats.lineName, 35)

        -- Ui Elements
        local lineBtn = lineGui.createLineButton(lineId, shortenedLineName)
        local lblDemand = api.gui.comp.TextView.new(tostring( lineStats.totalCount))
        local lblLoadCap = api.gui.comp.TextView.new(lineStats.inVehCount .. "/" .. lineStats.lineCapacity)
        local compWaiting = uiUtil.makeIconText(tostring(lineStats.waitingCount), "ui/hud/cargo_passengers.tga")

        local lblMaxStn
        if lineStats.maxAtStop > 0 then
            lblMaxStn = api.gui.comp.TextView.new(tostring(lineStats.maxAtStop))
        else
            lblMaxStn = api.gui.comp.TextView.new("")
        end

        local compLongWait
        if lineStats.maxLongWait > 0 then
            compLongWait = uiUtil.makeIconText(tostring(lineStats.maxLongWait), "ui/clock_small@2x.tga")
        else
            compLongWait = api.gui.comp.TextView.new("")
        end

        local lblAvgSpeed = api.gui.comp.TextView.new(lineStats.totalAvgSpeedStr)

        local journeyTimeStr = luaUtils.getTimeStr(lineStats.totalLegTime)
        local lblJourneyTime = api.gui.comp.TextView.new(journeyTimeStr)

        local lblFrequency = api.gui.comp.TextView.new(lineStats.lineFreqStr)
        local lblVehCount = api.gui.comp.TextView.new(tostring(lineStats.vehicleCount))

        -- Add the row to the table
        uiElems.lineTable:addRow({lineBtn, lblDemand, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblFrequency,lblVehCount})
        uiElems.lineTableItems[lineId] = {lineBtn, lblDemand, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblFrequency,lblVehCount}
    end

    linesListGui.sortByNameAlpha()
    print(string.format("linesListGui.fillLineTable. Elapsed time: %.4f\n", os.clock() - start_time))
end

function linesListGui.sortByNameAlpha()
    linesListGui.sortLines(function(a,b)
        return string.lower(a.value.lineName) < string.lower(b.value.lineName)
    end)
end
function linesListGui.sortByWaiting()
    linesListGui.sortLines(function(a,b)
        return a.value.waitingCount > b.value.waitingCount
    end)
end
function linesListGui.sortByVehCount()
    linesListGui.sortLines(function(a,b)
        return a.value.vehicleCount > b.value.vehicleCount
    end)
end
function linesListGui.sortByDemand()
    linesListGui.sortLines(function(a,b)
        return a.value.totalCount > b.value.totalCount
    end)
end
function linesListGui.sortByLoad()
    linesListGui.sortLines(function(a,b)
        return a.value.inVehCount > b.value.inVehCount
    end)
end
function linesListGui.sortByMaxAtStop()
    linesListGui.sortLines(function(a,b)
        return a.value.maxAtStop > b.value.maxAtStop
    end)
end
function linesListGui.sortByMaxMiss()
    linesListGui.sortLines(function(a,b)
        return a.value.maxLongWait > b.value.maxLongWait
    end)
end
function linesListGui.sortBySpd()
    linesListGui.sortLines(function(a,b)
        return a.value.totalAvgSpeed > b.value.totalAvgSpeed
    end)
end
function linesListGui.sortByJourney()
    linesListGui.sortLines(function(a,b)
        return a.value.totalLegTime > b.value.totalLegTime
    end)
end
function linesListGui.sortByFreq()
    linesListGui.sortLines(function(a,b)
        return a.value.lineFreq > b.value.lineFreq
    end)
end

function linesListGui.sortLines(sortFn)
    local order = luaUtils.getOrderOfArray(uiState.allLinesCache, sortFn)
    uiElems.lineTable:setOrder(order)
end

return linesListGui