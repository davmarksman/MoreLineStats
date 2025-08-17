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

This lightweight mod provides more statistic information about passenger lines. The motivation was to make managing running multiple passenger lines between the same stations easier

LINES
This shows show additonal stats about lines. Only useful for passenger lines:
- Average passenger waiting time
- How many passengers are waiting at a stop
- How many passengers have been waiting for longer than the line frequency (plus 1 minute in case of delays). Aka there was not enough space on the last vehicle for them
- Passengers travelling on the line vs waiting vs line capacity
- Leg times between stops
- Competing lines (speed is the biggest deciding factor for which lines passengers pick. This allows you to see lines competing for the same destinations and the time difference between them)
- Vehicles on line and where they are currently located

LOST TRAINS
- This mod provides a list of potentially lost trains. Trains are thought to be lost when they've been travelling for longer than 1.5x the maximum leg time or 3x the average leg time between stations
- You can reset trains. It's advised to reset trains in view after making station/track adjustments so the trains don't get lost in the first place (reseting trains reverses them 2x to recalculate their route)

OTHER
- This mod doesn't show any stats about cargo

CREDITS
- The ui and some helper functions are based off Celmi's Timetables mod
- The locate pins and functionality for that from is taken form statistics++ by okeating. Do check that out if you want more in-depth statistics
- Omegamezle for icons for each vehicle type

REPO
https://github.com/davmarksman/MoreLineStats

---
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