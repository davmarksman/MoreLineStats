local lineGui = require "lineGui"
local linesListGui = require "linesListGui"
local lostTrainsHelper = require "lostTrainsHelper"
local lineStatsHelper = require "lineStatsHelper"
local passengerChoice = require "passengerChoice"
local uiUtil = require "uiUtil"
local stationGui = require "stationGui"


-- state for passengerChoice
local state = {
    arrivalCounts = {}, -- [bucket][stationId][lineId][stopNo] = count
    lastUpdated = 0,
    startDate = {},
}

function data()
  return {
        -- Add More info button to every line window and station window
		guiHandleEvent = function(id, name, param)
            if name == "idAdded" and id:match("temp.view.entity_%d") then
                local entstr = id:gsub("temp.view.entity_","")
                local entId = tonumber(entstr)
                if not entId then
                    print(id,"No entity!")
                else
                    -- Line
                    if api.engine.getComponent(entId, api.type.ComponentType.LINE) then
                        -- TODO use function for if passenger line to determine if passenger line and add stats
                        local isPassenger = lineStatsHelper.isPassengerLine(entId)

                        if isPassenger == true then
                            local stWindow = api.gui.util.downcast(api.gui.util.getById(id))
                            if stWindow then
                                local lineBtn = lineGui.createLineButton(entId, "More Line Statistics")
                                stWindow:getContent():addItem(lineBtn,0,0)
                            end
                        end
                    -- Station
                    elseif api.engine.getComponent(entId,60) then
                        
                        -- print("Station. State updated at " .. state.lastUpdated)
                        -- print("Other: " .. getStateTime())
                        local stWindow = api.gui.util.downcast(api.gui.util.getById(id))
                        if stWindow then
                            local stationBtn = uiUtil.createButton("More Line Statistics")
                            local stationId = entId
                            stationBtn:onClick(function ()
                                local success, err = pcall(function () 
                                    stationGui.createGui(stationId, state)
                                end)
                                if err then
                                    print(err)
                                end
                            end)
                            stWindow:getContent():addItem(stationBtn,0,0)
                        end
                    end
                end
            end
        end,
        guiInit = function ()
            -- element for the divider
            local line = api.gui.comp.Component.new("VerticalLine")

            local buttonLabel = gui.textView_create("gameInfo.lineInfo.label", "More Line Statistics")
            local button = gui.button_create("gameInfo.lineInfo.button", buttonLabel)
            button:onClick(function ()
                local success, err = pcall(linesListGui.showLineList)
                if err then
                    print(err)
                end
            end)

            local resetAllTrainsLabel = gui.textView_create("gameInfo.lineInfo.resetTrainsLabel","Reset Trains In View")
            local resetButton = gui.button_create("gameInfo.lineInfo.resetTrainsButton", resetAllTrainsLabel)
            resetButton:onClick(lostTrainsHelper.resetVisibleTrains)

            -- add elements to ui
            local gameInfoLayout = api.gui.util.getById("gameInfo"):getLayout()
            gameInfoLayout:addItem(line)
            game.gui.boxLayout_addItem("gameInfo.layout", button.id)
            game.gui.boxLayout_addItem("gameInfo.layout", resetButton.id)
        end,
        guiUpdate  = function()
            passengerChoice.record(state)
        end
    }
end