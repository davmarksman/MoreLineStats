local lineStatsHelper = require "lineStatsHelper"
local timetableHelper = require "timetableHelper"
local lostTrainsHelper = require "lostTrainsHelper"
local uiUtil = require "uiHelper"

local gui = require "gui"

local menu = {window = nil, lineTableItems = {}}

-- We keep track of UI state when window opened/closed
local UIState = {
    lastSelectedLineTableIndex = nil,
    lastSelectedLineId = nil,
    lastSelectedStationIndex = nil,
    lastSelectedFilter = nil
}

local lineStatsGUI = {}
local vehicle2cargoMapCache = {}


-- Keeps track of where the scroll bar is so the ui scrolls to them when initialised
local stationTableScrollOffset
local lineTableScrollOffset
-- local detailsTableScrollOffset
local toggleBtns

local function err(x)
	print("An error was caught", x)
	local traceback = debug.traceback()
	print(traceback)
 
end
-------------------------------------------------------------
---------------------- SETUP --------------------------------
-------------------------------------------------------------

--- Sets up UI Elements for the Line (Left) table
function lineStatsGUI.initLineTable() 
    if menu.scrollArea then
        local tmp = menu.scrollArea:getScrollOffset()
        lineTableScrollOffset = api.type.Vec2i.new(tmp.x, tmp.y)
        UIState.boxLayoutLines:removeItem(menu.scrollArea)
    else
        lineTableScrollOffset = api.type.Vec2i.new()
    end
    if menu.lineHeader then UIState.boxLayoutLines:removeItem(menu.lineHeader) end


    menu.scrollArea = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('LineOverview'), "lineStatsg.LineOverview")
    menu.lineTable = api.gui.comp.Table.new(2, 'SINGLE')
    menu.lineTable:setColWidth(0,28)

    menu.lineTable:onSelect(function(index)
        lineStatsGUI.onLineSelected(index)
    end)

    menu.lineTable:setColWidth(1,240)

    menu.scrollArea:setMinimumSize(api.gui.util.Size.new(300, 570))
    menu.scrollArea:setMaximumSize(api.gui.util.Size.new(300, 570))
    menu.scrollArea:setContent(menu.lineTable)

    lineStatsGUI.fillLineTable()
    UIState.boxLayoutLines:addItem(menu.scrollArea,0,1)

    lineStatsGUI.scrollToLastLinePosition(lineTableScrollOffset)
end

--- QOL: This selects/scrolls to the last selected Line
function lineStatsGUI.scrollToLastLinePosition(offset)  
    menu.scrollArea:invokeLater( function () 
        menu.scrollArea:invokeLater(function () 
            menu.scrollArea:setScrollOffset(offset)
        end) 
    end)

    if UIState.lastSelectedLineTableIndex then
        if UIState.lastSelectedFilter then
            lineStatsGUI.filterToLinesOfType(UIState.lastSelectedFilter, toggleBtns)
        end

        if menu.lineTable:getNumRows() > UIState.lastSelectedLineTableIndex and not(menu.lineTable:getNumRows() == 0) then
            menu.lineTable:select(UIState.lastSelectedLineTableIndex, false) -- false so we don't trigger the event
        end
    end
end

--- Sets up UI Elements for the Station (Middle) table
function lineStatsGUI.initStationTable()
    if menu.stationScrollArea then
        local tmp = menu.stationScrollArea:getScrollOffset()
        stationTableScrollOffset = api.type.Vec2i.new(tmp.x, tmp.y)
        UIState.boxLayoutLines:removeItem(menu.stationScrollArea)
    else
        stationTableScrollOffset = api.type.Vec2i.new()
    end

    menu.stationScrollArea = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('stationScrollArea'), "lineStatsg.stationScrollArea")

    menu.stationTable = api.gui.comp.Table.new(6, 'SINGLE')
    menu.stationTable:setColWidth(0,40)
    menu.stationTable:setColWidth(1,260)
    menu.stationTable:setColWidth(2,80)
    menu.stationTable:setColWidth(3,80)
    menu.stationTable:setColWidth(4,80)
    menu.stationTable:setColWidth(5,50)

    menu.stationTable:onSelect(function (tableIndex)
        if not (tableIndex == -1) and  UIState.lastSelectedLineId then
            UIState.lastSelectedStationIndex = tableIndex

            lineStatsGUI.fillDetailsTable(tableIndex, UIState.lastSelectedLineId)
            lineStatsGUI.fillVehTableForSection(tableIndex, UIState.lastSelectedLineId)
        end
    end)

    menu.stationScrollArea:setMinimumSize(api.gui.util.Size.new(600, 600))
    menu.stationScrollArea:setMaximumSize(api.gui.util.Size.new(600, 600))
    menu.stationScrollArea:setContent(menu.stationTable)
    UIState.boxLayoutLines:addItem(menu.stationScrollArea,0.5,0)
end

--- Sets up UI Elements for the Details Area (Right) table
function lineStatsGUI.initDetailsArea()
    if menu.scrollAreaDetails then
        UIState.boxLayoutLines:removeItem(menu.scrollAreaDetails)
        UIState.boxLayoutLines:removeItem(menu.scrollAreaVeh)
    end

    menu.scrollAreaVeh = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('scrollAreaVeh'), "lineStatsg.scrollAreaVeh")
    menu.scrollAreaVeh:setMinimumSize(api.gui.util.Size.new(300, 200))
    menu.scrollAreaVeh:setMaximumSize(api.gui.util.Size.new(300, 200))
    
    menu.lineVehTable = api.gui.comp.Table.new(1, 'SINGLE')
    menu.scrollAreaVeh:setContent(menu.lineVehTable)

    menu.scrollAreaDetails = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('scrollAreaDetails'), "lineStatsg.scrollAreaDetails")
    menu.scrollAreaDetails:setMinimumSize(api.gui.util.Size.new(300, 400))
    menu.scrollAreaDetails:setMaximumSize(api.gui.util.Size.new(300, 400))
    
    menu.detailsTable = api.gui.comp.Table.new(2, 'SINGLE')
    menu.detailsTable:setColWidth(0,60)
    menu.scrollAreaDetails:setContent(menu.detailsTable)

    UIState.boxLayoutLines:addItem(menu.scrollAreaVeh,1,0)
    UIState.boxLayoutLines:addItem(menu.scrollAreaDetails,1,1)
end

function lineStatsGUI.initLostTrainsTable()
    if menu.scrollAreaLostTrains then
        UIState.boxLayoutLost:removeItem(menu.scrollAreaLostTrains)
    end

    menu.scrollAreaLostTrains = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('scrollAreaLostTrains'), "lineStatsg.scrollAreaLostTrains")
    menu.scrollAreaLostTrains:setMinimumSize(api.gui.util.Size.new(1000, 550))
    menu.scrollAreaLostTrains:setMaximumSize(api.gui.util.Size.new(1000, 550))

    menu.lostTrainsTable = api.gui.comp.Table.new(3, 'SINGLE')
    menu.lostTrainsTable:setColWidth(0,300)
    menu.lostTrainsTable:setColWidth(1,300)
    menu.lostTrainsTable:setColWidth(2,200)
    menu.scrollAreaLostTrains:setContent(menu.lostTrainsTable)

    lineStatsGUI.fillLostLines()

    
    local resetLostTrainsButton = uiUtil.createButton("Reset Lost Trains")
	resetLostTrainsButton:onClick(lostTrainsHelper.resetLostTrains)

    UIState.boxLayoutLost:addItem(menu.scrollAreaLostTrains,0,1)
    UIState.boxLayoutLost:addItem(resetLostTrainsButton,0,0)
end

-------------------------------------------------------------
---------------------- Open UI Menu ---------------------------
-------------------------------------------------------------
function lineStatsGUI.showLineMenu()
    print("-- showLineMenu --")
    if menu.window ~= nil then
        lineStatsGUI.initLineTable()
        lineStatsGUI.initLostTrainsTable()
        return menu.window:setVisible(true, true)
    end
    if not api.gui.util.getById('lineStatsg.floatingLayout') then
        local floatingLayout = api.gui.layout.FloatingLayout.new(0,1)
        floatingLayout:setId("lineStatsg.floatingLayout")
    end
    -- new floating layout to arrange all members
    UIState.boxLayoutLines = api.gui.util.getById('lineStatsg.floatingLayout')
    UIState.boxLayoutLines:setGravity(-1,-1)

    lineStatsGUI.initLineTable()
    lineStatsGUI.initStationTable()
    lineStatsGUI.initDetailsArea()

    -- Setting up Line Tab
    menu.tabWidget = api.gui.comp.TabWidget.new("NORTH")
    local wrapper = api.gui.comp.Component.new("wrapper")
    wrapper:setLayout(UIState.boxLayoutLines )
    menu.tabWidget:addTab(api.gui.comp.TextView.new("Lines"), wrapper)

    -- Set up Lost Trains Tab
    if not api.gui.util.getById('lineStatsg.lostTrainsLayout') then
        local floatingLayoutLostTrains = api.gui.layout.FloatingLayout.new(0,1)
        floatingLayoutLostTrains:setId("lineStatsg.lostTrainsLayout")
    end

    UIState.boxLayoutLost = api.gui.util.getById('lineStatsg.lostTrainsLayout')
    UIState.boxLayoutLost:setGravity(-1,-1)

    lineStatsGUI.initLostTrainsTable()
    local lostTrainsWrapper = api.gui.comp.Component.new("wrapper")
    lostTrainsWrapper:setLayout(UIState.boxLayoutLost)
    menu.tabWidget:addTab(api.gui.comp.TextView.new("Lost Trains"), lostTrainsWrapper)

    -- create final window
    menu.window = api.gui.comp.Window.new("Line Statistics", menu.tabWidget)
    menu.window:addHideOnCloseHandler()
    menu.window:setMovable(true)
    menu.window:setPinButtonVisible(true)
    menu.window:setResizable(false)
    menu.window:setSize(api.gui.util.Size.new(1200, 680))
    menu.window:setPosition(200,200)
    menu.window:onClose(function()
        menu.lineTableItems = {}
    end)
end


-------------------------------------------------------------
---------------------- LOST LINES ---------------------------
-------------------------------------------------------------
function lineStatsGUI.fillLostLines()
    print("Find Lost Vehicles")
    menu.lostTrainsTable:deleteRows(0,menu.lostTrainsTable:getNumRows())

    local lostTrains = lineStatsHelper.findLostTrains()

    local lblCol1 = api.gui.comp.TextView.new("Line")
    local lblCol2 = api.gui.comp.TextView.new("Name")
    local lblCol3 = api.gui.comp.TextView.new("Time Since Departure")
    menu.lostTrainsTable:addRow({lblCol1, lblCol2,lblCol3 })

    if lostTrains then
        for vehicleId, timeSinceDep in pairs(lostTrains) do
            local vehicleName = lineStatsHelper.getVehicleName(vehicleId)
            local lineName = lineStatsHelper.getLineNameOfVehicle(vehicleId)
    
            local lblLineName = api.gui.comp.TextView.new(lineName)
            local lblVehicleName = uiUtil.makeLocateText(vehicleId, vehicleName)
            local timeStr = lineStatsHelper.getTimeStr(timeSinceDep)
            local lblTimeSinceDep = api.gui.comp.TextView.new(timeStr)
    
            menu.lostTrainsTable:addRow({lblLineName, lblVehicleName,lblTimeSinceDep })
        end
    end
end


-------------------------------------------------------------
---------------------- LEFT TABLE ---------------------------
-------------------------------------------------------------

function lineStatsGUI.fillLineTable()
    menu.lineTable:deleteRows(0,menu.lineTable:getNumRows())
    if not (menu.lineHeader == nil) then menu.lineHeader:deleteRows(0,menu.lineHeader:getNumRows()) end

    menu.lineHeader = api.gui.comp.Table.new(6, 'None')
    toggleBtns = {}

    toggleBtns["ALL"] = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new("All"))
    toggleBtns["ROAD"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_road_vehicles.tga"))
    toggleBtns["TRAM"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/tram/TimetableTramIcon.tga"))
    toggleBtns["RAIL"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_trains.tga"))
    toggleBtns["WATER"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_ships.tga"))
    toggleBtns["AIR"] = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_planes.tga"))

    menu.lineHeader:addRow({ toggleBtns["ALL"], toggleBtns["ROAD"], toggleBtns["TRAM"], toggleBtns["RAIL"], toggleBtns["WATER"], toggleBtns["AIR"] })

    -- Fill table of lines
    local lineNames = {}
    for k,v in pairs(timetableHelper.getAllLines()) do
        local lineDot = api.gui.comp.TextView.new("●")
        local lineName = api.gui.comp.TextView.new(v.name)
        lineNames[k] = v.name

        menu.lineTableItems[#menu.lineTableItems + 1] = {lineDot, lineName}
        menu.lineTable:addRow({lineDot, lineName})
    end

    local order = timetableHelper.getOrderOfArray(lineNames)
    menu.lineTable:setOrder(order)

    -- Filter Functions
    toggleBtns["ALL"]:onToggle(function()        
        lineStatsGUI.filterToLinesOfType("ALL", toggleBtns)
    end)

    toggleBtns["ROAD"]:onToggle(function()
        lineStatsGUI.filterToLinesOfType("ROAD", toggleBtns)
    end)

    toggleBtns["TRAM"]:onToggle(function()
        lineStatsGUI.filterToLinesOfType("TRAM", toggleBtns)
    end)

    toggleBtns["RAIL"]:onToggle(function()
        lineStatsGUI.filterToLinesOfType("RAIL", toggleBtns)
    end)

    toggleBtns["WATER"]:onToggle(function()
        lineStatsGUI.filterToLinesOfType("WATER", toggleBtns)
    end)

    toggleBtns["AIR"]:onToggle(function()
        lineStatsGUI.filterToLinesOfType("AIR", toggleBtns)
    end)

    UIState.boxLayoutLines:addItem(menu.lineHeader,0,0)
end


---This filters the list of lines based on the line type
---@param typeOfLine string
function lineStatsGUI.filterToLinesOfType(typeOfLine, toggleButtons)
    UIState.lastSelectedFilter = typeOfLine

    if typeOfLine == "ALL" then
        for _,v in pairs(menu.lineTableItems) do
            v[1]:setVisible(true,false)
            v[2]:setVisible(true,false)
        end
    else
        local linesOfType = timetableHelper.isLineOfType(typeOfLine)
        for k,v in pairs(menu.lineTableItems) do
            if not(linesOfType[k] == nil) then
                v[1]:setVisible(linesOfType[k],false)
                v[2]:setVisible(linesOfType[k],false)
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


-------------------------------------------------------------
---------------------- Middle TABLE -------------------------
-------------------------------------------------------------

function lineStatsGUI.onLineSelected(index)
    -- initial checks
    if not index then return end
    if index ~= -1 then 
        UIState.lastSelectedLineTableIndex = index
    end

    local allLines = timetableHelper.getAllLines()
    if not(allLines[index+1]) then return end


    local lineId = allLines[index+1].id

    print("Selected LineId " .. lineId)
    UIState.lastSelectedLineId = lineId
    lineStatsGUI.fillStationTable(lineId)
end


function lineStatsGUI.fillStationTable(lineID)
    -- initial cleanup
    if not(menu.stationTable) then return end
    
    menu.stationTable:deleteAll()

      -- Cache the list of vehicles for use later
    vehicle2cargoMapCache = api.engine.system.simEntityAtVehicleSystem.getVehicle2Cargo2SimEntitesMap()

    local vehicleType = timetableHelper.getLineType(lineID)
    -- local lineFreq = timetableHelper.getFrequency(lineID)

    -- Header
    local passengerStats = lineStatsHelper.getPassengerStatsForLine(lineID)

    local lineFreqText = lineStatsHelper.getTimeStr(passengerStats.lineFreq)

    local lineStatsTxt = "Freq: " ..  lineFreqText .. " | Demand: " .. passengerStats.totalCount .. " | Cargo: " .. passengerStats.inVehCount .. "/" .. passengerStats.lineCapacity

    local header1 = api.gui.comp.TextView.new(lineStatsTxt)
    local header2 = api.gui.comp.TextView.new("")
    local header3 = api.gui.comp.TextView.new("Avg Wait")
    local header4 = api.gui.comp.TextView.new("Waiting: " .. passengerStats.waitingCount)
    local header5 = api.gui.comp.TextView.new("Journey")
    local header6 = api.gui.comp.TextView.new("")
    menu.stationTable:setHeader({header1,header2, header3, header4, header5, header6})

    --iterate over all stations to display them
    local stationsList = timetableHelper.getAllStations(lineID)
    local stationLegTimes = lineStatsHelper.getLegTimes(lineID)
    menu.lineImage = {}

    for stnIdx, stnId in pairs(stationsList) do

        -- Vehicles on Line image(s)
        local vehiclePositions = lineStatsHelper.getAggregatedVehLocs(lineID)
        local imageFile = uiUtil.getVehiclesOnSectionImageFile(vehiclePositions, stnIdx, vehicleType)
        menu.lineImage[stnIdx] = api.gui.comp.ImageView.new(imageFile)

        local count = 0
        local x = menu.lineImage[stnIdx]

        --  onStep is the update callback that is called in every step. (see: https://www.transportfever2.com/wiki/doku.php?id=modding:userinterface)
        menu.lineImage[stnIdx]:onStep(function()
            if not x then print("ERRROR") return end
            if not count then  print("ERRROR") return end

            -- This gets executed too frequently. This reduces it to roughly once every 3 seconds. Varies based on frame rate
            count = count + 1
            if count % 100 == 0 then
                local vehiclePositions2 = lineStatsHelper.getAggregatedVehLocs(lineID)
                local imageFile2 = uiUtil.getVehiclesOnSectionImageFile(vehiclePositions2, stnIdx, vehicleType)
                x:setImage(imageFile2, false)
            end
        end)

        local station = timetableHelper.getStationNameWithId(stnId)
        local nextStation
        if stationsList[stnIdx + 1] then
            nextStation = timetableHelper.getStationNameWithId(stationsList[stnIdx + 1] )
        else
            nextStation =  timetableHelper.getStationNameWithId(stationsList[1])
        end

        local stationNumber = api.gui.comp.TextView.new(tostring(stnIdx))

        stationNumber:setStyleClassList({"timetable-stationcolour"})
        stationNumber:setMinimumSize(api.gui.util.Size.new(30, 30))

        -- Station Col
        local lblStartStn = uiUtil.makeLocateText(station.id, station.name)
        local lblEndStn = uiUtil.makeLocateText(nextStation.id, "> " .. nextStation.name)
        local compStationNames =  uiUtil.makeVertical(lblStartStn, lblEndStn)

        -- Wait time col
        local lblAvgWaitTime = api.gui.comp.TextView.new(lineStatsHelper.getTimeStr(passengerStats.stopAvgWaitTimes[stnIdx]))

        -- Passenger Waiting col 
        local compTotalWaiting = uiUtil.makeIconText(tostring(passengerStats.peopleAtStop[stnIdx]), "ui/hud/cargo_passengers.tga")

        local compLongWait
        if (passengerStats.peopleAtStopLongWait[stnIdx] > 0) then
            compLongWait = uiUtil.makeIconText(tostring(passengerStats.peopleAtStopLongWait[stnIdx]), "ui/clock_small@2x.tga")
        else
            compLongWait = api.gui.comp.TextView.new("")
        end
        
        local compPplWaiting =  uiUtil.makeVertical(compTotalWaiting, compLongWait)

        -- Journey time column
        local lblJurneyTime
        if (stationLegTimes and stationLegTimes[stnIdx]) then
            lblJurneyTime = api.gui.comp.TextView.new(lineStatsHelper.getTimeStr(stationLegTimes[stnIdx]))
        else
            lblJurneyTime = api.gui.comp.TextView.new("")
        end
        
        menu.stationTable:addRow({stationNumber, compStationNames, lblAvgWaitTime, compPplWaiting, lblJurneyTime, menu.lineImage[stnIdx]})
    end


    lineStatsGUI.scrollToLastStationPosition(stationTableScrollOffset)
end

--- QOL: This selects/scrolls to the last selected station
function lineStatsGUI.scrollToLastStationPosition(offset)
    if UIState.lastSelectedStationIndex then
        if menu.stationTable:getNumRows() > UIState.lastSelectedStationIndex and not(menu.stationTable:getNumRows() == 0) then
            menu.stationTable:select(UIState.lastSelectedStationIndex, true) -- true to trigger event
        end
    end

    menu.stationScrollArea:invokeLater(function () 
        menu.stationScrollArea:invokeLater(function () 
            menu.stationScrollArea:setScrollOffset(offset) 
        end) 
    end)
end

-------------------------------------------------------------
---------------------- Right TABLE --------------------------
-------------------------------------------------------------
function lineStatsGUI.clearDetailsWindow()
    menu.detailsTable:deleteRows(1, menu.detailsTable:getNumRows())
end

function lineStatsGUI.fillDetailsTable(index, lineID)
    -- index is 0 based. Stop indexes are 1 based
    menu.detailsTable:deleteAll()
    local stopIdx = index+1
    local nextStopIdx = lineStatsHelper.getNextStop(lineID, stopIdx)
    if nextStopIdx == -1 then
        return
    end


    local lblEmpty = api.gui.comp.TextView.new("")
    local lblCompetingLInes = api.gui.comp.TextView.new("Competing Lines")
    menu.detailsTable:addRow({lblEmpty, lblCompetingLInes})

    local timesToStations = lineStatsHelper.getLineTimesFromStation(lineID, stopIdx)

    for _, timeToStn in pairs(timesToStations) do

        local station = timetableHelper.getStationNameWithId(timeToStn.toStationId) 
        local lblHeadFrom = api.gui.comp.TextView.new("To")
        local shortenedStnName = station.name
        if #shortenedStnName > 29 then
            shortenedStnName = string.sub(station.name, 1, 27) .. "..."
        end

        local lblHeadStnName = uiUtil.makeLocateText(station.id, shortenedStnName)
        

        menu.detailsTable:addRow({lblHeadFrom, lblHeadStnName})
        for _, competingLines in pairs(timeToStn.sortedTimes) do
            local elineId = competingLines.key
            local time = competingLines.value
            local lineName = timetableHelper.getLineName(elineId)
            local timeStr = lineStatsHelper.getTimeStr(time)

            local lblJurneyTime = api.gui.comp.TextView.new(timeStr)
            local shortenedLineName = lineName
            if #shortenedLineName > 33 then
                shortenedLineName = string.sub(shortenedLineName, 1, 30) .. "..."
            end
            local lblLineName = api.gui.comp.TextView.new(shortenedLineName)


            menu.detailsTable:addRow({lblJurneyTime, lblLineName})
        end

        local lblBlank1 = api.gui.comp.TextView.new("")
        local lblBlank2 = api.gui.comp.TextView.new("")
        menu.detailsTable:addRow({lblBlank1, lblBlank2}) 
    end
end



--- Displays all vehicles on the section in a table
function lineStatsGUI.fillVehTableForSection(index, lineId)
    -- index is 0 based. Stop indexes are 1 based
    local stopIdx = index+1
    
    if not(menu.lineVehTable) then return end
    menu.lineVehTable:deleteAll()
    
    local headerRow = api.gui.comp.TextView.new("Vehicles On Section")
    menu.lineVehTable:addRow({headerRow})

    local vehiclesForSection = lineStatsHelper.getVehiclesForSection(lineId, stopIdx)
    for _, vehicleId in pairs(vehiclesForSection) do
        local vehicleName = lineStatsHelper.getVehicleName(vehicleId)
        local vehiclePassengers = lineStatsHelper.getVehiclePassengerCount(vehicleId, vehicle2cargoMapCache)
        
        local vehicleLocateRow = uiUtil.makeLocateText(vehicleId, vehicleName .. " (" .. vehiclePassengers .. ")")
        menu.lineVehTable:addRow({vehicleLocateRow})
    end
end

-------------------------------------------------------------
--------------------- Main Entry ---------------------------------
-------------------------------------------------------------

local function createComponents() 
    -- element for the divider
    local line = api.gui.comp.Component.new("VerticalLine")
    local peoplestate = api.gui.comp.TextView.new("gameInfo.linestats.peopleLabel")
    

    local noOfPeople = api.engine.system.simPersonSystem.getCount()
    if peoplestate and noOfPeople then
        peoplestate:setText("Pop: " .. tostring(noOfPeople))
    end

    local buttonLabel = gui.textView_create("gameInfo.linestats.label", "Line Stats")
    local button = gui.button_create("gameInfo.lineStats.button", buttonLabel)
    button:onClick(function ()
        local err, msg = xpcall(lineStatsGUI.showLineMenu, err)
        if not err then
            menu.window = nil
            print(msg)
        end
    end)

    
    local resetAllTrainsLabel = gui.textView_create("gameInfo.linestats.resetTrainsLabel","Reset Trains In View")
    local resetButton = gui.button_create("gameInfo.lineStat.resetTrainsButton", resetAllTrainsLabel)
    resetButton:onClick(lostTrainsHelper.resetVisibleTrains)


    -- add elements to ui
    local gameInfoLayout = api.gui.util.getById("gameInfo"):getLayout()
    gameInfoLayout:addItem(line)
    game.gui.boxLayout_addItem("gameInfo.layout", button.id)
    game.gui.boxLayout_addItem("gameInfo.layout", resetButton.id)
    gameInfoLayout:addItem(peoplestate)
end


function data()
    return {
        --engine Thread
        guiInit = createComponents,
        guiUpdate = function()

        end
    }
end
