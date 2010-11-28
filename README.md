# Bib Integrated Library Management System

Bib is a multilingual, platform independant ILMS, written in [Lua](http://lua.org), using the
[Orbit](http://keplerproject.github.com/orbit/) MVC framework, and
[LuaRocks](http://www.luarocks.org) for packaging.

##Installation instructions

###Simple installation

	luarocks --from-server=http://jpjacobs.ulyssis.org/projects/rocks bib

### Complicated installation

Install LuaRocks for your platform, and the following rocks:

* wsapi-xavante
* orbit
* markdown
* luasql-sqlite

Extract the sources.

## Usage

In the bib-0.1 directory edit the bib/config.lua file to match your needs, and use the language of
your preference.

If you encounter weird errors, check the bib/lang.lua file for errors, or entries missing in the
current language (the english version remains the reference language). adding a language is as
simple as copying the english table to a new table, and translate each string.

If there is no file bib.db then run sqlite3 initDB.sql . 

Now run "orbit bib.lua" where orbit is the executable that comes with the orbit rock.

Making a shortcut executing this command would be handy.

Point your Browser to http://localhost:8080, default password for admin is admin, just add books as
needed etc etc.

## Disclaimer

This piece of software is far from finished, and far from glitch free. Don't rely on it for serious
stuff. Don't say I didn't warn you ...


