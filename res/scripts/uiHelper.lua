
local uiUtil = {}

---Locate pin for a component such as a station, person, or vehicle next to the name of the component
---@param componentId any
---@param componentName any
---@param includeFollowCam any
---Locate pin and text
function uiUtil.makeLocateText(componentId, componentName, includeFollowCam)
	local imageView = api.gui.comp.ImageView.new("ui/button/xxsmall/locate.tga")
	local button = api.gui.comp.Button.new(imageView, true)
	button:onClick(function() 
		local rendererComp = api.gui.util.getGameUI():getMainRendererComponent():getCameraController()
		if includeFollowCam then 
			rendererComp:follow(componentId, false)
		else 
			rendererComp:focus(componentId, false)
		end
	end)
	local textView = api.gui.comp.TextView.new(componentName)

	return uiUtil.makeHorizontal(button, textView)
end

-- cargo_citrusfruit@2x.tga
--- Text next to a icon
---@param text string
---@param iconLoc string
---returns text next to a  icon
function uiUtil.makeIconText(text, iconLoc)
	local personIcon = api.gui.comp.ImageView.new(iconLoc)
	personIcon:setMaximumSize(api.gui.util.Size.new( 40, 40 ))
	return uiUtil.makeHorizontal(personIcon, api.gui.comp.TextView.new(text))
end	

---Lays out 2 ui component in a vertical layout (one below the other)
---@param item1 any
---@param item2 any
---Lays out 2 items in a vertical layout
function uiUtil.makeVertical(item1, item2)
	local vertLayout = api.gui.layout.BoxLayout.new("VERTICAL")
	return uiUtil.createComp(vertLayout, item1, item2)
end	

---Lays out 2 ui component in a vertical layout (one below the other)
---@param item1 any
---@param item2 any
---Lays out 2 items in a vertical layout
function uiUtil.makeHorizontal(item1, item2)
	local horizontalLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
	return uiUtil.createComp(horizontalLayout, item1, item2)
end	


function uiUtil.createComp(layout,item1, item2)
	layout:addItem(item1)
	layout:addItem(item2)
	local comp =  api.gui.comp.Component.new("")
	comp:setLayout(layout)
	return comp
end

return uiUtil