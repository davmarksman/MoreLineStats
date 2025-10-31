local lineStatsHelper = require "lineStatsHelper"
local lostTrainsHelper = require "lostTrainsHelper"
local vehiclesHelper = require "vehiclesHelper"
local uiUtil = require "uiUtil"
local lineGui = require "lineGui"
local luaUtils = require "luaUtils"

local windowWidth = 1070
local colWidths = {260,75,90,95,80,80,75,95,75,70,65}

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
    allLinesCache = {}, -- Cache for all lines. Array,
    sortDesc = false, -- Sort order
}

function linesListGui.showLineList()
    linesListGui.showOrCreateUi()
    linesListGui.fillLostLines()
    linesListGui.fillLineTable()
    linesListGui.filterToLinesOfType(uiState.lastSelectedFilter, uiElems.toggleBtns)
end

function linesListGui.showOrCreateUi()
    print("-- showOrCreateUi --")
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
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLines, _("Passenger Lines"))
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLost, "Lost Trains")

    -- create final window
    uiElems.window = uiUtil.createWindow("More Line Statistics", uiElems.tabWidget, windowWidth, 650, true)
end

function linesListGui.createLostTrainsTable()
    uiElems.lostTrainsTable = api.gui.comp.Table.new(3, 'SINGLE')
    uiElems.lostTrainsTable:setColWidth(0,380)
    uiElems.lostTrainsTable:setColWidth(1,380)
    uiElems.lostTrainsTable:setColWidth(2,200)

    uiElems.scrollAreaLostTrains = uiUtil.createScrollArea(uiElems.lostTrainsTable, windowWidth, 520, "lineInfo.mainUi.scrollAreaLostTrains")

    local resetLostTrainsButton = uiUtil.createButton("Reset Lost Trains")
	resetLostTrainsButton:onClick(lostTrainsHelper.resetLostTrains)

    uiElems.floatLayoutLost:addItem(uiElems.scrollAreaLostTrains,0,1)
    uiElems.floatLayoutLost:addItem(resetLostTrainsButton,0,0)
end

function linesListGui.createLineTable()
    uiElems.lineTable = api.gui.comp.Table.new(#colWidths, 'SINGLE')

    for i, width in pairs(colWidths) do
        uiElems.lineTable:setColWidth(i-1,width)
    end

    uiElems.scrollAreaLines = uiUtil.createScrollArea(uiElems.lineTable, windowWidth, 500, "lineInfo.mainUi.scrollAreaLines")
    uiElems.floatLayoutLines:addItem(uiElems.scrollAreaLines,0,1)
end

function linesListGui.createLineTableHeader()
    -- Needs to match uiElems.lineTable
    uiElems.lineHeaderTable = api.gui.comp.Table.new(#colWidths, 'SINGLE')
    for i, width in pairs(colWidths) do
        uiElems.lineHeaderTable:setColWidth(i-1,width)
    end

    local nameBtn =  uiUtil.createButtonToolTip("Line", "Line Name. Click to sort")
    nameBtn:onClick(linesListGui.sortByNameAlpha)

    local demandBtn =  uiUtil.createButtonToolTip("Demand", "Total passengers on line (in vehicles + waiting). Click to sort")
    demandBtn:onClick(linesListGui.sortByDemand)

    local demandCapBtn =  uiUtil.createButtonToolTip("Demand %", "Demand/Capacity: Demand as a percentage of line capacity. Numbers below 100% indicate less demand than line capacity. Click to sort")
    demandCapBtn:onClick(linesListGui.sortByDemandCap)

    local loadBtn = uiUtil.createButtonToolTip("Passengers", "Passengers in vehicles (Loaded) / line capacity. Same as on the line statistics windov. Click to sort by passengers in vehicles (loaded)")
    loadBtn:onClick(linesListGui.sortByLoad)

    local waitingBtn =  uiUtil.createButtonToolTip("Waiting", "Passengers currently waiting at stops. Click to sort")
    waitingBtn:onClick( linesListGui.sortByWaiting)

    local maxStnBtn =  uiUtil.createButtonToolTip("Busiest", "Number of passengers at the busiest stop. Click to sort")
    maxStnBtn:onClick( linesListGui.sortByMaxAtStop)

    local longWaitBtn =  uiUtil.createButtonToolTip("Missed", "How many passengers have been waiting for longer than the line frequency (Aka there was not enough space on the last vehicle for them). Click to sort")
    longWaitBtn:onClick( linesListGui.sortByLongWait)

    local avgSpdBtn =  uiUtil.createButtonToolTip("Avg Speed", "Average line speed between stops (as the crow flies). Click to sort")
    avgSpdBtn:onClick( linesListGui.sortBySpd)

    local journeyBtn =  uiUtil.createButtonToolTip("Journey", "Total journey time for the line (sum of leg times between stops). Click to sort")
    journeyBtn:onClick( linesListGui.sortByJourney)

    local distBtn =  uiUtil.createButtonToolTip("Length", "Total distance between the stops of the line (as the crow flies between each stop). Click to sort")
    distBtn:onClick( linesListGui.sortByDistance)

    local freqBtn =  uiUtil.createButtonToolTip("Freq.", "Indicates the time between two vehicles of that line in real time at normal game speed (Same as shown in line window). Click to sort")
    freqBtn:onClick( linesListGui.sortByFreq)

    local refreshDataBtn = uiUtil.createButtonToolTip("Reload", "Refresh the data shown in the table")
    refreshDataBtn:onClick(function ()
        linesListGui.showLineList()
    end)

    --Add filter & refreshDataBtn then the column headers
    uiElems.lineHeaderTable:addRow({uiElems.lineFilter,api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),api.gui.comp.TextView.new(""),refreshDataBtn })
    uiElems.lineHeaderTable:addRow({nameBtn, demandBtn,demandCapBtn,loadBtn,waitingBtn,maxStnBtn,longWaitBtn,avgSpdBtn,journeyBtn, distBtn,freqBtn})

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
        local lblDemand = api.gui.comp.TextView.new(tostring( lineStats.lineDemand))
        local lblDemandCap = api.gui.comp.TextView.new(string.format("%.d %%", lineStats.demandCapRatio * 100))
        local lblLoadCap = api.gui.comp.TextView.new(lineStats.inVehCount .. "/" .. lineStats.lineCapacity)
        local compWaiting = uiUtil.makeIconText(tostring(lineStats.waitingCount), "ui/hud/cargo_passengers.tga")

        local lblMaxStn
        if lineStats.maxAtStop > 0 then
            lblMaxStn = api.gui.comp.TextView.new(tostring(lineStats.maxAtStop))
        else
            lblMaxStn = api.gui.comp.TextView.new("")
        end

        local compLongWait
        if lineStats.longWaitCount > 0 then
            compLongWait = uiUtil.makeIconText(tostring(lineStats.longWaitCount), "ui/clock_small@2x.tga")
        else
            compLongWait = api.gui.comp.TextView.new("")
        end

        local lblAvgSpeed = api.gui.comp.TextView.new(lineStats.totalAvgSpeedStr)

        local journeyTimeStr = luaUtils.getTimeStr(lineStats.totalLegTime)
        local lblJourneyTime = api.gui.comp.TextView.new(journeyTimeStr)

        local lblDistance = api.gui.comp.TextView.new(string.format("%.1f km", lineStats.totalDistanceKm))

        local lblFrequency = api.gui.comp.TextView.new(lineStats.lineFreqStr)
        -- local lblVehCount = api.gui.comp.TextView.new(tostring(lineStats.vehicleCount))

        -- Add the row to the table
        uiElems.lineTable:addRow({lineBtn, lblDemand, lblDemandCap, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblDistance, lblFrequency})
        uiElems.lineTableItems[lineId] = {lineBtn, lblDemand, lblDemandCap, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblDistance, lblFrequency}
    end

    linesListGui.firstSort()
    print(string.format("linesListGui.fillLineTable. Elapsed time: %.4f", os.clock() - start_time))
end


-- Sorting functions
function linesListGui.firstSort()
    linesListGui.sortLines(function(a,b)
        return string.lower(a.value.lineName) < string.lower(b.value.lineName) 
    end)
    uiState.sortDesc = false
end
function linesListGui.sortByNameAlpha()
    linesListGui.sortLines(function(a,b)
        if uiState.sortDesc then
            return string.lower(a.value.lineName) > string.lower(b.value.lineName)
        else
            return string.lower(a.value.lineName) < string.lower(b.value.lineName)
        end
    end)
end
function linesListGui.sortByWaiting()
    linesListGui.sortLinesNum(function(row)
        return row.value.waitingCount
    end)
end
function linesListGui.sortByDemand()
    linesListGui.sortLinesNum(function(row)
        return row.value.lineDemand
    end)
end
function linesListGui.sortByDemandCap()
    linesListGui.sortLinesNum(function(row)
        return row.value.demandCapRatio
    end)
end
function linesListGui.sortByLoad()
    linesListGui.sortLinesNum(function(row)
        return row.value.inVehCount
    end)
end
function linesListGui.sortByMaxAtStop()
    linesListGui.sortLinesNum(function(row)
        return row.value.maxAtStop
    end)
end
function linesListGui.sortByLongWait()
    linesListGui.sortLinesNum(function(row)
        return row.value.longWaitCount
    end)
end
function linesListGui.sortBySpd()
    linesListGui.sortLinesNum(function(row)
        return row.value.totalAvgSpeed
    end)
end
function linesListGui.sortByJourney()
    linesListGui.sortLinesNum(function(row)
        return row.value.totalLegTime
    end)
end
function linesListGui.sortByDistance()
    linesListGui.sortLinesNum(function(row)
        return row.value.totalDistanceKm
    end)
end
function linesListGui.sortByFreq()
    linesListGui.sortLinesNum(function(row)
        return row.value.lineFreq
    end)
end

function linesListGui.sortLines(sortFn)
    local order = luaUtils.getOrderOfArray(uiState.allLinesCache, sortFn)
    uiElems.lineTable:setOrder(order)
    uiState.sortDesc = not uiState.sortDesc
end

---@param fieldFn function sorting function
function linesListGui.sortLinesNum(fieldFn)
    local sortFn = function (a,b)
        if uiState.sortDesc then
            return fieldFn(a) > fieldFn(b)
        else
            return fieldFn(a) < fieldFn(b)
        end
    end

    linesListGui.sortLines(sortFn)
end

return linesListGui