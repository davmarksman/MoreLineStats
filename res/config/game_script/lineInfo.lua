local lineGui = require "lineGui"
local linesListGui = require "linesListGui"
local lostTrainsHelper = require "lostTrainsHelper"
local lineStatsHelper = require "lineStatsHelper"

function data()
  return {
        -- Add More info button to every line window
		guiHandleEvent = function(id, name, param)
            if name == "idAdded" and id:match("temp.view.entity_%d") then
                local entstr = id:gsub("temp.view.entity_","")
                local entId = tonumber(entstr)
                if not entId then
                    print(id,"No entity!")
                else
                    if api.engine.getComponent(entId, api.type.ComponentType.LINE) then
                        -- TODO use function for if passenger line to determine if passenger line and add stats
                        print("LineId", entId)
                        local isPassenger = lineStatsHelper.isPassengerLine(entId)

                        if isPassenger == true then
                            local stWindow = api.gui.util.downcast(api.gui.util.getById(id))
                            if stWindow then
                                local lineBtn = lineGui.createLineButton(entId, "More Info")
                                stWindow:getContent():addItem(lineBtn,0,0)
                            end
                        end
                    end
                end
            end
        end,
        guiInit = function ()
            -- element for the divider
            local line = api.gui.comp.Component.new("VerticalLine")

            local buttonLabel = gui.textView_create("gameInfo.lineInfo.label", "Line Stats")
            local button = gui.button_create("gameInfo.lineInfo.button", buttonLabel)
            button:onClick(function ()
                -- linesListGui.showLineList()
                local success, err = pcall(linesListGui.showLineList)
                if err then
                    -- linesListGui.uiElems.window = nil
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
        end
    }
end