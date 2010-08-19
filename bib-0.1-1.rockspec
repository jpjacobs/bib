package = "Bib"
version = "0.1-1"
source = {
	url = "http://jpjacobs.ulyssis.org/projects/bib/bib-0.1.tar.gz"
}
description = {
	summary = "A multilingual Integrated Library Management system.",
	detailed = [[
		A multilingual Integrated Library Management system based on Lua / Orbit
		with the following features:
			* Book management (multiple copies of a book allowed)
			* User management
			* Lendings / reservations
			* A nice web frontend
			* Easy translation by changing 1 file only
			* Uses SQLite3 -> no database server needed, easy backup of the db
		]],
	homepage = "http://jpjacobs.ulyssis.org/projects/bib",
	license = "MIT/X11",
	maintainer = "Jan-Pieter Jacobs (jpjacobs) <janpieter.jacobs@gmail.com>"
}
dependencies = {
	"lua >= 5.1",
	"markdown >= 0.32",
	"wsapi-xavante >= 1.3.4",
	"orbit >= 2.1.0",
	"luasql-sqlite3 >= 2.2.0",
}
build = {
	type= "builtin",
	modules = {
		bib = "bib.lua",
		["bib.admin"] = "bib/admin.lua",
		["bib.config"] = "bib/config.lua",
		["bib.trans"] = "bib/trans.lua",
	}
}
-- vim:ft=lua
