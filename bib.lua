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

function check_isbn(number) -- TODO move to some utility module ... --{{{
	if not_empty(number) then
		local num=tostring(number:gsub("[ -]",""))
		local nt = {}
		for num in num:gmatch("[%dxX]") do
			nt[#nt+1]=num
		end
		if #num == 10 then
			control = 11-math.fmod(10*nt[1]+9*nt[2]+8*nt[3]+7*nt[4]+6*nt[5]+5*nt[6]+4*nt[7]+3*nt[8]+2*nt[9],11)
			if control == 10 then control="X" end
		elseif #num == 13 then
			control = 10-math.fmod(nt[1]+3*nt[2]+nt[3]+3*nt[4]+nt[5]+3*nt[6]+nt[7]+3*nt[8]+nt[9]+3*nt[10]+nt[11]+3*nt[12],10)
		else
			print("--debug isbn needs to be a 10 or 13 digit number")
			return nil
		end
		if tostring(control) == nt[#nt] or tostring(control):lower() == nt[#nt] then
			return num
		else
			print("--debug ISBN 10 invalid",num)
			return num,strings.invalid_isbn
		end
	else
		return "",strings.warn.isbn_missing
	end
end --}}}

--- Returns nil if the input is nil or "" , returns input otherwise
function not_empty(input)
	if input and input ~= "" then
		return input
	else
		return nil
	end
end

--- Stupid wrapperfunction for forcing an update to the HTML from markdown code.
function update_html(field,obj)
	return obj:update_html(true)
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
-- Form information for different models, used to build the edit forms and pars edit POST info. The format is straight forward.
-- "title" is the field of the model used as in the page title
-- "depends" is a string containing a model from which one instance is needed to be selected, via web.GET[form.depends] or will be asked when creating a new object of this type.
-- "fields" is a table containing info for each field that will be editable by the administrator
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
--			readonly	: a read-only text
--		valid(value,obj)	: validation function and filtering function receives the field to filter/validate and needs to return the following:
--			value : the validated and transformed value, nil if invalid and to be refused
--			message : Warning message if needed (like when a book has an invalid isbn, which is possible)
--		update(field,obj) : function that updates the some other field upon a change of a field in the form (eg. in pages, update the body_html from the markdown code in body)
--			receives field, the field that triggers the update, so is in the form and obj, the object being edited.
--		autogen(obj_type,object,get)	: Autogenerates the field, given the object type (for new objects), the object self (if existing), get, the web.GET variables passed
--											on to the page. Currently used for copy_nr.
--
models.book.form={ --{{{
	title="title",
	fields = {
		{name="title",caption=strings.title,["type"]="text",valid=not_empty},
		 --TODO Make these fields autocomplete, and add a "new ... " link style drupal autocomplete for authors and tags
		{name="author_id",caption=strings.author,["type"]="select",model=models.author,fields={"rest_name","last_name","id"}},
		{name="cat_id",caption=strings.category,["type"]="select",model=models.cat,fields={"cat_text","id"}},
		{name="isbn",caption=strings.isbn,["type"]="text",valid=check_isbn},
		{name="abstract",caption=strings.abstract,["type"]="textarea",update=update_html},
		{name="url_ref",caption=strings.url_ref,["type"]="text"}, -- TODO maybe add link verification?
		{name="url_cover",caption=strings.url_cover,["type"]="text"}
	}
} --}}}
models.cat.form={ --{{{
	title="cat_text",
	fields={
		{name="cat_text",caption=strings.category,["type"]="text", -- lowercase all categories
			valid=function(cat_text,cat)
				if not not_empty(cat_text,cat) then return nil, strings.err.cat_text_empty end
				local cat_text = cat_text:lower()
				local cat_db = models.cat:find_by_cat_text({cat_text})
				print("--debug cat.form.valid ",cat_text, cat_db and tprint(cat_db), tprint(cat), cat_db and cat_db.id, cat.id)
				if not cat_db or (cat and cat_db.id == cat.id) then
					return cat_text
				else
					return nil , strings.err.cat_text_exists
				end
			end}
		}
} --}}}
models.tag.form={ --{{{
	title="tag_text",
	fields={
		{name="tag_text",caption=strings.tag,["type"]="text",
			valid=function(tag_text,tag)
				if not not_empty(tag_text) then return nil, strings.err.tag_text_empty end
				local tag_text = tag_text:lower() -- lowercase all tags
				local tag_db = models.tag:find_by_tag_text(tag_text)
				if not tag_db or tag_db.id == tag.id then
					return tag_text
				else
					return nil , strings.err.tag_text_exists
				end
			end}
	}
} --}}}
models.page.form={ --{{{
	title="title",
	fields = {
		{name="title",caption=strings.title,["type"]="text",valid=not_empty},
		{name="body",caption=strings.body,["type"]="textarea",update=update_html}
	}
}--}}}
models.author.form={ --{{{
	title={"last_name","rest_name",sep=", "},
	fields = {
		{name="last_name",caption=strings.last_name,["type"]="text",valid=not_empty},
		{name="rest_name",caption=strings.rest_name,["type"]="text",valid=not_empty},
		{name="url_ref",caption=strings.url_ref,["type"]="text"}
	}
}--}}}
models.copy.form={--{{{
	title={"book_id","copy_nr",sep="/"},
	depends="book",
	fields = {
		{name="book_id",caption=strings.book,["type"]="select",model=models.book,fields={"title","id"}},
		{name="copy_nr",caption=strings.copy_nr,["type"]="readonly",
			autogen = function(copy_model,copy,get)
				if copy or not get then print("-- debug copy, something fishy going on!") end
				local depends=copy_model.form.depends
				local prevCopy = copy_model:find_first("book_id=?",{tonumber(get.book_id),fields={"MAX(copy_nr)"}})
				local prevNr = prevCopy and prevCopy["MAX(copy_nr)"] or 0
				return prevNr + 1
			end},
		{name="date_acquisition",caption=strings.date_acquisition,["type"]="text"}, -- TODO come up with some validation.
		{name="edition",caption=strings.edition, ["type"]="text"},
		{name="price",caption=strings.price,["type"]="text",valid=function(str) if not_empty(str) then return str:match("%d+%.?%d*") end return "" end } --TODO look into converting this into number, for sorting.
	}
}--}}}
models.user.form={--{{{
	title={"login","real_name",sep=": "},
	fields = {
		{name="login",caption=strings.login,["type"]="text",
			valid=function(login,user)
				if login:match("^[%wéáíóúüûñ_%.%d]+$") and #login>=4 then
					local user_db = models.user:find_by_login({login,fields={"id"}})
					if not user_db or user_db.id == user.id then
						return login
					else
						return nil, strings.err.login_exists
					end
				else
					return nil,strings.err.login_invalid
				end
			end},
		--{name={"password",caption=strings.password,["type"]="password"}},
		{name="real_name",caption=strings.name,["type"]="text",valid=not_empty},
		{name="is_admin",caption=strings.admin,["type"]="select",options={0,1}},
		{name="center_id",caption=strings.center,["type"]="select",model=models.center,fields={"real_name","id"}},
		{name="telephone",caption=strings.telephone,["type"]="text",
			valid=function(tel)
				local tel=tel:gsub("[- %(%)]","") -- remove any extra characters
				if tel:match("%+?%d%d%d%d%d%d%d+") then -- check if there are enough digits
					return tel
				else
					return nil, strings.err.telephone_malformed 
				end
			end},
		{name="email",caption=strings.email,["type"]="text",
			valid=function(email,user)
				local email=email:match("([%w%d%._]+[%w%d]+@[%w%d]+%.[%w%d%.]+)") --TODO Make stronger, now stuf like foo..bar@mail....com are possible
				if not email then
					return nil, strings.err.email_malformed
				end
				local user_mail = models.user:find_by_email(email)
				if not user_mail or user.id == user_mail.id then -- email address not yet used
					return email
				else
					return nil, strings.err.email_exists
				end
				
			end}, -- verify if it's a unique email in the db.
		{name="debt",caption=strings.debt,["type"]="text",valid=function(debt) return debt:match("%d+%.?%d*") end} --TODO look into converting this into number, for sorting
	}
}--}}}
models.center.form={--{{{
	title="real_name",
	fields = {
		{name="real_name",caption=strings.name,["type"]="text",valid=not_empty},
		{name="center_id",caption=strings.subcenter_of,["type"]="select",model=models.center,fields={"real_name","id"}},
		{name="address",caption=strings.address,["type"]="textarea"},
		{name="telephone",caption=strings.telephone,["type"]="text",
			valid=function(tel)
				local tel=tel:gsub("[- %(%)]","") -- remove any extra characters
				if tel and #tel>=7 then -- check if there are enough digits
					return tel
				else return nil, strings.err.telephone_malformed end
			end},
		{name="email",caption=strings.email,["type"]="text",
			valid=function(email)
				local email=email:match("([%w%d%._]+[%w%d]+@[%w%d]+%.[%w%d%.]+)") --TODO Make stronger, now stuf like foo..bar@mail....com are possible
				if email then
					return email
				else
					return nil,strings.err.email_malformed
				end
				
			end}, -- verify if it's a unique email in the db.
		{name="contact",caption=strings.contact_person,["type"]="text"},
		--{name="logo",caption=strings.logo,["type"]="text"} --TODO not implemented
	}
}--}}}

-- make form fields indexable by index number as by name.
for name,model in pairs(models) do
	if model.form then
		local cur_fields=model.form.fields
		for n=1,#cur_fields do
			cur_fields[cur_fields[n].name]=cur_fields[n]
		end
	end
end

-- Methods for all models / Métodos para todos modelos --{{{

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

	--- Finds all books, with limiting,offset, and order
	local function find_all_limit(self,where,orderby,order,limit,offset)
		local where = where or "1=1"
		local orderby = self.meta[orderby] and orderby or "id" -- Only column of which we are sure that exists
		local order = order and (order:upper():match("(ASC)") or order:upper():match("(DESC)")) or "DESC"
		local limit = tonumber(limit) or 10
		local offset = tonumber(offset) or 0

		local query = ([[SELECT * FROM `%s` WHERE %s ORDER BY %s %s LIMIT %s OFFSET %s;]]):format(self.model.table_prefix..self.name,where,orderby,order,limit,offset) 
		local curs,err = self.model.conn:execute(query)
		if err then print("-- error find_all_limit ",err) end
		local objs_result = {}
		local cur_obj = {}
		while curs:fetch(cur_obj,"a") do
			setmetatable(cur_obj,{__index = models[self.name] }) -- Set the metatble to the metatable that comes with objs, enables stuff like :delete and :save
			objs_result [#objs_result +1] = cur_obj
			cur_obj ={}
		end
		return objs_result
	end
	
	--- Concatenates the values of the fields which names are listed in the table "fields" from self, seperated by the string in fields.sep.
	local function concat_fields(self, fields)
		if type(fields) ~= "table" then
			return self[fields]
		else
			local res={}
			for k=1,#fields do
				res[#res+1]=self[fields[k]]
			end
			return table.concat(res,fields.sep)
		end
	end
	-- Install method to all models / Instalar método a todos modelos
	for k,v in pairs(models) do
		v.index				= index
		v.find_all_limit	= find_all_limit
		v.concat_fields		= concat_fields
	end
end --}}}

cache = orbit.cache.new(bib, cache_path) -- No longer used: pages where username get's displayed can't be cached.
-- Methods for the page model / Métodos para el model "page"
--- Updates a pages body_html from the markdown version body
function models.page.update_html(page,force) --{{{
	if page.body_html == "" or force then -- first time
		page.body_html = markdown(page.body)
		page:save()
	end
	return page
end --}}}

-- Methods for the Book model / Métodos para el model "book"
--- Updates a books abstract_html from the markdown version abstract
function models.book.update_html(book,force) --{{{
	if book.abstract_html == "" or force then -- first time
		book.abstract_html = markdown(book.abstract)
		book:save()
	end
	return book
end --}}}
	
--- Add's lot's of data from other models to the book to be returned.
function models.book.pimp(book) --{{{
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
end --}}}
	
--- Returns the most recently added books, while adding all info needed (like Authors, tags, copies, ...)
function models.book:find_recent(num) --{{{
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
end --}}}

--- General search function
-- @params q Term for which to search
-- @params c Field in which to look for term
-- @params orderby Field by which to order the returned list
-- @params order Which sense the list should be ordered: asc or desc
-- @params limit Number of results to return
-- @params offset display from the offset'th result on
function models.book:find_gen(q,c,orderby,order,limit,offset) --{{{
	local books_result = {}
	local conn = self.model.conn -- This will be the connection to make the more complex SQL calls
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
		setmetatable(cur_book,{__index = models.book }) -- Set the metatble to the metatable that comes with books, enables stuff like :delete and :save
		cur_book:pimp() -- Add extra data to the returned book
		books_result [#books_result +1] = cur_book
		cur_book ={}
	end
	return books_result
end --}}}

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
	local limit = tonumber(web.input.limit) or 10
	limit = limit >= 0 and limit or 10 -- The maximum number of results to return (number or nil)
	local offset = tonumber(web.input.offset) or 0
	offset = offset >=0 and offset or 0 -- The offset from book 0 (number or nil)
	local order = web.input.order or "ASC" -- The order ASC or DESC
	if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
		order = "ASC"
	end
	local orderby = field_possible[web.input.orderby:lower()] or "title"

	local pgs = pgs or models.page:find_all()
	local user = check_user(web)

	books_result=models.book:find_gen(q,c,orderby,order,limit,offset)
	
	return render_search_results(web,{books=books_result, pages = pgs, user=user})
end --}}}

bib:dispatch_get(search_results, "/search")

--- Controller for viewing the books (GET part)
function view_book(web, id) --{{{
	local user = check_user(web)
	local pages = models.page:find_all()
	if id:match("%d+") then
		local book = models.book:find(id)
		book:pimp()
		if user then
			local user_res=models.reservation:find_by_book_id_and_user_id({book_id,user.id})
		end

		return render_book(web,{book=book,user=user,pages=pages,reservation=user_res})
	else
		local fields = {title="title",author="author",isbn="isbn",tag="tag",abstract="abstract"}
		local orderby = web.input.orderby and web.input.orderby:lower() or "title"-- The search criterium
		local order = web.input.order or "ASC"
		local limit = tonumber(web.input.limit) or 10
		local offset = tonumber(web.input.offset) or 0
		-- Sanitation of the parameters
		orderby = fields[orderby] or "title"
		if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
			order = "ASC"
		end
		limit = limit >= 0 and limit or 10 -- The maximum number of results to return (number or nil)
		offset = offset >=0 and offset or 0 -- The offset from book 0 (number or nil)

		local list = models.book:find_all_limit(nil,orderby,order,limit,offset)
		return render_book_list(web,{list=list,user=user,pages=pages,order=order,orderby=orderby,limit=limit,offset=offset,fields=fields})
	end	
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

bib:dispatch_get(view_book, "/book/(%d+)","/book/?")
bib:dispatch_post(book_post, "/book/(%d+)")

--- Controller for the author pages
function author_get(web,id) -- {{{
	local user = check_user(web)
	local pages = models.page:find_all()
	local order = web.input.order or "ASC"
	local limit = tonumber(web.input.limit) or 10
	local offset = tonumber(web.input.offset) or 0
	if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
		order = "ASC"
	end
	limit = limit >= 0 and limit or 10 -- The maximum number of results to return (number or nil)
	offset = offset >=0 and offset or 0 -- The offset from book 0 (number or nil)
	if id:match("%d+") then
		local author = models.author:find(id)

		local fields = {title="title",author="author",isbn="isbn",tag="tag",abstract="abstract"}
		local orderby = web.input.orderby and web.input.orderby:lower() or "title"-- The search criterium
		-- Sanitation of the parameters
		orderby = fields[orderby] or "title"

		local list = models.book:find_all_limit("author_id="..author.id,orderby,order,limit,offset)
		return render_author(web,{book_list=list,author=author,user=user,pages=pages,order=order,orderby=orderby,limit=limit,offset=offset,fields=fields})
	else
		local fields = {last_name="last_name",rest_name="rest_name"}
		local orderby = web.input.orderby and web.input.orderby:lower() or "rest_name"-- The search criterium
		-- Sanitation of the parameters
		orderby = fields[orderby] or "rest_name"

		local list = models.author:find_all_limit(nil,orderby,order,limit,offset)
		return render_author_list(web,{list=list,user=user,pages=pages,order=order,orderby=orderby,limit=limit,offset=offset,fields=fields})
	end
end --}}}
bib:dispatch_get(author_get,"/author/(%d+)/?","/author/?")

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
function layout(web, args, inner_html, rightsidebar) --{{{
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
			div{ id = "menu",
				_menu(web, args)
			}, 
			div{ id = "sidebar",
				_sidebar(web, args)
			},  
			div{ id = "contents", inner_html },
			rightsidebar and div{ id="sidebar_right",style="clear:both", rightsidebar} or "",
			div{ id = "footer", style="clear:both", markdown(strings.copyright_notice) }
		}
	}
} 
end

function _menu(web, args)
	local res={
		li( a{ href= web:link("/"), strings.homepage_name }),
		li( a{ href= web:link("/admin"), strings.administration })
		}
	if args.user then
		res[#res+1]=li( a{ href = web:link("/login",{link_to=web.path_info}),strings.logged_in_as,args.user.login} )
	else
		res[#res+1]=li( a{ href = web:link("/login",{link_to=web.path_info}),strings.login_button} )
	end
	return ul(res)
end

function _sidebar(web, args)
	local res
	res={
		li( strings.browse_by ),
		ul{
			li( a{ href=web:link("/bytag"), strings.category }),
			li( a{ href=web:link("/book"), strings.book }), -- TODO implement
			li( a{ href=web:link("/author"), strings.author })
		},
		li( strings.pages)
	}
	local pages = {}
	for _,page in pairs(args.pages) do
		pages[#pages + 1] = li(a{ href = web:link("/page/" .. page.id), page.title })
	end
	res[#res+1]=ul(pages)
	return ul(res)
end

function _sort_sidebar(web,fields,order,orderby,limit)
	local ft={ strings.sort_by,'<br />','<select name=orderby>' }
	for field in pairs(fields) do
		local selected
		if orderby:lower() == field then
			selected="selected"
		end
		ft[#ft+1]=option{value=field,selected=selected,strings[field]}
	end
	local asc_sel,desc_sel
	if order:upper()=="DESC" then desc_sel="checked" else asc_sel="checked" end
	ft[#ft+1]=table.concat{
		'</select>',
		'<br />',
		input{type="radio",name="order",value="ASC",checked=asc_sel}, strings.order_asc, '<br />',
		input{type="radio",name="order",value="DESC",checked=desc_sel}, strings.order_desc, '<br />',
		'<select name="limit">',
		'<br />'
		}
	for _,num in pairs{10,20,50,100} do
		local selected
		if num==limit then
			selected="selected"
		end
		ft[#ft+1]=option{value=num, num, selected=selected}
	end
	ft[#ft+1]=table.concat{
		'</select>',
		strings.entries_per_page,
		'<br />',	
		input{type="submit", value=strings.confirm}
		}
	return form{ action=web.path_info, method="GET",ft }
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
		return layout(web, args, p(strings.err.no_books))
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
		h3{book.title,strings.by_author, a{ href=web:link("/author/"..book.author_id),book.author_last_name,", ",book.author_rest_name}},
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
		mesg = div.mesg {strings.delete_reservation_ok}
	elseif result == "doubleReservation" then
		mesg = div.error {strings.err.double_reservation}
	elseif result == "noReservation" then
		mesg = div.error {strings.err.no_reservation}
	end
	
	local res={mesg,
		h3{book.title ,strings.by_author,a{ href=web:link("/author/"..book.author_id), book.author_last_name , ", " , book.author_rest_name} },
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
					a{ href=web:link("/delete/book/"..book.id), strings.delete," ",strings.book}," ",
					a{ href=web:link("/new/copy/",{book_id=book.id}),strings.new_copy}
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

--- Renders the booklist page
function render_book_list(web, args) --{{{
	-- This needs to list books, and accept options for sorting and limiting
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local title = h2(strings.browse_objects:gsub("@objects",strings.books))
	local res = {}
	local url = web.path_info:gsub("/+$","").."/" -- Strip extra // and make sure there is 1
	for  item_n = 1,#args.list do
		local item = args.list[item_n]
		res[#res+1]= li{ a{href=web:link(url..item.id),item:concat_fields(item.form.title) }}
	end
	local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
	local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}

	return layout(web,args,{title,res,br(),prevPage," ",nextPage},_sort_sidebar(web,args.fields,order,orderby,limit))
end --}}}

--- Renders the author page
function render_author(web,args) --{{{
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local author = args.author
	local title=h2{author.last_name,", ",author.rest_name}
	local url_ref = author.url_ref and a{ href=author.url_ref, author.url_ref} or ""
	local books = {}
	for k=1,#args.book_list do
		local book=args.book_list[k]
		book:pimp()
		books[#books+1] = _book_short(web,book)--li{ a{href= web:link(("/book/%s"):format(book.id)),book.form.title}}
	end

	local url = web.path_info:gsub("/+$","").."/" -- Strip extra // and make sure there is 1
	local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
	local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
	return layout(web,args,{title,url_ref,books,prevPage,nextPage},_sort_sidebar(web,args.fields,order,orderby,limit))
end --}}}

--- Renders the authors list page
function render_author_list(web,args) --{{{
	-- This needs to list books, and accept options for sorting and limiting
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local title = h2(strings.browse_objects:gsub("@objects",strings.authors))
	local res = {}
	local url = web.path_info:gsub("/+$","").."/" -- Strip extra // and make sure there is 1
	for  item_n = 1,#args.list do
		local item = args.list[item_n]
		res[#res+1]= li{ a{href=web:link(url..item.id),item:concat_fields(item.form.title) }}
	end
	local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
	local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}

	return layout(web,args,{title,res,br(),prevPage," ",nextPage},_sort_sidebar(web,args.fields,order,orderby,limit))
end --}}}
-- Add html utility functions to all render and layout functions, as to generate the HTML programmatically.
-- Añadir funcciones html a todas las funcciones render y layout, para que pueden generar el HTML programmaticalemente.
orbit.htmlify(bib, "layout", "_.+", "render_.+")
-- vim:fdm=marker
