
local uiUtil = {}

function uiUtil.makeStationLocateRow(stationId, stationName, includeFollowCam)
	local boxLayout =  api.gui.layout.BoxLayout.new("HORIZONTAL");
	local imageView = api.gui.comp.ImageView.new("ui/button/xxsmall/locate.tga")
	local button = api.gui.comp.Button.new(imageView, true)
	button:onClick(function() 
		local rendererComp = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()
		if includeFollowCam then 
			rendererComp:follow(stationId, false)
		else 
			rendererComp:focus(stationId, false)
		end
	end)
	boxLayout:addItem(button)

	boxLayout:addItem(api.gui.comp.TextView.new(stationName)) -- NB the stationGroup is required if there station was renamed
	local comp= api.gui.comp.Component.new("")
	comp:setLayout(boxLayout)
	return comp
end


return uiUtil