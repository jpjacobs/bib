#! /usr/bin/env lua
--- Bib is an Integrated Library Management System, build with <a href="http://keplerproject.github.com/orbit/">Orbit</a>
-- and <a href="http://www.luarocks.org/">LuaRocks</a>
-- It's build to be easy to deploy, manage, use and customize.
--
-- Copyright (c) 2010 Jan-Pieter Jacobs
--
-- Permission is hereby granted, free of charge, to any
-- person obtaining a copy of this software and associated
-- documentation files (the "Software"), to deal in the
-- Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the
-- Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice
-- shall be included in all copies or substantial portions of
-- the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
-- KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
-- OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
-- OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
--
-- Bib es una sistema de gestion de biblioteca integrada, construido con <a href="http://keplerproject.github.com/orbit/">Orbit</a>
-- and <a href="http://www.luarocks.org/">LuaRocks</a>. Esta construido para ser facil en instalación, utilización, gestión y personalisación.
--
-- Copyright (c) 2010 Jan-Pieter Jacobs
--
-- Se autoriza, de forma gratuita, a cualquier
-- persona que ha obtenido una copia de este software y 
-- archivos asociados de documentación (el "Software"), para tratar en el
-- Software sin restricción, incluyendo sin ninguna limitación en lo que concierne
-- los derechos para usar, copiar, modificar, fusionar, publicar,
-- distribuir, sublicenciar, y / o vender copias de este
-- Software, y para permitir a las personas que usan el Software para 
-- hacerlo, con sujeción a las siguientes condiciones:
--
-- El aviso de copyright anterior y este aviso de permiso
-- se incluirá en todas las copias o partes sustanciales de
-- este Software.
--
-- EL SOFTWARE SE ENTREGA "TAL CUAL", SIN GARANTÍA DE NINGÚN
-- TIPO, EXPRESA o implícita, no limitado a la GARANTÍAS DE
-- COMERCIALIZACIÓN, CAPACIDAD DE HACER Y DE NO INFRACCIÓN DE COPYRIGHT. EN NINGÚN 
-- CASO LOS AUTORES O TITULARES DEL COPYRIGHT SERÁN RESPONSABLES DE 
-- NINGUNA RECLAMACIÓN, daños o OTRAS RESPONSABILIDADES, 
-- YA SEA EN UN LITIGIO, agravio o DE OTRO MODO, 
-- DERIVADAS DE, FUERA DE O EN CONEXION CON EL
-- SOFTWARE SU UTILIZACIÓN U OTRAS OPERACIONES EN EL SOFTWARE.
--
-- @release 0.1
-- @usage ./orbit bib.ws

-- debug hook
local function memusage()
	print("--debug Using ",collectgarbage("count"),"Kb of memory")
end
--debug.sethook(memusage,"c")

require "luarocks.require"	-- Working with Luarocks
require "orbit"				-- uses orbit
require "orbit.cache"		-- ... and it's caching module
require "markdown"			-- we'll use markdown for marking up contents
require "cosmo"				-- for templatematching

module("bib", package.seeall, orbit.new)

-- Load the config file bib/config.lua / Carga el archivo de configuración bib/config.lua
require "bib.config"
require "bib.admin"

-- Load and connect the database / Carga la base de datos y conectase
require("luasql." .. database.driver)
local env = luasql[database.driver]()

-- Make the mapper use this database by default / Hace que el mapper utilize esta base de datos por defecto
mapper.conn = env:connect(unpack(database.conn_data))
mapper.driver = database.driver

-- SQL query sanitation and un-sanitation functions
--	local sanitize_tab={"select","drop","insert","delete","update","create","pragma","alter"}
--- Utility function to check whether a user is a user
function check_user(web)
	local auth = web.cookies.authentication		-- Get the authentication cookie
	if auth then
		local login,auth_hash =auth:match("(%w*)||(%d*)")	-- parse the username and auth-hash (random number that get's saved to the DB for each user)
		local user = models.user:find_by_login{ login }		-- check whether the user exists
		if (user and auth_hash ~= user.auth) then			-- if the auth-hash does not match the saved one (forged or old cookie) -> delete it
			-- Notice: Firefox does not delete cookies with the cookie window open (don't panic if the cookie does not instantly vanish).
			web:delete_cookie("authentication")
		end
		return models.user:find_by_login_and_auth{ login, auth_hash }
	else
		return nil
	end
end


-- Define the models to be used / Definir los modeles necesarios
models = {
	page = bib:model "page",
	cat = bib:model "cat",
	book = bib:model "book",
	copy = bib:model "copy",
	author = bib:model "author",

	user = bib:model "user",
	center = bib:model "center",
	lending = bib:model "lending",
	reservation = bib:model "reservation",

	tag = bib:model "tag",
	taglink = bib:model "taglink"
	-- Add E-library models: Will be implemented as simple books, with the url reffering to the resource.
}
-- Methods for all models / Métodos para todos modelos
do -- Only put the functions in the model
	--- Makes an index out of a model
	-- @return ret a table containing a list of letters, containing the number of
	local function index(self,field)
		local ret={}
		local query=("SELECT COUNT(id) FROM %s WHERE %s LIKE '%%s%%%%';"):format(self.table_name,field)
		for k=97,122 do
			local cur_letter = string.char(k)
			local number = bib.mapper.conn:execute(query:format(cur_letter)):fetch()
			if number > 0 then
				ret[cur_letter] = number
			end
		end
		return ret
	end
	-- Install method to all models / Instalar método a todos modelos
	for k,v in pairs(models) do
		v.index=index
	end
end

-- Form information for different models, used to build the edit forms and pars edit POST info. The format is straight forward.
-- title is the field of the model used as in the page title
-- fields is a table containing info for each field that will be editable by the administrator
-- Each field in turn consists of:
--		name 	: name of the field as used in the db/model
--		caption	: the string that will be place before the field (typically coming from strings) 
--		type	: type of the input (notice the [" "] because type is a keyword in lua). currently supported are:
--			text		: Single line text input
--			textarea	: multiline text input, which will be markdowned afterwards
--			select		: drop-down selection box having 2 usages:
--				1) provided a model, will supply id's for all items in the model, using {fields} as fields for displaying in the options
--				2) provided a table of options, in order which can be selected (no option to change display value to other than the actual value in the DB. Will be added if needed)
--			file		: upload a file + select url (TODO to be implemented)
--
models.book.form={
	title="title",
	fields = {
		{name="title",caption=strings.title,["type"]="text"},
		{name="author_id",caption=strings.author,["type"]="select",model=models.author,fields={"rest_name","last_name","id"}}, --TODO Make these fields autocomplete, and add a "new ... " link style drupal autocomplete for authors and tags
		{name="cat_id",caption=strings.category,["type"]="select",model=models.cat,fields={"cat_text","id"}},
		{name="isbn",caption=strings.isbn,["type"]="text"},
		{name="abstract",caption=strings.abstract,["type"]="textarea"},
		{name="url_ref",caption=strings.url_ref,["type"]="text"},
		{name="url_cover",caption=strings.url_cover,["type"]="text"}
	}
}

models.cat.form={
	title="cat_text",
	fields={{name="cat_text",caption=strings.category,["type"]="text"}}
}

models.tag.form={
	title="tag_text",
	fields={{name="tag_text",caption=strings.tag,["type"]="text"}}
}
models.page.form={
	title="title",
	fields = {
		{name="title",caption=strings.title,["type"]="text"},
		{name="body",caption=strings.body,["type"]="textarea"}
	}
}
models.author.form={
	title="last_name",
	fields = {
		{name="last_name",caption=strings.last_name,["type"]="text"},
		{name="rest_name",caption=strings.rest_name,["type"]="text"},
		{name="url_ref",caption=strings.url_ref,["type"]="text"}
	}
}
models.copy.form={
	title="id",
	fields = {
		{name="book_id",caption=strings.book,["type"]="select",model=models.book,fields={"title","id"}},
		{name="date_acquisition",caption=strings.date_acquisition,["type"]="text"},
		{name="edition",caption=strings.edition, ["type"]="text"},
		{name="price",caption=strings.price,["type"]="text"}
	}
}
models.user.form={
	title="login",
	fields = {
		{name="login",caption=strings.login,["type"]="text"},
		--{name="password",caption=strings.password,["type"]="password"},
		{name="is_admin",caption=strings.admin,["type"]="select",options={0,1}},
		{name="center_id",caption=strings.center,["type"]="select",model=models.center,fields={"name","id"}},
		{name="telephone",caption=strings.telephone,["type"]="text"},
		{name="email",caption=strings.email,["type"]="text"}, -- verify if it's a unique email in the db.
		{name="debt",caption=strings.debt,["type"]="text"}
	}
}
models.center.form={
	title="name",
	fields = {
		{name="name",caption=strings.name,["type"]="text"},
		{name="center_id",caption=strings.subcenter_of,["type"]="select",model=models.center,fields={"name","id"}},
		{name="address",caption=strings.address,["type"]="textarea"},
		{name="contact",caption=strings.contact_person,["type"]="textarea"},
		--{name="logo",caption=strings.logo,["type"]="text"} --TODO not implemented
	}
}

cache = orbit.cache.new(bib, cache_path) -- No longer used: pages where username get's displayed can't be cached.
-- Methods for the page model / Métodos para el model "page"
--- Updates a pages body_html from the markdown version body
function models.page.update_html(page,force)
	if page.body_html == "" or force then -- first time
		page.body_html = markdown(page.body)
		page:save()
	end
	return page
end

-- Methods for the Book model / Métodos para el model "book"
--- Updates a books abstract_html from the markdown version abstract
function models.book.update_html(book,force)
	if book.abstract_html == "" or force then -- first time
		book.abstract_html = markdown(book.abstract)
		book:save()
	end
	return book
end
	
--- Add's lot's of data from other models to the book to be returned.
function models.book.pimp(book)
		book.author_rest_name = models.author:find(book.author_id).rest_name
		book.author_last_name = models.author:find(book.author_id).last_name
		-- Explication of next query: find all tags corresponding to this book: find all links, matching this book, and
		-- inject the tag_text to which they point. However, we don't need any data from taglink self, so fields={}. We do
		-- need the tag_text, so inject it from tags.
		local ret = models.taglink:find_all("book_id = ?",{book.id, fields={"tag_tag_text"}, inject={ model=models.tag, fields={"tag_text"}},fields={}})
		local tags = {}
		for k=1,#ret do
			tags[#tags+1]=ret[k].tag_tag_text
		end
		book.tags=tags
		book.ncopies=#(models.copy:find_all_by_book_id({book.id})) -- TODO Add support for lend books.
		book.cat = models.cat:find(book.cat_id).cat_text
		book:update_html() -- updates html version of page if necessary.
end
	
--- Returns the most recently added books, while adding all info needed (like Authors, tags, copies, ...)
function models.book:find_recent(num)
	local num = num or 10
	local copies=models.copy:find_all("",{nil,order="date_acquisition desc",count=num,fields={"book_id","date_acquisition"}})
	-- Will contain true for books[book_id] will containt the acquisition date if it's in the list of recently acquired copies
	-- Contenera la fecha de procuración para books[book_id] si book_id esta en uno de los ejemplares recien procurado.
	local books,dates={},{}
	for k=#copies,1,-1 do -- back to forth : need most recent books. / detras adelante: querimos los libros recientos
		local cc=copies[k]
		dates[cc.book_id]=cc.date_acquisition
	end
	for k,v in pairs(dates) do	-- use book_id's in dates to build the array of books to be fetched 
		books[#books+1]=k		-- utiliza book_id en dates para construir la lista de libros para estar retornado
	end

	local ret=models.book:find_all("id = ?",{books}) -- Fetch books / buscar libros
	for k,v in pairs(ret) do
		local cur_book_id=v.id
		models.book.pimp(v)
		v.date_acquisition = dates[cur_book_id]	-- Include an acquisition date field / incluye un campo de fecho de compra
	end
		
	return ret
end

--- General search function
-- @params term Term for which to search
-- @params criterium Field in which to look for term
-- @params orderby Field by which to order the returned list
-- @params order Which sense the list should be ordered: asc or desc
function models.book:find_gen(term,criterium,orderby,order,num)
	print("find_gen not implemented")
end

--- Finds all copies of of this book.
-- Deprecated does not get used TODO
function models.book:find_copies()
	return models.copy:find_by_book_id{self.id}
end

-- Methods for the copy model / Métodos para el model "copy"

-- Methods for the author model / Métodos para el model "model"
-- Methods for the user model / Métodos para el model "user"

-- Methods for the lending model / Métodos para el model "lending"

-- Methods for the reservation model / Métodos para el model "reservation"

-- Methods for the tag model / Métodos para el model "tag"

-- Methods for the taglink model / Métodos para el model "taglink"

--{{{-- -- Initialize the template cache / Antememoria de patrones
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
--end --}}}


-- Controllers : gets the data together
--- Controller for the index page
-- Get's together the most recent books and pages, and put's them in a list
function index(web) --{{{
   local books_rec = models.book:find_recent()
   local pgs = pgs or models.page:find_all()
   local user = check_user(web)
   return render_index(web, { books = books_rec, pages = pgs, user=user})
end --}}}

bib:dispatch_get(index, "/", "/index") 

--- Controller for the static pages. Get's the page and user, and displays the page if it exists
function view_page(web, page_id) --{{{
	local page = models.page:find(tonumber(page_id))
	local user = check_user(web)
	if page then
		page:update_html() -- updates html from the markdown in body if necessary.
		local pgs = models.page:find_all()
		return render_page(web, { pages=pgs, page = page, user=user })
	else
		not_found(web)
	end
end --}}}

bib:dispatch_get(view_page, "/page/(%d+)")

--- Controller for the Search page. 
function search_results(web) --{{{
	-- GET parameters from the web object
	local field_possible = {title="title",author="author",isbn="isbn",tag="tag",abstract="abstract"}

	local c = field_possible[web.input.c:lower()] or "title"-- The search criterium
	local q = web.input.q:gsub("'","''") -- The search query, aka search term TODO : optimize sanitation
	local limit = tonumber(web.input.limit) 
	limit = limit and limit >= 0 or 10 -- The maximum number of results to return (number or nil)
	local offset = tonumber(web.input.offset)
	offset = offset and offset >=0 or 0 -- The offset from book 0 (number or nil)
	local order = web.input.order or "ASC" -- The order ASC or DESC
	if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
		order = "ASC"
	end
	local orderby = field_possible[web.input.orderby:lower()] or "title"

	local conn = models.book.model.conn -- This will be the connection to make the more complex SQL calls
	local pgs = pgs or models.page:find_all()
	local books_result = {}
	local user = check_user(web)
	local curs,err
	-- Check for all cases that the search criterium can be in (Explications of the SQL below).
	-- This initializes a cursor object which will be used to fetch the books.
	if c == "title" then
		-- Select  where title is like the search term
		curs,err = conn:execute(([[SELECT * FROM bib_book WHERE title LIKE '%%%s%%' ORDER BY %s %s LIMIT %d OFFSET %d;]]):format(q,orderby,order,limit,offset))
	elseif c == "author" then
		-- Select the authors that correspond (first or rest of name) to the searchterm, and match that to the book with a JOIN)
		curs,err = conn:execute(([[SELECT bib_book.* FROM bib_book, bib_author WHERE (bib_author.last_name LIKE '%%%s%%' OR bib_author.rest_name LIKE '%%%s%%') AND bib_book.author_id = bib_author.id ORDER BY %s %s LIMIT %d OFFSET %d;]]):format(q,q,orderby,order,limit,offset))
	elseif c == "isbn" then
		-- Select books by isbn, but only return exact matches (other don't have much meaning) and remove any - or space that may have been in the queried ISBN
		curs,err = conn:execute(([[SELECT * from bib_book WHERE isbn = '%s' ORDER BY %s %s LIMIT %d OFFSET %d;]]):format(q:gsub('[- ]+',''),orderby,order,limit,offset))
	elseif c == "tag" then
		-- Select the right tag from bib_tag, match it to books in bib_taglink, and get the info from the  books that have these tags applied.
		curs,err = conn:execute(([[SELECT bib_book.* FROM bib_tag,bib_taglink,bib_book WHERE bib_tag.tag_text LIKE '%%%s%%' AND bib_taglink.book_id = bib_book.id AND bib_taglink.tag_id = bib_tag.id ORDER BY %s %s LIMIT %d OFFSET %d;]]):format(q,orderby,order,limit,offset))
	elseif c == "abstract" then
		-- Select books which have the term in their abstract
		curs,err = conn:execute(([[SELECT * FROM bib_book WHERE abstract LIKE '%%%s%%' ORDER BY %s %s LIMIT %d OFFSET %d;]]):format(q,orderby,order,limit,offset))
	else -- Should never happen, as title get's set by default higher up
		print("Hit a bug in search_results, we should never be in something else but defined fields",debug.traceback()) 
	end
	if err then print("-- search result debug ERROR: ",err) end	
	-- Start fetching all the books (stops when curs:fetch returns nil instead of the table)
	local cur_book = {}
	while curs:fetch(cur_book,"a") do
		cur_book:pimp() -- Add extra data to the returned book
		setmetatable(cur_book,{__index = models.book }) -- Set the metatble to the metatable that comes with books, enables stuff like :delete and :save
		books_result [#books_result +1] = cur_book
		cur_book ={}
	end
	return render_search_results(web,{books=books_result, pages = pgs, user=user})
end --}}}

bib:dispatch_get(search_results, "/search")

--- Controller for viewing the books (GET part)
function view_book(web, id) --{{{
	local user = check_user(web)
	local book = models.book:find(id)
	local pages = models.page:find_all()
	book:pimp()
	if user then
		local user_res=models.reservation:find_by_book_id_and_user_id({book_id,user.id})
	end

	return render_book(web,{book=book,user=user,pages=pages,reservation=user_res})
end --}}}

--- Controller for the book processing (POST part)
function book_post(web,book_id) --{{{
	local user = check_user(web)
	local result
	local res
	local submit=web.input.submit
	if not user then
		not_found(web)
	elseif submit==strings.reserve then
		-- check if there already is a reservation
		res =models.reservation:find_by_book_id_and_user_id({book_id,user.id})
		if res then
			result="doubleReservation"
		else
			res=models.reservation:new()
			res.user_id=user.id
			res.book_id=book_id
			res.date=os.date("%Y-%m-%d",os.time())
			res:save()
			result="reservationOK"
		end
	elseif submit==strings.cancel_reservation then
		res=models.reservation:find_by_book_id_and_user_id({book_id,user.id})
		if not res then
			result="noReservation"
		else
			res:delete()
		 	result="deleteReservationOK"
		end
	else
		print("debug uncaught case",submit,args)
	end

	return web:redirect(web:link("/book/"..book_id,{result=result,reservation= res and res.id or nil}))
end --}}}

bib:dispatch_get(view_book, "/book/(%d+)")
bib:dispatch_post(book_post, "/book/(%d+)")

--- Controller for the markdown syntax part
function markdown_syntax(web,args) --{{{
	local user = check_user(web)
	local pages = models.page:find_all()
	if not lfs.attributes('static') then print("--debug markdown_syntax: static dir does not exist") end
	local att_md,err1 = lfs.attributes("static/markdown."..language_def..".md")
	local att_html = lfs.attributes("static/markdown."..language_def..".html")
	local innerhtml
	if not att_md and not att_html then -- There isn't a markdown, nor a html file -> redirect to the wikipage (if that doesn't exist, bad luck)
		return web:redirect(web:link(strings.markdown_url))
	elseif not att_html or att_md.modification > att_html.modification then -- Check whether html doesn't exist or is older than the markdown file
		local fhin =io.open("static/markdown."..language_def..".md","r")
		local md_string=fhin:read("*a")
		fhin:close()
		local fhout=io.open("static/markdown."..language_def..".html","w")
		innerhtml=markdown(md_string)
		fhout:write(innerhtml)
		fhout:close()
	else
		local fhin=io.open("static/markdown."..language_def..".html")
		innerhtml = fhin:read("*a")
		fhin:close()
	end
	return layout(web,{user=user;pages=pages},innerhtml)
end --}}}

bib:dispatch_get(markdown_syntax, "/markdown")

-- Controllers for static content:
-- Controladores para contenido stático:
-- css / css
-- images / imagenes
-- book covers / Tapas de los libros
bib:dispatch_static("/covers/.*%.jpg","/covers/.*%gif")
-- Static html pages: Manuals, markdown syntax, ...

-- Views for the application / Views para la aplicación
function layout(web, args, inner_html) --{{{
return html{
	head{
		title(bib_title),
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
			div{ id = "footer", style="clear:both", markdown(strings.copyright_notice) }
		}
	}
} 
end

function _menu(web, args)
	local res={ li( a{ href= web:link("/"), strings.homepage_name }) }
	for _,page in pairs(args.pages) do
		res[#res + 1] = li(a{ href = web:link("/page/" .. page.id), page.title })
	end
	if args.user then
		res[#res+1]=li( a{ href = web:link("/login"),strings.logged_in_as,args.user.login} )
	else
		res[#res+1]=li( a{ href = web:link("/login"),strings.login_button} )
	end
	return ul(res)
end

function _sidebar(web, args)
	local res
	res={
	li( a{ href=web:link("/"), strings.homepage_name }),
	li( a{ href=web:link("bytag"), strings.browse_by,string.category })
	}
	return ul(res)
end
--}}}

--- Renders the inner HTML for the indexpage
function render_index(web, args) --{{{
	local tstart=os.time()
	local searchbox
	searchbox = div.searchbox{
		fieldset{
			legend{strings.search_book},
			form{ name="search",method="GET",action=web:link("/search"), 
				strings.search, input{type="text",name="q"},
				strings.search_by, '<select name="c">',
					option{value="title",selected="selected",strings.title},
					option{value="author",strings.author},
					option{value="isbn",strings.isbn},
					option{value="tag",strings.tag},
					option{value="abstract",strings.abstract},
				'</select>',
				strings.order_by, '<select name="orderby">',
					option{value="title",selected="selected",strings.title},
					option{value="author",strings.author},
					option{value="isbn",strings.isbn},
					option{value="tag",strings.tag},
					option{value="abstract",strings.abstract},
				'</select>',
				'<select name="order">',
					option{value="desc",selected="selected",strings.order_desc},
					option{value="asc",strings.order_asc},
				'</select>',
				input{type="submit",value=strings.search}
			}		
		}
	}
	local res = {searchbox}
	if #args.books == 0 then
		return layout(web, args, p(strings.no_books))
	else
		local cur_time -- For Grouping books bought on same date together
		for _, book in pairs(args.books) do
			local str_time = book.date_acquisition
			if cur_time ~= str_time then
				cur_time = str_time
				res[#res + 1] = h2{style="clear:both",str_time}
			end
			res[#res + 1] = _book_short(web, book)
		end
		print("--render_index time: ",os.time()-tstart)
		return layout(web, args, div.booklist(res))
	end
end

function _book_short(web, book)
	local cover_img
	if book.url_cover~= "" then
		cover_img=book.url_cover
	else
		cover_img="/covers/cover0-default.gif"
	end
	local abstract_html = book.abstract_html:match("^(.*)<!%-%-%s*break%s*%-%->") or book.abstract_html
	return div.book_short{ style="clear:both",
		h3{book.title,strings.by_author,book.author_last_name,", ",book.author_rest_name},
		div.cover{ a{ href = web:link("/book/".. book.id), img { style="float:left", height="100px",src=web:static_link(cover_img), alt=strings.cover_of .. book.title} }},
		div.tags{em{book.cat,class="category"},": ", table.concat(book.tags,", ") },
		strings.copies_available .. book.ncopies,
		abstract_html,
		--a{ href = web:link("/post/" .. post.id .. "#comments"), strings.comments ..
		--" (" .. (post.n_comments or "0") .. ")" }
   }
end 
-- }}}

--- Renders inner html for static pages, and plugs them into the layout function
function render_page(web, args) --{{{
	return layout(web, args, div.blogentry(args.page.body_html))
end
--}}}

--- Renders the search results
function render_search_results(web, args) --{{{
	local res={}
	for _, book in pairs(args.books) do
		res[#res + 1] = _book_short(web, book)
	end
	return layout(web,args,h2("Search results")..div.booklist(res))
end --}}}

--- Renders the page for a book
function render_book(web, args) --{{{
	local book=args.book
	local cover_img
	if book.url_cover~= "" then
		cover_img=book.url_cover
	else
		cover_img="/covers/cover0-default.gif"
	end
	local result = web.input.result
	local mesg = ""
	if result == "reservationOK" then
		mesg = div.mesg {strings.reservation_ok}
	elseif result == "deleteReservationOK" then
		mesg = div.error {strings.delete_reservation_ok}
	elseif result == "doubleReservation" then
		mesg = div.error {strings.double_reservation}
	elseif result == "noReservation" then
		mesg = div.error {strings.no_reservation}
	end
	
	local res={mesg,
		h3{book.title ,strings.by_author,book.author_last_name , ", " , book.author_rest_name },
		div.cover{ a{ href = web:link("/book/".. book.id), img {height="100px", src=web:static_link(cover_img), alt=strings.cover_of .. book.title} } },
		div.tags{ em.category {book.cat}, ": ", table.concat(book.tags,", ") },
		strings.copies_available .. book.ncopies,
		book.abstract_html
		}
	if args.user then
		res[#res+1]= h3(strings.user_menu)
		-- if reserved by this user : put date available and un-reserve button
		-- else put copies available and reserve button
		if web.input.reservation then
			res[#res+1]=form{action=web:link("/book/"..book.id), method="POST",
				strings.reserved,
				input{ name="submit",type="submit", value=strings.cancel_reservation},
			}
		else
			res[#res+1]= form {action=web:link("/book/"..book.id), method="POST",
				strings.copies_available, book.ncopies,
				input{ name="submit",type="submit", value=strings.reserve },
			}
		end

		if args.user.is_admin == 1 then
			res[#res+1] = {
				h3(strings.admin_menu),
				div.group{
					h4(strings.this_book),
					a{ href=web:link("/edit/book/"..book.id), strings.edit_book}," ",
					a{ href=web:link("/delete/book/"..book.id), strings.delete_book}," ",
					}
				}
			local copies = models.copy:find_all_by_book_id({book.id})
			local copies_list = {}
			for _,copy in pairs(copies) do
				copies_list[#copies_list+1] = li{ book.title.." ", copy.id ," ",
					a{ href=web:link("/lend/"..copy.id),	strings.lend_copy}," ",
					a{ href=web:link("/return/"..copy.id),	strings.return_copy}," ",
					a{ href=web:link("/edit/copy/"..copy.id),	strings.edit_copy}," ",
					a{ href=web:link("/delete/copy/"..copy.id),	strings.delete_copy}
					}
			end
			res[#res+1]=div.group{ h4(strings.copies), ul(copies_list)}
		end
	end
	return layout(web,args,res)
end --}}}

-- Add html utility functions to all render and layout functions, as to generate the HTML programmatically.
-- Añadir funcciones html a todas las funcciones render y layout, para que pueden generar el HTML programmaticalemente.
orbit.htmlify(bib, "layout", "_.+", "render_.+")
-- vim:fdm=marker
