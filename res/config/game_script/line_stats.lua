local lineStatsHelper = require "lineStatsHelper"
local timetableHelper = require "timetableHelper"
local uiUtil = require "uiHelper"

local gui = require "gui"

local menu = {window = nil, lineTableItems = {}}

local UIState = {
    currentlySelectedLineTableIndex = nil ,
    -- currentlySelectedStationTabStation = nil
}

local lineStatsGUI = {}

-- Search Constraint

local stationTableScrollOffset
local lineTableScrollOffset
local detailsTableScrollOffset

local function err(x)
	print("An error was caught",x)
	local traceback = debug.traceback()
	print(traceback)
 
end
-------------------------------------------------------------
---------------------- SETUP --------------------------------
-------------------------------------------------------------

function lineStatsGUI.initLineTable()
    print("initLineTable")
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
        if not index == -1 then UIState.currentlySelectedLineTableIndex = index end
        lineStatsGUI.fillStationTable(index)
    end)

    menu.lineTable:setColWidth(1,240)

    menu.scrollArea:setMinimumSize(api.gui.util.Size.new(300, 570))
    menu.scrollArea:setMaximumSize(api.gui.util.Size.new(300, 570))
    menu.scrollArea:setContent(menu.lineTable)

    lineStatsGUI.fillLineTable()

    UIState.boxLayoutLines:addItem(menu.scrollArea,0,1)
end

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
    menu.stationScrollArea:setMinimumSize(api.gui.util.Size.new(600, 600))
    menu.stationScrollArea:setMaximumSize(api.gui.util.Size.new(600, 600))

    menu.stationScrollArea:setContent(menu.stationTable)
    UIState.boxLayoutLines:addItem(menu.stationScrollArea,0.5,0)
end

function lineStatsGUI.initDetailsTable()
    if menu.scrollAreaDetails then
        local tmp = menu.scrollAreaDetails:getScrollOffset()
        detailsTableScrollOffset = api.type.Vec2i.new(tmp.x, tmp.y)
        UIState.boxLayoutLines:removeItem(menu.scrollAreaDetails)
    else
        detailsTableScrollOffset = api.type.Vec2i.new()
    end

    menu.scrollAreaDetails = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('scrollAreaDetails'), "lineStatsg.scrollAreaDetails")
    menu.detailsTable = api.gui.comp.Table.new(2, 'SINGLE')
    menu.detailsTable:setColWidth(0,60)

    menu.scrollAreaDetails:setMinimumSize(api.gui.util.Size.new(300, 600))
    menu.scrollAreaDetails:setMaximumSize(api.gui.util.Size.new(300, 600))
    menu.scrollAreaDetails:setContent(menu.detailsTable)
    UIState.boxLayoutLines:addItem(menu.scrollAreaDetails,1,0)
end


function lineStatsGUI.initLostTrainsTable()
    print("initLostTrainsTable")
    if menu.scrollAreaLostTrains then
        UIState.boxLayoutLost:removeItem(menu.scrollAreaLostTrains)
    end

    menu.scrollAreaLostTrains = api.gui.comp.ScrollArea.new(api.gui.comp.TextView.new('scrollAreaLostTrains'), "lineStatsg.scrollAreaLostTrains")
    menu.lostTrainsTable = api.gui.comp.Table.new(3, 'SINGLE')
    menu.lostTrainsTable:setColWidth(0,300)
    menu.lostTrainsTable:setColWidth(1,300)
    menu.lostTrainsTable:setColWidth(2,200)

    menu.scrollAreaLostTrains:setMinimumSize(api.gui.util.Size.new(1000, 600))
    menu.scrollAreaLostTrains:setMaximumSize(api.gui.util.Size.new(1000, 600))
    menu.scrollAreaLostTrains:setContent(menu.lostTrainsTable)

    lineStatsGUI.fillLostLines()

    UIState.boxLayoutLost:addItem(menu.scrollAreaLostTrains,0,1)
end


function lineStatsGUI.showLineMenu()
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
    lineStatsGUI.initDetailsTable()

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

    local lostVehicles = lineStatsHelper.FindLostVehicles()

    local lblCol1 = api.gui.comp.TextView.new("Line")
    local lblCol2 = api.gui.comp.TextView.new("Name")
    local lblCol3 = api.gui.comp.TextView.new("Time Since Departure")
    menu.lostTrainsTable:addRow({lblCol1, lblCol2,lblCol3 })

    if lostVehicles then
        for vehicleId, timeSinceDep in pairs(lostVehicles) do
            local vehicleName = lineStatsHelper.getVehicleName(vehicleId)
            local lineName = lineStatsHelper.getLineNameOfVehicle(vehicleId)
    
            local lblLineName = api.gui.comp.TextView.new(lineName)
            -- local lblVehicleName = api.gui.comp.TextView.new(vehicleName)
            local lblVehicleName = uiUtil.makeLocateRow(vehicleId, vehicleName)
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
    local sortAll   = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new("All"))
    local sortBus   = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_road_vehicles.tga"))
    local sortTram  = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/TimetableTramIcon.tga"))
    local sortRail  = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_trains.tga"))
    local sortWater = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_ships.tga"))
    local sortAir   = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new("ui/icons/game-menu/hud_filter_planes.tga"))

    menu.lineHeader:addRow({sortAll,sortBus,sortTram,sortRail,sortWater,sortAir})

    -- Col 1 line Names
    local lineNames = {}
    for k,v in pairs(timetableHelper.getAllLines()) do
        local lineDot = api.gui.comp.TextView.new("●")
        local lineName = api.gui.comp.TextView.new(v.name)
        lineNames[k] = v.name
        lineName:setName("lineStats-linename")

        menu.lineTableItems[#menu.lineTableItems + 1] = {lineDot, lineName}
        menu.lineTable:addRow({lineDot, lineName})
    end

    local order = timetableHelper.getOrderOfArray(lineNames)
    menu.lineTable:setOrder(order)

    -- Filter Functions
    sortAll:onToggle(function()
        for _,v in pairs(menu.lineTableItems) do
                v[1]:setVisible(true,false)
                v[2]:setVisible(true,false)
        end
        sortBus:setSelected(false,false)
        sortTram:setSelected(false,false)
        sortRail:setSelected(false,false)
        sortWater:setSelected(false,false)
        sortAir:setSelected(false,false)
        sortAll:setSelected(true,false)
    end)

    sortBus:onToggle(function()
        local linesOfType = timetableHelper.isLineOfType("ROAD")
        for k,v in pairs(menu.lineTableItems) do
            if not(linesOfType[k] == nil) then
                v[1]:setVisible(linesOfType[k],false)
                v[2]:setVisible(linesOfType[k],false)
            end
        end
        sortBus:setSelected(true,false)
        sortTram:setSelected(false,false)
        sortRail:setSelected(false,false)
        sortWater:setSelected(false,false)
        sortAir:setSelected(false,false)
        sortAll:setSelected(false,false)
    end)

    sortTram:onToggle(function()
        local linesOfType = timetableHelper.isLineOfType("TRAM")
        for k,v in pairs(menu.lineTableItems) do
            if not(linesOfType[k] == nil) then
                v[1]:setVisible(linesOfType[k],false)
                v[2]:setVisible(linesOfType[k],false)
            end
        end
        sortBus:setSelected(false,false)
        sortTram:setSelected(true,false)
        sortRail:setSelected(false,false)
        sortWater:setSelected(false,false)
        sortAir:setSelected(false,false)
        sortAll:setSelected(false,false)
    end)

    sortRail:onToggle(function()
        local linesOfType = timetableHelper.isLineOfType("RAIL")
        for k,v in pairs(menu.lineTableItems) do
            if not(linesOfType[k] == nil) then
                v[1]:setVisible(linesOfType[k],false)
                v[2]:setVisible(linesOfType[k],false)
            end
        end
        sortBus:setSelected(false,false)
        sortTram:setSelected(false,false)
        sortRail:setSelected(true,false)
        sortWater:setSelected(false,false)
        sortAir:setSelected(false,false)
        sortAll:setSelected(false,false)
    end)

    sortWater:onToggle(function()
        local linesOfType = timetableHelper.isLineOfType("WATER")
        for k,v in pairs(menu.lineTableItems) do
            if not(linesOfType[k] == nil) then
                v[1]:setVisible(linesOfType[k],false)
                v[2]:setVisible(linesOfType[k],false)
            end
        end
        sortBus:setSelected(false,false)
        sortTram:setSelected(false,false)
        sortRail:setSelected(false,false)
        sortWater:setSelected(true,false)
        sortAir:setSelected(false,false)
        sortAll:setSelected(false,false)
    end)

    sortAir:onToggle(function()
        local linesOfType = timetableHelper.isLineOfType("AIR")
        for k,v in pairs(menu.lineTableItems) do
            if not(linesOfType[k] == nil) then
                v[1]:setVisible(linesOfType[k],false)
                v[2]:setVisible(linesOfType[k],false)
            end
        end
        sortBus:setSelected(false,false)
        sortTram:setSelected(false,false)
        sortRail:setSelected(false,false)
        sortWater:setSelected(false,false)
        sortAir:setSelected(true,false)
        sortAll:setSelected(false,false)
    end)

    UIState.boxLayoutLines:addItem(menu.lineHeader,0,0)
    menu.scrollArea:invokeLater( function () menu.scrollArea:invokeLater(function () menu.scrollArea:setScrollOffset(lineTableScrollOffset) end) end)
end



-------------------------------------------------------------
---------------------- Middle TABLE -------------------------
-------------------------------------------------------------

-- params
-- index: index of currently selected line
function lineStatsGUI.fillStationTable(index)
    print("fillStationTable" .. index)
    --initial checks
    if not index then return end
    if not(timetableHelper.getAllLines()[index+1]) or (not menu.stationTable)then return end


    -- initial cleanup
    menu.stationTable:deleteAll()

    UIState.currentlySelectedLineTableIndex = index
    local lineID = timetableHelper.getAllLines()[index+1].id

    -- Header
    local passengerStats = lineStatsHelper.getPassengerStatsForLine(lineID)
    local lineStatsTxt = "Freq. " .. timetableHelper.getFrequency(lineID) .. "   Loaded: " .. passengerStats.inVehCount .. "/" .. passengerStats.totalCount

    local header1 = api.gui.comp.TextView.new(lineStatsTxt)
    local header2 = api.gui.comp.TextView.new("")
    local header3 = api.gui.comp.TextView.new("Avg Wait")
    local header4 = api.gui.comp.TextView.new("Total: " .. passengerStats.waitingCount)
    local header5 = api.gui.comp.TextView.new("Journey")
    local header6 = api.gui.comp.TextView.new("")
    menu.stationTable:setHeader({header1,header2, header3, header4, header5, header6})

    --iterate over all stations to display them
    local stationsList = timetableHelper.getAllStations(lineID)
    for k, v in pairs(stationsList) do
        menu.lineImage = {}
        local vehiclePositions = timetableHelper.getTrainLocations(lineID)
        if vehiclePositions[k-1] then
            if vehiclePositions[k-1].atTerminal then
                if vehiclePositions[k-1].countStr == "MANY" then
                    menu.lineImage[k] = api.gui.comp.ImageView.new("ui/timetable_line_train_in_station_many.tga")
                else
                    menu.lineImage[k] = api.gui.comp.ImageView.new("ui/timetable_line_train_in_station.tga")
                end
            else
                if vehiclePositions[k-1].countStr == "MANY" then
                    menu.lineImage[k] = api.gui.comp.ImageView.new("ui/timetable_line_train_en_route_many.tga")
                else
                    menu.lineImage[k] = api.gui.comp.ImageView.new("ui/timetable_line_train_en_route.tga")
                end
            end
        else
            menu.lineImage[k] = api.gui.comp.ImageView.new("ui/timetable_line.tga")
        end
        local x = menu.lineImage[k]
        menu.lineImage[k]:onStep(function()
            if not x then print("ERRROR") return end
            local vehiclePositions2 = timetableHelper.getTrainLocations(lineID)
            if vehiclePositions2[k-1] then
                if vehiclePositions2[k-1].atTerminal then
                    if vehiclePositions2[k-1].countStr == "MANY" then
                        x:setImage("ui/timetable_line_train_in_station_many.tga", false)
                    else
                        x:setImage("ui/timetable_line_train_in_station.tga", false)
                    end
                else
                    if vehiclePositions2[k-1].countStr == "MANY" then
                        x:setImage("ui/timetable_line_train_en_route_many.tga", false)
                    else
                        x:setImage("ui/timetable_line_train_en_route.tga", false)
                    end
                end
            else
                x:setImage("ui/timetable_line.tga", false)
            end
        end)

        local station = timetableHelper.getStationNameWithId(v)
        local nextStation
        if stationsList[k + 1] then
            nextStation = timetableHelper.getStationNameWithId(stationsList[k + 1] )
        else
            nextStation =  timetableHelper.getStationNameWithId(stationsList[1])
        end

        local stationNumber = api.gui.comp.TextView.new(tostring(k))

        stationNumber:setStyleClassList({"timetable-stationcolour"})
        stationNumber:setMinimumSize(api.gui.util.Size.new(30, 30))

        -- local lblStartStationName = api.gui.comp.TextView.new(station.name)
        -- lblStartStationName:setName("stationName")
        -- local lblEndStationName = api.gui.comp.TextView.new("-> " .. nextStation.name)
        -- lblEndStationName:setName("endStationName")

        -- Station Col
        local stationNameTable = api.gui.comp.Table.new(1, 'NONE')
        stationNameTable:addRow({uiUtil.makeLocateRow(station.id, station.name)})
        stationNameTable:addRow({uiUtil.makeLocateRow(nextStation.id, "-> " .. nextStation.name)})
        stationNameTable:setColWidth(0,260)

        -- Wait time col
        local lblAvgWaitTime = api.gui.comp.TextView.new(lineStatsHelper.getTimeStr(passengerStats.stopAvgWaitTimes[k]))

        -- Passenger Waiting col
        local waitPassengerTable = api.gui.comp.Table.new(2, 'SINGLE')
        waitPassengerTable:setColWidth(0,30)

        local personIcon = api.gui.comp.ImageView.new("ui/hud/cargo_passengers.tga")
        local lblPeopleWaiting = api.gui.comp.TextView.new(tostring(passengerStats.peopleAtStop[k]))
        waitPassengerTable:addRow({personIcon,lblPeopleWaiting})

        if(passengerStats.peopleAtStop[k] ~= passengerStats.peopleAtStop5m[k]) then
            local label5m = api.gui.comp.TextView.new("")
            local lblPeopleAtStop5m= api.gui.comp.TextView.new(tostring(passengerStats.peopleAtStop5m[k]))
            waitPassengerTable:addRow({label5m,lblPeopleAtStop5m})
        end

        -- Journey time column
        local stationLegTime = lineStatsHelper.getLegTimes(lineID)
        local lblJurneyTime
        if (stationLegTime and stationLegTime[k]) then
            lblJurneyTime = api.gui.comp.TextView.new(lineStatsHelper.getTimeStr(stationLegTime[k]))
        else
            lblJurneyTime = api.gui.comp.TextView.new("")
        end
        menu.stationTable:addRow({stationNumber,stationNameTable, lblAvgWaitTime,waitPassengerTable,lblJurneyTime, menu.lineImage[k]})
    end

    menu.stationTable:onSelect(function (tableIndex)
        if not (tableIndex == -1) then
            print("On Line click " .. lineID)
            lineStatsGUI.initDetailsTable()
            lineStatsGUI.fillDetailsTable(tableIndex,lineID)
        end

    end)


    menu.stationScrollArea:invokeLater(
        function () menu.stationScrollArea:invokeLater(
            function () menu.stationScrollArea:setScrollOffset(stationTableScrollOffset) end) end)
end


-------------------------------------------------------------
---------------------- Right TABLE --------------------------
-------------------------------------------------------------

function lineStatsGUI.clearDetailsWindow()
    menu.detailsTable:deleteRows(1, menu.detailsTable:getNumRows())
end

function lineStatsGUI.fillDetailsTable(index,lineID)
    -- index is 0 based
    print("FillDetailsTable: " ..  index .. " lineID: " .. lineID)
    --menu.lineTable:deleteRows(0,menu.lineTable:getNumRows())

    menu.detailsTable:deleteAll()
    
    local stations = timetableHelper.getAllStations(lineID)
    print(#stations)
    if index < 0 or index > #stations then
        return
    end

    local nextStationIdx = index+2
    if index == #stations -1 then
        nextStationIdx = 1
    end

    local timesForLinesBetweenStations = lineStatsHelper.getLineTimesBetweenStation(stations[index+1], stations[nextStationIdx])
    local sortedInfo = lineStatsHelper.sortByValues(timesForLinesBetweenStations)

    local lblEmpty = api.gui.comp.TextView.new("")
    local lblCompetingLInes = api.gui.comp.TextView.new("Competing Lines")
    menu.detailsTable:addRow({lblEmpty, lblCompetingLInes})
    for _, entity in pairs(sortedInfo) do
        local elineId = entity.key
        local time = entity.value
        local name = timetableHelper.getLineName(elineId)
        local timeStr = lineStatsHelper.getTimeStr(time)

        local lblJurneyTime = api.gui.comp.TextView.new(timeStr)
        local lblLineName = api.gui.comp.TextView.new(name)

        menu.detailsTable:addRow({lblJurneyTime, lblLineName})
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
        peoplestate:setText(tostring(noOfPeople))
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

    -- add elements to ui
    local gameInfoLayout = api.gui.util.getById("gameInfo"):getLayout()
    gameInfoLayout:addItem(line)
    game.gui.boxLayout_addItem("gameInfo.layout", button.id)
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
