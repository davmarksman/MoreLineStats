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

This lightweight mod provides more statistic information about lines and detects lost trains. The motivation was to make managing running multiple passenger lines between the same stations easier

CORE FEATURES
- Find lost trains!
- Statistics about passenger and cargo lines
- Easy access from Line Window


LOST TRAINS
- This mod provides a list of potentially lost trains. Trains are thought to be lost when they've been travelling for longer than they should have taken to get to the next station
- You can reset trains. It's advised to reset trains in view, or trains on affected lines after making station/track adjustments so the trains don't get lost in the first place (reseting trains reverses them 2x to recalculate their route. Trains in stations are not reset)
- Multiple options to reset trains: Reset trains on a line from the lines's window, reset trains in view, reset all lost trains from the lost trains tab

LINES
This shows show additional stats about lines. This can be accessed from a line's window (more info button), or from the game bar. Only useful for passenger lines:
- Overview of all lines
- How many passengers/cargo are waiting at a stop
- How many passengers/cargo have been waiting for longer than the line frequency (Aka there was not enough space on the last vehicle for them)
- Passengers/cargo travelling on the line
- Passengers/cargo waiting
- Line Capacity
- Line & Sections demand (Similar to the Destinations data layer)
- Leg times between stops
- Distance between stops (This is as the crow flies - the most direct path between 2 stops)
- Average speeds (This is as the crow flies - the most direct path between 2 stops)
- Competing lines (speed is the biggest deciding factor for which lines passengers pick. This allows you to see lines competing for the same destinations and the time difference between them)
- Vehicles on line and where they are currently located


PERFORMANCE
The mod is designed to be performant:
- No background running tasks
- The most expensive operation is calculating the stats about all passenger or cargo lines. This is calculated whenever then the line menu is opened from the game bar. That said you can bypass this and access a line from the line's window which is faster:
- Accessing a line from the lines window only calculates stats for that line so it's pretty fast
- The stats are not live updating (apart from the vehicle locations which updates every apx 3-5 seconds). You can refresh the stats at will using the "Reload" button

CREDITS
- The ui and some helper functions are based off Celmi's Timetables mod
- The locate pins and functionality for that from is taken form statistics++ by okeating. Do check that out if you want more in-depth statistics
- Omegamezle for icons for each vehicle type

REPO
https://github.com/davmarksman/MoreLineStats

---
UPDATE 1.5
- Support for cargo lines

UPDATE 1.4
- Tooltips! and improved sorting

UPDATE 1.3
- Overview of all lines
- Open line stats from in-game line window
- Demand (passengers on line + waiting) & Average speeds


UPDATE 1.2
- Reset trains in view & reset lost trains
- Show cargo (passengers loaded/line capacity)
- Updated competing lines

UPDATE 1.1
- QOL, UX and usability fixes

]]),
		},
	}
end