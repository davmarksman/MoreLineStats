function data()
	return {
		info = {
			name = _("More Line Statistics"),
			minorVersion = 0,
			severityAdd = "NONE",
			severityRemove = "WARNING",
			params = { },
			tags = { "Script Mod","Script", "Statistics",  },
			authors = { -- OPTIONAL one or multiple authors
				{
					name = "Bottle", -- author name
					role = "CREATOR", -- OPTIONAL "CREATOR", "CO_CREATOR", "TESTER" or "BASED_ON" or "OTHER"
				}
			},
			description = _([[ 
More Line statistics!

This lightweight mod provides more statistic information about passenger lines and detects lost trains. The motivation was to make managing multiple passenger lines between the same stations easier

CORE FEATURES
- Find lost trains!
- Statistics about passenger lines
- Easy access from ingame Line Window


LOST TRAINS
- This mod provides a list of potentially lost trains. Trains are thought to be lost when they've been travelling for longer than they should have taken to get to the next station
- You can reset trains. It's advised to reset trains in view, or trains on affected lines after making station/track adjustments so the trains don't get lost in the first place (reseting trains reverses them 2x to recalculate their route. Trains in stations are not reset)

LINES
This shows show additional stats about lines. This can be accessed from a line's window (more info button), or from the game bar. Only useful for passenger lines:
- Overview of all lines
- How many passengers are waiting at a stop
- How many passengers have been waiting for longer than the line frequency (Aka there was not enough space on the last vehicle for them)
- Passengers travelling on the line
- Passengers waiting
- Line Capcity
- Line & Sections demand (Similar to the Destinations data layer)
- Leg times between stops
- Distance between stops
- Average speeds (This is as the crow flies - the most direct path between 2 stops)
- Competing lines (speed is the biggest deciding factor for which lines passengers pick. This allows you to see lines competing for the same destinations and the time difference between them)
- Vehicles on line and where they are currently located

OTHER
- This mod doesn't show any stats about cargo

PERFORMANCE
The mod is designed to be performant:
- No background running tasks
- The most expensive operation is calculating all passenger lines. This is calculated whenever then the line menu is opened from the game bar. That said you can bypass this and access a line from the line's window which is very fast:
- Accessing a line from the lines window only calculates stats for that line so it's pretty fast 
- The stats are not live updating (apart from the vehicle locations which updates every apx 3-5 seconds). You can refresh stats at will using the "Refresh" button

CREDITS
- The ui and some helper functions are based off Celmi's Timetables mod
- The locate pins and functionality for that is taken form statistics++ by okeating. Do check that out if you want more in-depth statistics
- Omegamezle for icons for each vehicle type

REPO
https://github.com/davmarksman/MoreLineStats

---
UPDATE 1.3
- Overview of all lines
- Open line stats from in-game line window
- Line/Section demand
- Line/Section speeds
- Better lost trains functionality
- Complete UI rewrite


UPDATE 1.2
- Ability to reset trains in view & reset lost trains
- Vehicles on line section now shows the number of passengers on each vehicle
- New icons
- Show cargo (passengers loaded/line capacity) and demand (all passengers currently on the line)
- Update competing lines to show competing lines for each stop from the currently selected stop

UPDATE 1.1
- Change from "How many passengers arrived within the last 5 minutes" to "Passengers waiting longer than Line frequency"
- Added a list of Vehicles on the line
- QOL, UX and usability fixes
 

]]),
		},
	}
end