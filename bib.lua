#! /usr/bin/env lua
--- Bib is an Integrated Library Management System, build with <a href="http://keplerproject.github.com/orbit/">Orbit</a>
-- and <a href="http://www.luarocks.org/">LuaRocks</a>
-- It's build to be easy to deploy, manage, use and customize.
--
-- Bib es una sistema de gestion de biblioteca integrada, construido con <a href="http://keplerproject.github.com/orbit/">Orbit</a>
-- and <a href="http://www.luarocks.org/">LuaRocks</a>. Esta construido para ser facil en instalación, utilización, gestión y personalisación.
-- @release 0.1
-- @usage ./orbit bib.ws

require "luarocks.require"	-- Working with Luarocks
require "orbit"				-- uses orbit
require "orbit.cache"		-- ... and it's caching module
require "markdown"			-- we'll use markdown for marking up contents
require "cosmo"				-- for templatematching

module("bib", package.seeall, orbit.new)

-- Load the config file bib/config.lua / Carga el archivo de configuración bib/config.lua
require "bib.config"

-- Load and connect the database / Carga la base de datos y conectase
require("luasql." .. database.driver)
local env = luasql[database.driver]()

-- Make the mapper use this database by default / Hace que el mapper utilize esta base de datos por defecto
mapper.conn = env:connect(unpack(database.conn_data))
mapper.driver = database.driver

-- Define the models to be used / Definir los modeles necesarios
models = {
	book = bib:model "book",
	copy = bib:model "copy",
	author = bib:model "author",

	user = bib:model "user",
	loan = bib:model "loan",
	reservation = bib:model "reservation",

	tag = bib:model "tag",
	taglink = bib:model "taglink"
	-- TODO: Add E-library models
}

cache = orbit.cache.new(bib, cache_path)

-- Methods for the Book model / Métodos para el model "book"
--- Returns the most recently added books
function models.book:find_recent(num)
	local num = num or 10
	return models.copy:find_first("BookID = ?",{self.id, order="DateAquisition asc",count=num}).BookID
end

--- General search function
-- @params term Term for which to search
-- @params criterium Field in which to look for term
-- @params orderby Field by which to order the returned list
-- @params order Which sense the list should be ordered: asc or desc
function models.book:find_gen(term,criterium,orderby,order,num)
	local criterium = criterium or "Title"
	local orderby = orderby or "Title"
	local order = order or "asc"
	local num = num or 10
	return models.book[find_by_..crit](self,crit.." = ?",{term, order=orderby.." "..order, count=num})
end

--- Finds all copies of of this book.
function models.book:find_copies()
	return models.copy:find_by_BookID{self.id}
end

-- Methods for the copy model / Métodos para el model "copy"

-- Methods for the author model / Métodos para el model "model"

-- Methods for the user model / Métodos para el model "user"

-- Methods for the loan model / Métodos para el model "loan"

-- Methods for the reservation model / Métodos para el model "reservation"

-- Methods for the tag model / Métodos para el model "tag"

-- Methods for the taglink model / Métodos para el model "taglink"

---- Initialize the template cache / Antememoria de patrones
--local template_cache = {}
--
----- Loads a template from the template directory
---- @params name Name of the template
--function load_template(name)
--   local template = template_cache[name]
--   if not template then
--      local template_file = io.open(bib.real_path .. "/templates/" ..
--				    template_name .. "/" .. name, "rb")
--      if template_file then
--  	 template = cosmo.compile(template_file:read("*a"))
--	 template_cache[name] = template
--	 template_file:close()
--      end
--   end
--   return template
--end
--	
----- Loads a plugin from the plugin directory
---- @params name Name of the plugin
--function load_plugin(name)
--  local plugin, err = loadfile("plugins/" .. name .. ".lua")
--  if not plugin then
--    error("Error loading plugin " .. name .. ": " .. err)
--  end
--  return plugin
--end
--
----- Creates a new template environnement
---- @params web web object to be the host of the template
--function new_template_env(web)
--  local template_env = {}
--
--  template_env.template_vpath = template_vpath or web:static_link("/templates/" .. template_name)
--  template_env.today = date(os.time())
--  template_env.home_url = web:link("/")
--  template_env.home_url_xml = web:link("/xml")
--
--  function template_env.import(arg)
--    local plugin_name = arg[1]
--    local plugin = plugins[plugin_name]
--    if not plugin then
--      plugin = load_plugin(plugin_name)
--      plugins[plugin_name] = plugin
--    end
--    for fname, f in pairs(plugin(web)) do
--      template_env[fname] = f
--    end
--    return ""
--  end
--
--  return template_env
--end

-- Views for the application / Views para la aplicación
function layout(web, args, inner_html)
return html{
	head{
		title(blog_title),
		meta{ ["http-equiv"] = "Content-Type",
		content = "text/html; charset=utf-8" },
		--link{ rel = 'stylesheet', type = 'text/css', href = web:static_link('/style.css'), media = 'screen' }
	},
	body{
		div{ id = "container",
			div{ id = "header", title = "sitename" },
			div{ id = "mainnav",
				_menu(web, args)
			}, 
			div{ id = "menu",
				_sidebar(web, args)
			},  
			div{ id = "contents", inner_html },
			div{ id = "footer", copyright_notice }
		}
	}
} 
end

-- for using as inner html on the indexpage.
--		div{ id = "searchbox",
--			fieldset{
--				legend{""},
--				form{
--					input{}
--				}
--			}
--		}

function index(web)
   local book_rec = book:find_recent()
   local pgs = pgs or pages:find_all()
   return render_index(web, { books = book_rec })
end

blog:dispatch_get(cache(index), "/", "/index") 
