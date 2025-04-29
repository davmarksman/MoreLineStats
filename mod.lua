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
- Passengers travelling on the line vs waiting
- Leg times between stops
- Competing lines (speed is the biggest deciding factor for which lines passengers pick. This allows you to see if a line is faster and therefore getting a higher share of passengers. I've noticed that the platform chosen on larger stations can have a noticable impact.)
- Vehicles on line

LOST TRAINS
This provides a list of potentially lost trains. Trains are thought to be lost when they've been travelling for longer than 1.5x the maximum leg time or 3x the average leg time between stations

OTHER
- This mod doesn't show any stats about cargo

CREDITS
- The ui and some helper functions are based off Celmi's Timetables mod
- The locate pins and functionality for that from is taken form statistics++ by okeating. Do check that out if you want more in-depth statistics
- Omegamezle for icons for each vehicle type

REPO
https://github.com/davmarksman/MoreLineStats

FUTURE PLANS
- Icons for each transport mode. Thanks to omegamezle/Mezzie
- Future plans include showing the rate of change at stops which will provide a line rate vs demand estimate
- Let me know in the comments if you encounter any issues or would like to add any feature requests. 

---

UPDATE 1.1
- Change from "How many passengers arrived within the last 5 minutes" to "Passengers waiting longer than Line frequency"
- Added a list of Vehicles on the line
- QOL, UX and usability fixes
 

]]),
		},
	}
end