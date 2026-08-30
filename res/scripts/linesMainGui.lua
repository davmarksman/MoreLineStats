local lineStatsHelper = require "lineStatsHelper"
local lostTrainsHelper = require "lostTrainsHelper"
local vehiclesHelper = require "vehiclesHelper"
local uiUtil = require "uiUtil"
local lineGui = require "lineGui"
local cargoLineGui = require "cargoLineGui"
local luaUtils = require "luaUtils"

local windowWidth = 1070
local colWidths = {260,75,90,95,80,80,75,95,75,70,65}
local PASSENGER_TAB = 0
local CARGO_TAB = 1
local LOST_TAB = 2
local LOADED_DO_NOTHING = 5

local linesMainGui = {}
local uiElems = {
    window = nil,
    tabWidget = nil,

    floatLayoutLost = nil,
    scrollAreaLostTrains = nil,
    lostTrainsTable = nil,

    floatLayoutPassengerLines = nil,
    passengerTable = nil,
    passengerTableItems = nil,
    passengerToggleBtns = nil,
    passengerSearchInput = nil,

    floatLayoutCargoLines = nil,
    cargoToggleBtns = nil,
    cargoSearchInput = nil,
    cargoTableItems = nil,
    cargoTable = nil,
}

-- Shared between passenger and cargo tabs
local uiState = {
    lastSelectedFilter = "ALL", -- Default filter
    searchText = "", -- Current line name search text (lower case)
    allLinesCache = {}, -- Cache for all lines (of cargo or passenger). Array,
    sortDesc = false, -- Sort order
    lastTab = PASSENGER_TAB, -- last selected tab index
}


function linesMainGui.showLineList()
    print("-- showLineList --")
    linesMainGui.showOrCreateUi()
    linesMainGui.initTab(uiState.lastTab)
end

function linesMainGui.initTab(tabSelected)
    -- 0 is first tab
    if tabSelected == PASSENGER_TAB then
        uiState.lastTab = PASSENGER_TAB
        linesMainGui.fillPassengerTable()
        linesMainGui.filterToLinesOfType(uiState.lastSelectedFilter, uiElems.passengerToggleBtns)
    elseif tabSelected == CARGO_TAB then
        uiState.lastTab = CARGO_TAB
        linesMainGui.fillCargoTable()
        linesMainGui.filterToLinesOfType(uiState.lastSelectedFilter, uiElems.cargoToggleBtns)
    elseif tabSelected == LOST_TAB then
        uiState.lastTab = LOST_TAB
        -- Lost Trains Tab
        linesMainGui.fillLostLines()
    else
        print("Doing nothing")
    end
end

function linesMainGui.showOrCreateUi()
    print("-- showOrCreateUi --")
    if uiElems.window ~= nil then
        uiElems.window:setVisible(true, true)
        uiElems.window:setPinned(true)
        return
    end

    -- Passenger Lines
    print("-- Passenger Lines --")
    uiElems.floatLayoutPassengerLines = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutPsngrLines")
    uiElems.passengerToggleBtns = linesMainGui.createLineFilterToggles()
    local passengerLineFilter = linesMainGui.createLineFilter(uiElems.passengerToggleBtns)
    uiElems.passengerSearchInput = linesMainGui.createSearchInput()

    linesMainGui.createPassengerTableHeader(passengerLineFilter, uiElems.passengerSearchInput)
    linesMainGui.createPassengerTable()

    -- Cargo Lines
    print("-- Cargo Lines --")
    uiElems.floatLayoutCargoLines = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutCargoLines")
    uiElems.cargoToggleBtns = linesMainGui.createLineFilterToggles()
    local cargoLineFilter = linesMainGui.createLineFilter(uiElems.cargoToggleBtns)
    uiElems.cargoSearchInput = linesMainGui.createSearchInput()

    linesMainGui.createCargoTableHeader(cargoLineFilter, uiElems.cargoSearchInput)
    linesMainGui.createCargoTable()

    -- Lost Trains
    print("-- Lost trains --")
    uiElems.floatLayoutLost = uiUtil.createFloatingLayout("lineInfo.mainUi.floatingLayoutlostTrains")
    linesMainGui.createLostTrainsTable()

    -- Setting up Tabs
    uiElems.tabWidget = api.gui.comp.TabWidget.new("NORTH")
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutPassengerLines, _("Passenger Lines"))
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutCargoLines, _("Cargo Lines"))
    uiUtil.addTabToWidget(uiElems.tabWidget, uiElems.floatLayoutLost, "Lost Trains")

    uiElems.tabWidget:onCurrentChanged(linesMainGui.initTab)

    -- create final window
    uiElems.window = uiUtil.createWindow("More Line Statistics", uiElems.tabWidget, windowWidth, 650, true)
    uiState.lastTab = LOADED_DO_NOTHING
end

--- ----------------------------------------------------
--- Lost Trains
--- ----------------------------------------------------
function linesMainGui.createLostTrainsTable()
    uiElems.lostTrainsTable = api.gui.comp.Table.new(3, 'SINGLE')
    uiElems.lostTrainsTable:setColWidth(0,380)
    uiElems.lostTrainsTable:setColWidth(1,380)
    uiElems.lostTrainsTable:setColWidth(2,200)

    uiElems.scrollAreaLostTrains = uiUtil.createScrollArea(uiElems.lostTrainsTable, windowWidth, 520, "lineInfo.mainUi.scrollAreaLostTrains")

    local resetLostTrainsButton = uiUtil.createButton("Reset Lost Trains")
	resetLostTrainsButton:onClick(lostTrainsHelper.resetLostTrains)


    local resetTrainsInViewButton =uiUtil.createButton("Reset Trains In View")
    resetTrainsInViewButton:onClick(lostTrainsHelper.resetVisibleTrains)
    local resetBtnHolder = uiUtil.makeHorizontal(resetLostTrainsButton,resetTrainsInViewButton)

    uiElems.floatLayoutLost:addItem(uiElems.scrollAreaLostTrains,0,1)
    uiElems.floatLayoutLost:addItem(resetBtnHolder,0,0)
end

function linesMainGui.fillLostLines()
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

--- ------------------------------------------------
--- -- Passenger & Cargo Common
--- ------------------------------------------------

function linesMainGui.createLineFilter(toggleBtns)
    local lineFilter = api.gui.comp.Table.new(6, 'None')
    lineFilter:addRow({ toggleBtns["ALL"], toggleBtns["ROAD"], toggleBtns["TRAM"], toggleBtns["RAIL"], toggleBtns["WATER"], toggleBtns["AIR"] })
    return lineFilter
end

function linesMainGui.createLineFilterToggles()
    local toggleBtns = {}
    toggleBtns["ALL"] = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new("All"))
    toggleBtns["ROAD"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_road_vehicles.tga"))
    toggleBtns["TRAM"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/tram/TimetableTramIcon.tga"))
    toggleBtns["RAIL"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_trains.tga"))
    toggleBtns["WATER"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_ships.tga"))
    toggleBtns["AIR"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_planes.tga"))

    -- Filter Functions
    toggleBtns["ALL"]:onToggle(function()
        linesMainGui.filterToLinesOfType("ALL", toggleBtns)
    end)

    toggleBtns["ROAD"]:onToggle(function()
        linesMainGui.filterToLinesOfType("ROAD", toggleBtns)
    end)

    toggleBtns["TRAM"]:onToggle(function()
        linesMainGui.filterToLinesOfType("TRAM", toggleBtns)
    end)

    toggleBtns["RAIL"]:onToggle(function()
        linesMainGui.filterToLinesOfType("RAIL", toggleBtns)
    end)

    toggleBtns["WATER"]:onToggle(function()
        linesMainGui.filterToLinesOfType("WATER", toggleBtns)
    end)

    toggleBtns["AIR"]:onToggle(function()
        linesMainGui.filterToLinesOfType("AIR", toggleBtns)
    end)
    return toggleBtns
end

---Creates the text box used to filter lines by name
function linesMainGui.createSearchInput()
    local searchInput = api.gui.comp.TextInputField.new(_("Search line name..."))
    searchInput:setMaxLength(50)
    searchInput:setMinimumSize(api.gui.util.Size.new(700, 30))
    searchInput:setMaximumSize(api.gui.util.Size.new(700, 30))
    searchInput:setGravity(-1, 0)
    searchInput:onChange(function(text)
        uiState.searchText = string.lower(text or "")
        linesMainGui.applyFilters()
    end)
    return searchInput
end

---Builds the row above the column headers: type toggles, search box and reload button
function linesMainGui.createTopBar(lineFilter, searchInput, refreshDataBtn)
    local layout = api.gui.layout.BoxLayout.new("HORIZONTAL")
    layout:addItem(lineFilter)
    layout:addItem(searchInput)
    layout:addItem(refreshDataBtn)
    local topBar = api.gui.comp.Component.new("")
    topBar:setLayout(layout)
    topBar:setMinimumSize(api.gui.util.Size.new(windowWidth, 30))
    return topBar
end

---This filters the list of lines based on the line type
---@param typeOfLine string
---@param toggleButtons any
function linesMainGui.filterToLinesOfType(typeOfLine, toggleButtons)
    uiState.lastSelectedFilter = typeOfLine

    -- set all other toggle buttons as unselected
    for _, toggleButton in pairs(toggleButtons) do
        toggleButton:setSelected(false,false)
    end
    -- set only the selected toggle Button as selected
    if toggleButtons[typeOfLine] then
        toggleButtons[typeOfLine]:setSelected(true,false)
    end

    linesMainGui.applyFilters()
end

---Splits the search text on ',' into trimmed, lower case, non-empty terms
---@param searchText string
---@return table terms array of strings
function linesMainGui.parseSearchTerms(searchText)
    local terms = {}
    for term in string.gmatch(searchText or "", "[^,]+") do
        local trimmed = string.lower(string.match(term, "^%s*(.-)%s*$"))
        if trimmed ~= "" then
            table.insert(terms, trimmed)
        end
    end
    return terms
end

---Returns true if there are no search terms, or the line name contains any one of them
---@param lineName string
---@param terms table
---@return boolean
function linesMainGui.nameMatchesAnyTerm(lineName, terms)
    if #terms == 0 then
        return true
    end
    local lowerName = string.lower(lineName or "")
    for _, term in ipairs(terms) do
        if string.find(lowerName, term, 1, true) ~= nil then
            return true
        end
    end
    return false
end

---Shows only the lines matching both the selected line type and the search text
function linesMainGui.applyFilters()
    local tableItems = uiElems.passengerTableItems
    local searchInput = uiElems.passengerSearchInput
    if uiState.lastTab == CARGO_TAB then
        tableItems = uiElems.cargoTableItems
        searchInput = uiElems.cargoSearchInput
    end

    if tableItems == nil then
        print("No table items to filter!")
        return
    end

    -- Keep the search text in sync with the text box of the current tab
    if searchInput ~= nil then
        uiState.searchText = string.lower(searchInput:getText() or "")
    end

    local typeOfLine = uiState.lastSelectedFilter
    local searchTerms = linesMainGui.parseSearchTerms(uiState.searchText)

    for _, lineStats in pairs(uiState.allLinesCache) do
        local elemsForLine = tableItems[lineStats.lineId]
        if elemsForLine then
            local matchesType = typeOfLine == "ALL" or lineStats.vehicleTypeStr == typeOfLine
            local matchesName = linesMainGui.nameMatchesAnyTerm(lineStats.lineName, searchTerms)
            local visible = matchesType and matchesName
            for _, uiEl in pairs(elemsForLine) do
                uiEl:setVisible(visible,false)
            end
        end
    end
end


--- ----------------------------------------------------
--- Passengers
--- ----------------------------------------------------

function linesMainGui.createPassengerTableHeader(lineFilter, searchInput)
    local lineHeaderTable = api.gui.comp.Table.new(#colWidths, 'SINGLE')
    for i, width in pairs(colWidths) do
        lineHeaderTable:setColWidth(i-1,width)
    end

    local nameBtn =  uiUtil.createButtonToolTip("Line", "Line Name.\nClick to sort")
    nameBtn:onClick(linesMainGui.sortByNameAlpha)

    local demandBtn =  uiUtil.createButtonToolTip("Demand", "Total passengers on line (in vehicles + waiting).\nClick to sort")
    demandBtn:onClick(linesMainGui.sortByDemand)

    local demandCapBtn =  uiUtil.createButtonToolTip("Demand %", "Demand as a percentage of line capacity.\nHigher numbers indicate there may not be enough vehicles on the line.\nClick to sort")
    demandCapBtn:onClick(linesMainGui.sortByDemandCap)

    local loadBtn = uiUtil.createButtonToolTip("Passengers", "Passengers in vehicles (Loaded) / Line capacity.\nSame as on the line statistics window.\nClick to sort by passengers in vehicles (loaded)")
    loadBtn:onClick(linesMainGui.sortByLoad)

    local waitingBtn =  uiUtil.createButtonToolTip("Waiting", "Passengers currently waiting at stops.\nClick to sort")
    waitingBtn:onClick( linesMainGui.sortByWaiting)

    local maxStnBtn =  uiUtil.createButtonToolTip("Busiest", "Number of passengers at the busiest stop.\nClick to sort")
    maxStnBtn:onClick( linesMainGui.sortByMaxAtStop)

    local longWaitBtn =  uiUtil.createButtonToolTip("Missed", "How many passengers have been waiting for longer than the line frequency.\nClick to sort")
    longWaitBtn:onClick( linesMainGui.sortByLongWait)

    local avgSpdBtn =  uiUtil.createButtonToolTip("Avg Speed", "Average line speed between stops (as the crow flies).\nClick to sort")
    avgSpdBtn:onClick( linesMainGui.sortBySpd)

    local journeyBtn =  uiUtil.createButtonToolTip("Journey", "Total journey time for the line (sum of leg times between stops).\nClick to sort")
    journeyBtn:onClick( linesMainGui.sortByJourney)

    local distBtn =  uiUtil.createButtonToolTip("Length", "Total distance between the stops of the line (as the crow flies between each stop).\nClick to sort")
    distBtn:onClick( linesMainGui.sortByDistance)

    local freqBtn =  uiUtil.createButtonToolTip("Freq.", "Indicates the time between two vehicles of that line in real time at normal game speed\nSame as shown in line window.\nClick to sort")
    freqBtn:onClick( linesMainGui.sortByFreq)

    local refreshDataBtn = uiUtil.createButtonToolTip("Reload", "Refresh the data shown in the table")
    refreshDataBtn:onClick(function ()
        linesMainGui.initTab(PASSENGER_TAB)
    end)

    -- Top bar (filter, search & reload) above the column headers
    local topBar = linesMainGui.createTopBar(lineFilter, searchInput, refreshDataBtn)
    lineHeaderTable:addRow({nameBtn, demandBtn,demandCapBtn,loadBtn,waitingBtn,maxStnBtn,longWaitBtn,avgSpdBtn,journeyBtn, distBtn,freqBtn})

    -- Stack the top bar and the column headers into one component (the floating layout only handles two rows well)
    local headerLayout = api.gui.layout.BoxLayout.new("VERTICAL")
    local header = uiUtil.createComp(headerLayout, topBar, lineHeaderTable)
    uiElems.floatLayoutPassengerLines:addItem(header,0,0)
end

function linesMainGui.createPassengerTable()
    uiElems.passengerTable = api.gui.comp.Table.new(#colWidths, 'SINGLE')

    for i, width in pairs(colWidths) do
        uiElems.passengerTable:setColWidth(i-1,width)
    end

    local scrollAreaPassenger = uiUtil.createScrollArea(uiElems.passengerTable, windowWidth, 500, "lineInfo.mainUi.scrollAreaPassengerLines") 

    uiElems.floatLayoutPassengerLines:addItem(scrollAreaPassenger,0,1)
end


---Fill the line table with passenger lines
function linesMainGui.fillPassengerTable()
    local start_time = os.clock()
    uiElems.passengerTable:deleteRows(0,uiElems.passengerTable:getNumRows())
    uiElems.passengerTableItems = {}
    uiState.allLinesCache = {}
    uiState.allLinesCache = lineStatsHelper.getPassengerStatsForAllLines()

    for _, lineStats in pairs(uiState.allLinesCache) do
        local lineId = lineStats.lineId
        local shortenedLineName = luaUtils.shortenName(lineStats.lineName, 35)

        -- Ui Elements
        local lineBtn = lineGui.createLineButton(lineId, shortenedLineName)
        local lblDemand = api.gui.comp.TextView.new(tostring( lineStats.lineDemand))
        local lblDemandCap = api.gui.comp.TextView.new(string.format("%.d%%", lineStats.demandCapRatio * 100))
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
        uiElems.passengerTable:addRow({lineBtn, lblDemand, lblDemandCap, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblDistance, lblFrequency})
        uiElems.passengerTableItems[lineId] = {lineBtn, lblDemand, lblDemandCap, lblLoadCap, compWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblDistance, lblFrequency}
    end

    linesMainGui.firstSort()
    print(string.format("linesMainGui.fillpassengerTable. Elapsed time: %.4f", os.clock() - start_time))
end

--- ----------------------------------------------------
--- Cargo
--- ----------------------------------------------------

function linesMainGui.createCargoTableHeader(lineFilter, searchInput)
    local lineHeaderTable = api.gui.comp.Table.new(#colWidths, 'SINGLE')
    for i, width in pairs(colWidths) do
        lineHeaderTable:setColWidth(i-1,width)
    end

    local nameBtn =  uiUtil.createButtonToolTip("Line", "Line Name.\nClick to sort")
    nameBtn:onClick(linesMainGui.sortByNameAlpha)

    local demandBtn =  uiUtil.createButtonToolTip("Demand", "Total cargo on line (in vehicles + waiting).\nClick to sort")
    demandBtn:onClick(linesMainGui.sortByDemand)

    local demandCapBtn =  uiUtil.createButtonToolTip("Demand %", "Demand as a percentage of line capacity.\nNumbers below 100% indicate less demand than line capacity.\nClick to sort")
    demandCapBtn:onClick(linesMainGui.sortByDemandCap)

    local loadBtn = uiUtil.createButtonToolTip("Cargo", "Cargo in vehicles (Loaded) / Line capacity.\nSame as on the line statistics window.\nClick to sort by cargo in vehicles (loaded)")
    loadBtn:onClick(linesMainGui.sortByLoad)

    local waitingBtn =  uiUtil.createButtonToolTip("Waiting", "cargo currently waiting at stops.\nClick to sort")
    waitingBtn:onClick( linesMainGui.sortByWaiting)

    local maxStnBtn =  uiUtil.createButtonToolTip("Busiest", "Number of cargo at the busiest stop.\nClick to sort")
    maxStnBtn:onClick( linesMainGui.sortByMaxAtStop)

    local longWaitBtn =  uiUtil.createButtonToolTip("Missed", "How much cargo has been waiting for longer than the line frequency.\nClick to sort")
    longWaitBtn:onClick( linesMainGui.sortByLongWait)

    local avgSpdBtn =  uiUtil.createButtonToolTip("Avg Speed", "Average line speed between stops (as the crow flies).\nClick to sort")
    avgSpdBtn:onClick( linesMainGui.sortBySpd)

    local journeyBtn =  uiUtil.createButtonToolTip("Journey", "Total journey time for the line (sum of leg times between stops).\nClick to sort")
    journeyBtn:onClick( linesMainGui.sortByJourney)

    local distBtn =  uiUtil.createButtonToolTip("Length", "Total distance between the stops of the line (as the crow flies between each stop).\nClick to sort")
    distBtn:onClick( linesMainGui.sortByDistance)

    local freqBtn =  uiUtil.createButtonToolTip("Freq.", "Indicates the time between two vehicles of that line in real time at normal game speed.\nSame as shown in line window).\nClick to sort")
    freqBtn:onClick( linesMainGui.sortByFreq)

    local refreshDataBtn = uiUtil.createButtonToolTip("Reload", "Refresh the data shown in the table")
    refreshDataBtn:onClick(function ()
        linesMainGui.initTab(CARGO_TAB)
    end)

    -- Top bar (filter, search & reload) above the column headers
    local topBar = linesMainGui.createTopBar(lineFilter, searchInput, refreshDataBtn)
    lineHeaderTable:addRow({nameBtn, demandBtn,demandCapBtn,loadBtn,waitingBtn,maxStnBtn,longWaitBtn,avgSpdBtn,journeyBtn, distBtn,freqBtn})

    -- Stack the top bar and the column headers into one component (the floating layout only handles two rows well)
    local headerLayout = api.gui.layout.BoxLayout.new("VERTICAL")
    local header = uiUtil.createComp(headerLayout, topBar, lineHeaderTable)
    uiElems.floatLayoutCargoLines:addItem(header,0,0)
end

function linesMainGui.createCargoTable()
    uiElems.cargoTable = api.gui.comp.Table.new(#colWidths, 'SINGLE')

    for i, width in pairs(colWidths) do
        uiElems.cargoTable:setColWidth(i-1,width)
    end

    local scrollAreaCargoLines = uiUtil.createScrollArea(uiElems.cargoTable, windowWidth, 500, "lineInfo.mainUi.scrollAreaCargoLines") 

    uiElems.floatLayoutCargoLines:addItem(scrollAreaCargoLines,0,1)
end


function linesMainGui.fillCargoTable()
    local start_time = os.clock()
    uiElems.cargoTable:deleteRows(0,uiElems.cargoTable:getNumRows())
    uiElems.cargoTableItems = {}
    uiState.allLinesCache = {}
    uiState.allLinesCache = lineStatsHelper.getCargoStatsForAllLines()

    for _, lineStats in pairs(uiState.allLinesCache) do
        local lineId = lineStats.lineId
        local shortenedLineName = luaUtils.shortenName(lineStats.lineName, 35)

        -- Ui Elements
        local lineBtn = cargoLineGui.createCargoLineButton(lineId, shortenedLineName)
        local lblDemand = api.gui.comp.TextView.new(tostring( lineStats.lineDemand))
        local lblDemandCap = api.gui.comp.TextView.new(string.format("%.d%%", lineStats.demandCapRatio * 100))
        local lblLoadCap = api.gui.comp.TextView.new(lineStats.inVehCount .. "/" .. lineStats.lineCapacity)
        local lblWaiting = api.gui.comp.TextView.new(tostring(lineStats.waitingCount))

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
        uiElems.cargoTable:addRow({lineBtn, lblDemand, lblDemandCap, lblLoadCap, lblWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblDistance, lblFrequency})
        uiElems.cargoTableItems[lineId] = {lineBtn, lblDemand, lblDemandCap, lblLoadCap, lblWaiting, lblMaxStn, compLongWait, lblAvgSpeed, lblJourneyTime, lblDistance, lblFrequency}
    end

    linesMainGui.firstSort()
    print(string.format("linesMainGui.cargoTable. Elapsed time: %.4f", os.clock() - start_time))
end


--- ----------------------------------------------------
--- Common Sorting Functions
--- ----------------------------------------------------

function linesMainGui.firstSort()
    linesMainGui.sortLines(function(a,b)
        return string.lower(a.value.lineName) < string.lower(b.value.lineName) 
    end)
    uiState.sortDesc = false
end
function linesMainGui.sortByNameAlpha()
    linesMainGui.sortLines(function(a,b)
        if uiState.sortDesc then
            return string.lower(a.value.lineName) > string.lower(b.value.lineName)
        else
            return string.lower(a.value.lineName) < string.lower(b.value.lineName)
        end
    end)
end
function linesMainGui.sortByWaiting()
    linesMainGui.sortLinesNum(function(row)
        return row.value.waitingCount
    end)
end
function linesMainGui.sortByDemand()
    linesMainGui.sortLinesNum(function(row)
        return row.value.lineDemand
    end)
end
function linesMainGui.sortByDemandCap()
    linesMainGui.sortLinesNum(function(row)
        return row.value.demandCapRatio
    end)
end
function linesMainGui.sortByLoad()
    linesMainGui.sortLinesNum(function(row)
        return row.value.inVehCount
    end)
end
function linesMainGui.sortByMaxAtStop()
    linesMainGui.sortLinesNum(function(row)
        return row.value.maxAtStop
    end)
end
function linesMainGui.sortByLongWait()
    linesMainGui.sortLinesNum(function(row)
        return row.value.longWaitCount
    end)
end
function linesMainGui.sortBySpd()
    linesMainGui.sortLinesNum(function(row)
        return row.value.totalAvgSpeed
    end)
end
function linesMainGui.sortByJourney()
    linesMainGui.sortLinesNum(function(row)
        return row.value.totalLegTime
    end)
end
function linesMainGui.sortByDistance()
    linesMainGui.sortLinesNum(function(row)
        return row.value.totalDistanceKm
    end)
end
function linesMainGui.sortByFreq()
    linesMainGui.sortLinesNum(function(row)
        return row.value.lineFreq
    end)
end

function linesMainGui.sortLines(sortFn)
    local order = luaUtils.getOrderOfArray(uiState.allLinesCache, sortFn)

    if uiState.lastTab == CARGO_TAB then
        uiElems.cargoTable:setOrder(order)
    else
        uiElems.passengerTable:setOrder(order)
    end
    uiState.sortDesc = not uiState.sortDesc
end

---@param fieldFn function sorting function
function linesMainGui.sortLinesNum(fieldFn)
    local sortFn = function (a,b)
        if uiState.sortDesc then
            return fieldFn(a) > fieldFn(b)
        else
            return fieldFn(a) < fieldFn(b)
        end
    end

    linesMainGui.sortLines(sortFn)
end

return linesMainGui