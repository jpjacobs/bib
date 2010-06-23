
module("bib", package.seeall)

--- Initialisation of random function
function init_random() --{{{
	print("-- init_random called")
	math.randomseed(os.time())
	-- perhaps improve with http://lua-users.org/wiki/MathLibraryTutorial
end --}}}
init_random()

--- Append more than 1 element to an array
-- @params t table to be appended too
-- @params ... list or table of elements to be appended
function tappend (t,...) --{{{
	local ti=table.insert
	local t2
	-- If the second argument is a table, add the elements of that table
	if type(select(1,...))=='table' then
		t2=select(1,...)
	-- The second argument ain't a table, so add all remaining arguments
	else
		t2={...}
	end
	for k=1,#t2 do
		ti(t,t2[k])
	end
end --}}}

--- Returns a string that list a table recursively (can be reloaded with table=loadstring("return "..str)())
-- Note: not tested on cyclic or selfcontaining tables.
-- @params t table to list
-- @params indent initial indentation (used internally)
-- @params done a list of tables that already have been traversed (to avoid eternal loops)
function tprint (t, indent, done) --{{{ 
	local res={}  -- result table to be concatenated 
	local done = done or {}
	local ta=tappend
	local indent = indent or 2
	ta(res,string.rep(" ",indent-2),"{\n")	-- initial {
	for key, value in pairs (t) do 			-- loop  through table
		ta(res,string.rep(" ",indent)) 		-- indent it
		if type (value) == "table" and not done [value] then
			done [value] = true
			if type(key)=='string' then
				ta(res,'["',key,'"]=\n')
			else
				ta(res,"[",key,"]",'=\n')
			end
			ta(res,tprint (value, indent + 2, done))
		else
			if type(key) == 'string' then
				ta(res,'["',key,'"]=\t',tostring(value),",\n")
			else
				ta(res,'[',key,']','=\t',tostring(value),',\n')
			end
		end
	end
	ta(res,string.rep(" ",indent-2),"},\n")
	if indent==2 then		-- if last level: remove the trailing , (not allowed)
		table.remove(res)
		ta(res,"}")
	end
	return table.concat(res)	-- concatenate the result
end --}}}


-- Controllers for admin related stuff.
-- Admin interface
--- Controller for the admin section (redirects if not logged in)
-- @param web webobject which will be passed by the dispatcher
-- @param params captchures matched by the dispatcher, which will either be words (other adminpages) or numbers (TODO necessary?)
function admin_get(web,args) --{{{
	-- List of admin pages, except the admin mainpage.
	local user=check_user(web)
	-- If the user is not set/known, then redirect to the login page
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		local order = web.input.order or "ASC"
		local limit = tonumber(web.input.limit) or 10
		local offset = tonumber(web.input.offset) or 0
		if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
			order = "ASC"
		end
		limit = limit >= 0 and limit or 10 -- The maximum number of results to return (number or nil)
		offset = offset >=0 and offset or 0 -- The offset from book 0 (number or nil)
		local fields = {overdue="overdue",copy_code="copy_code",telephone="telephone",real_name="real_name",user_id="user_id",email="email",title="title"}
		local orderby = web.input.orderby and web.input.orderby:lower() or "overdue"-- The search criterium
		-- Sanitation of the parameters
		orderby = fields[orderby] or "overdue"
		-- Find users that have over-due books
		-- using SQL because of WAY to complicated using Orbit
		local query = ([[SELECT julianday("now")-julianday(date_return) AS overdue, bib_book.title, bib_book.id||"/"||copy_id as copy_code, user_id, bib_user.real_name, bib_user.telephone, bib_user.email
		FROM bib_lending, bib_user, bib_book, bib_copy
		WHERE bib_lending.copy_ID = bib_copy.id -- connect copy with lending
		and bib_copy.book_id = bib_book.id -- connect copy with book
		and bib_lending.user_ID = bib_user.id -- connect user with lending
		and overdue > 0
		ORDER BY %s %s LIMIT %s OFFSET %s;]]):format(orderby,order,limit,offset)
		local curs,err = models.book.model.conn:execute(query)
		if err then print("-- warn, overdues query in admin returned ",err) end
		local overdues = {}
		local t={}
		while curs:fetch(t,"a") do
			overdues[#overdues+1] = t
			t={}
		end
		local allusers=models.user:find_all({fields={"id","real_name"}})
		-- TODO pass fields for sorting sidebar
		return render_admin(web,{user=user,allusers=allusers,overdues=overdues,fields=fields,order=order,limit=limit,offset=offset,orderby=orderby})
	end
end --}}}
function admin_post(web,args) --{{{
	local user= check_user(web)
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		if web.POST.op==strings.lend_copy then --{{{
			if web.POST.lend_copy == "" then
				return web:redirect("/admin")
			end
			local book_id,copy_nr = web.POST.lend_copy:match("%d+/%d+")
			local copy,copy_id
			print('--debug amdin_post, user_id for lending is',web.POST.user_id,"and lend_copy =",web.POST.lend_copy)
			if not book_id then -- did not find in frmat book_id/copy_nr, try the raw copy_id (as in db)
				copy_id = web.POST.lend_copy:match("%d+")
				copy = models.copy:find(web.POST.lend_copy)
			else
				copy = models.copy:find_first("book_id = ? and copy_nr = ?",{book_id,copy_nr,fields={"id"}})
			end
			local user_lend = models.user:find(web.POST.user_id)
			if not (book_id and copy_nr) and not copy_id then
				print("--warn admin_post copy_nr malformed") -- TODO message
			elseif not copy then
				print("--warn admin_post book_id and copy_nr don't form an existing copy code",book_id,copy_nr)
			elseif not user_lend then
				print("--warn admin_post user ",web.POST.user_id," does not exist")
			elseif models.lending:find_first("copy_id = ?",{copy.id,fields={"id"}}) then
				print("--warn admin_post, copy not available")
			else
				-- TODO if a reservation is pending _for another user_ then message the admin.
				-- How do we handle this with multiple copies? per reservation, one copy should be kept back
				-- Number of reservations, excepting reservations for this book for this user
				local num_res = models.reservation:find_first("user_id <> ? and book_id == ?",{user_lend.id,copy.book_id,fields={[[count(id)]]}})
				-- Total number of copies of this book
				local all_copies = models.copy:find_first("id == ?",{copy.id,fields={"id"}})
				-- Number of copies of this book being lend
				local copies_ids = {}
				for k=1,#all_copies do	
					copies_ids[#copies_ids+1] = all_copies[k].id
				end
				local book=models.book:find(copy.book_id)
				book:pimp()
				-- There aren't any copies available, and the lending user does not have a reservation for this book
				if book.copies_available <= 0 and not models.reservation:find_by_user_id_and_book_id({user_lend.id,copy.book_id}) then
					print("--debug admin_post, no un-reserved copies available, lending NOT made")
					return web:redirect(web:link("/admin")) -- TODO message & link_to 
				else
					local t=models.lending:new()
					t.user_id = user_lend.id
					t.copy_id = copy.id
					t.date_return = os.date("%Y-%m-%d",os.time()+86400*7*3) -- TODO hardcodedvalue warning!
					t:save()
					local r = models.reservation:find_by_user_id_and_book_id({user_lend.id,copy.book_id})
					if r then
						print("-- debug admin_post, reservation",r.id,"deleted") 
						r:delete()
					end
				end
			end
			return web:redirect(web:link("/admin")) -- }}} TODO message & link_to
		elseif web.POST.op==strings.return_copy then --{{{
			local book_id,copy_nr = web.POST.return_copy:match("%d+/%d+")
			local copy , copy_id
			if not book_id then -- did not find in frmat book_id/copy_nr, try the raw copy_id (as in db)
				copy_id = web.POST.return_copy:match("%d+")
				copy = models.copy:find(copy_id)
			else
				copy = models.copy:find_first("book_id = ? and copy_nr = ?",{book_id,copy_nr,fields={"id"}})
			end
			local lending = models.lending:find_first("copy_id = ?",{copy.id})
			if not book_id and copy_nr then
				print("--warn admin_post copy_nr malformed") -- TODO message
			elseif not copy then
				print("--warn admin_post book_id and copy_nr don't form an existing copy code",book_id,copy_nr)
			elseif not lending then
				print("--warn copy",copy.id," has not been lend")
			else
				print("--debug admin_post: lending ",lending.id,"deleted")
				lending:delete()
			end
			return web:redirect(web:link("/admin")) -- TODO message & link_to
		else
			return not_found(web)
		end --}}}
	end
end --}}}

bib:dispatch_get(admin_get, "/admin/?")--,"/admin/(%w+.+)")
bib:dispatch_post(admin_post,"/admin/?")

--- Controller for the GET part of the login page
function login_get(web) -- {{{
	-- Convert the result of a previous login to the apropriate errormessage
	local result_login
	if web.GET.not_found=="1" then
		result_login = strings.err.user_not_found
	elseif web.GET.not_match=="1" then
		result_login = strings.err.wrong_password
	elseif web.GET.not_admin=="1" then
		print("-- login_get detected not_admin")
		result_login = strings.err.not_allowed_to_administration
	else
		result_login = ""
	end
	-- if the link_to parameter was given then take that one as argument, else take "/"
	return login_layout(web , { link_to = web:link(web.input.link_to or "/"), login = web.input.login, result_login=result_login} )		 
end --}}}

--- Controller for the POST part of the login page
function login_post(web) --{{{
	local login = web.input.login
	local password = web.input.password
	local user = models.user:find_by_login{ login }
	-- If the link_to parameter is empty (we're not being referred to the loginpage from another page)
	if web:empty_param("link_to") then
		web.input.link_to = web:link("/")
	end
	-- The user that has been entered exists
	if user then
		-- The entered password matches
		if password == user.password then
			-- Make a new auth cookie, save it in the DB, and set it as Cookie
			local auth_hash=math.random(2^31-1)
			user.auth=auth_hash
			user:save()
			web:set_cookie("authentication",{value=user.login.."||"..auth_hash,expires=os.time()+3600})
			return web:redirect(web.input.link_to)
		else
	 		return web:redirect(web:link("/login", { login = login,
				link_to = web.input.link_to,
				not_match = "1" }))
		end
	else
		return web:redirect(web:link("/login", { login = login,
			link_to = web.input.link_to,
			not_found = "1" }))
	end
end --}}}

bib:dispatch_get(login_get, "/login")
bib:dispatch_post(login_post, "/login")

--- Controller for the edit pages 
function edit_get(web,obj_type,id) --{{{ TODO split controller from view.
	-- TODO display results from editing instead of failing silently.
	local offset = tonumber(web.input.offset) or 0
	local limit = tonumber(web.input.limit) or 10
	local user = check_user(web)
	local pages = models.page:find_all()
	local fields,title,object
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		if obj_type:match("^/edit/?") then -- no extra arguments, and since there are no captures, the function get's the whole match from dispatch_get()
			-- build list of all editable models, display the list to choose from
			local title = h2(strings.edit_objects)
			local res = {}
			for name,model in pairs(models) do
				if model.form then
					res[#res+1] = li{ a{ href=web:link("/edit/"..name,{limit=10}), " ", strings[name]}}
				end
			end
			return admin_layout(web,{user=user,pages=pages},div.group{title,ul(res)})
		elseif not models[obj_type] then -- There is no model named obj_type
			print("-- debug edit_get: no model found for type ",obj_type)
			return not_found(web) --TODO rewrite not_found to include an error message
		elseif not models[obj_type].form then -- The model obj_type exists, but isn't editable (eg, has no form)
			print("--debug edit_get","object type doesn't have a form-table, add form table to the model")
			return not_found(web)
		else -- The obj_type exist and is editable
			if not id then -- no id given, edit is type /edit/<object>, so list all <objects>
				local title = h2{strings.edit," ",strings[obj_type]}
				local res = {}
				local url = web.path_info:gsub("/+$","").."/" -- Strip extra // and make sure there is 1
				local list = models[obj_type]:find_all_limit(nil,models[obj_type].form.title[1],"ASC",limit,offset)
				for  item_n = 1,#list do
					local item = list[item_n]
					res[#res+1]= li{ a{href=web:link(url..item.id),item:concat_fields(item.form.title) }}
				end
				local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
				local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
				return admin_layout(web,{user=user,pages=pages},div.group{title,ul(res),br(),prevPage," ",nextPage})
			else
				local object = models[obj_type]:find(id)
				local form=models[obj_type].form
				if not object then -- The object does not exist in the db
					if web.input.create ~= "1" then -- we're not creating a new object
						print("--debug edit object not found and create ~= 1")
						return not_found(web)
					end
					return render_edit(web,{user=user,pages=pages},obj_type,object,form.fields)
				else --Object exists
					return render_edit(web,{user=user,pages=pages},obj_type,object,form.fields)
				end
			end
		end
	end
end --}}}

--- Controller for the edit pages, POST part aka form processing
function edit_post(web,obj,id) --{{{
	local user = check_user(web)
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
--		print("--debug edit_post, web.POST=",tprint(web.POST))
		local this_object
		if not obj or obj:match("^/edit/?$") or not id or not id:match("%d") then -- Check for editing something that does not exist
			print("--warn edit_post, Attempting to edit a non-existing object: ",obj,id)
			return web:redirect(web:link("/edit")) --TODO add explanation
		end
		if web.POST.create=="1" then
--			print("--debug edit_post , created new object")
			this_object=models[obj]:new() --make a new object
			this_object:save() -- pass the new option to edit_get so if necessary fields remain empty, or the editing is canceled, the object is deleted
		elseif not models[obj]:find(id) then
			print("--warn edit_post, Attempting to edit non-existing object, and create~= 1")
			return web:redirect(web:link("/edit/"..obj))
		else -- the object is not newly created and, it exists
			this_object=models[obj]:find(id)
		end
		-- From here on, the object_type and id should point to an existing object
		local this_form=models[obj].form
		-- parse web.POST parameters
		if web.POST.op==strings.delete then
			if web.POST.create == "1" then -- this is a newly created "unsaved" object
				this_object:delete()
				return web:redirect(web:link("/edit/"..obj))
			else
				print("--debug edit_post, link_to = ",web.path_info)
				return web:redirect(web:link("/delete/"..obj.."/"..id),{link_to=web.path_info}) -- page asking for confirmation + processing in POST
			end
		elseif web.POST.op==strings.save then --{{{
			if not this_form then
				print("-- warn edit_post :trying to edit an object from a non-editable model")
				return web:redirect(web:link("/edit")) -- TODO add explanation
			else
				local mesg={} -- list of messages returned by validation functions
				local obj_changed
				for k,v in pairs(web.POST) do
					local field_changed
					if this_form.fields[k] then
--						if this_form.fields[k].autogen then FIXME deprecated, autogenned stuf happens in render_edit
--							v=this_form.fields[k].autogen(this_object) --replace v; so if the field has a valid function, it still runs
----							print("--debug edit_post, autogen", v)
--						end
--						print("--debug edit_post, object has a form for this field:",this_form.fields[k].name)
						if this_form.fields[k].valid then -- Form field contains a validation function, receives string to validate/filter and the object
--							print("--debug edit_post, field "..this_form.fields[k].name.." has a validation function")
							local dummy -- To protect the field from getting overwritten upon errors
							dummy,mesg[#mesg+1]=this_form.fields[k].valid(v,this_object) -- if there is a message, capture and forward.
--							print("--debug edit_post, validation function returned",dummy,mesg[#mesg])
							if dummy and tostring(this_object[k]) ~= dummy then
--								print("--debug edit_post, object valid, and new")
								field_changed,obj_changed = true,true
								this_object[k]=dummy
							else
--								print("--debug edit_post, the value ",v," was not valid, or not new")
							end
						else -- no validation function present for this field
--							print("--debug edit_post, field "..this_form.fields[k].name.." does not have a validation function")
							if tostring(this_object[k])~=v then -- the value is new
--								print("--debug edit_post, the new value ",v,"differs from the old one",this_object[k])
								field_changed,obj_changed = true,true
								this_object[k]=v 
							end
						end
						if this_form.fields[k].update and field_changed then -- Field has an update function
--							print("--debug edit_post, field "..this_form.fields[k].name.." has an updatefield")
							this_form.fields[k].update(k,this_object)
						end
					end
				end
	--			print("--debug edit_post, there have been changes to the object ",this_object.name,this_object.id,", saving changes")
				this_object:save()
--				print("--debug edit_post, Object saved")
			end
			return web:redirect(web:link("/edit/"..obj.."/"..id),{mesg=mesg}) --}}}
		elseif web.POST.op==strings.cancel then
			if web.POST.create == "1" then
				this_object:delete()
			end
			return web:redirect(web:link("/edit/"..obj)) -- TODO use link_to
		end
	end
	return tprint(web):gsub("\n","<br />")
end --}}}
bib:dispatch_get(edit_get,"/edit/(%w+)/(%d+)","/edit/(%w+)/?","/edit/?")
bib:dispatch_post(edit_post,"/edit/(%w+)/(%d+)")
 
--- Controller for delete page, GET part
function delete_get(web,obj,id) --{{{
	local user = check_user(web)
	local pages = models.page:find_all()
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		if not models[obj] then
			return not_found(web)
		else
			local object = models[obj]:find(id)
			if not object then
				return not_found(web)
			else
				return render_delete(web,{pages=pages, user=user} ,object)
			end
		end
	end
end --}}}

--- Controller for the delete page, POST part
function delete_post(web,obj,id) --{{{
	local user = check_user(web)
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		if not models[obj] then
			return not_found(web)
		else
			local object = models[obj]:find(id)
			if not object then
				return not_found(web)
			elseif web.POST.op== strings.cancel then
				return web:redirect(web:link("/edit/"..obj)) -- TODO link_to
			elseif web.POST.op == strings.delete then
				object:delete() -- BIG TODO : What to do with orphanaged things, like books without authors, ... -> maybe warn in delete_get about dependancies.
				return web:redirect(web:link("/edit/"..obj)) --TODO pass suitable message
			end
		end
	end
end --}}}
bib:dispatch_get(delete_get,"/delete/(%w+)/(%d+)")
bib:dispatch_post(delete_post,"/delete/(%w+)/(%d+)")

function new_get(web,obj) --{{{
	local offset = tonumber(web.input.offset) or 0
	local limit = tonumber(web.input.limit) or 10
	local user = check_user(web)
	local pages= models.page:find_all()
	local fields,object
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		if obj:match("^/new/?$") then -- We're doing the generic /new or /new/ page here -> return a list of object types
			-- TODO split off view for render_generic_new from the controller
			print("--debug new_get, we matched the generic new page!") 
			local title = h2(strings.edit_objects)
			local res = {}
			for name,model in pairs(models) do
				if model.form then
					res[#res+1] = li{ a{ href=web:link("/new/"..name), " ", strings[name]}}
				end
			end
			local prevPage = a{href=web:link(web.path_info,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
			local nextPage = a{href=web:link(web.path_info,{offset = offset+limit}), strings.nextPage}
			return admin_layout(web,{user=user,pages=pages},div.group{title,ul(res),br(),prevPage," ",nextPage})
		elseif not models[obj] then
			print("-- debug new_get, no model exists for",obj)
		elseif not models[obj].form then
			print("-- debug new_get, the model does not have a form")
		else -- The model really is editable
			print("-- debug new_get, Your're new",obj, "will be ready soon!")
			-- Get the last assigned autoid, and add 1 to it... will work fine until after 9223372036854775807 inserts in a table ... which I hope no one ever has to enter ;)
			local curs,mess = models[obj].model.conn:execute(([[SELECT seq FROM sqlite_sequence WHERE name = '%s%s']]):format(models[obj].model.table_prefix,models[obj].name))
			local new_id = curs:fetch()+1
			if mess then print("-- debug new_get",obj,"max(id) returned",mess) end 
			if models[obj].form.depends then
				local depends = models[obj].form.depends.."_id"
				if web.GET[depends] then -- if the dependancy already has been provided to the new call, then pass it to the edit page.
					return web:redirect(web:link(("/edit/%s/%s"):format(obj,new_id),{create=1,[depends]=web.GET[depends]}))
				else
					return web:redirect(web:link(("/depends/%s/%s"):format(obj,new_id)))
				end
			else
				return web:redirect(web:link(("/edit/%s/%s"):format(obj,new_id),{create=1}))
			end
		end
	end
end --}}}
bib:dispatch_get(new_get,"/new/(%w+)/?","/new/?")

--- Controller for the dependancy control for making a new object (like a book for a copy)
function depends_get(web,obj,new_id) --{{{
	local user = check_user(web)
	local pages = models.page:find_all()
	local fields,object
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		if obj:match("^/depends/?$") then
			print("--debug depends_get, we need a model for dependancy checking")
			return web:redirect("/new")
		elseif not models[obj] then
			print("--debug depends_get, model does not exist")
			return web:redirect("/new")
		elseif not models[obj].form then
			print("--debug depends_get, model does not have a form")
			return web:redirect("/new")
		elseif not models[obj].form.depends then
			print("--debug depends_get, model has no dependancies")
			return web:redirect("/new/"..obj)
		elseif not new_id then
			print("--debug depends_get, we do need the new id number of what is getting created")
			return web:redirect("/new/")
		else
			local depends = models[obj].form.depends
			local objects = models[depends]:find_all()
			return render_depends(web,{user=user,pages=pages},obj,new_id,objects,depends)	
		end
		return not_found(web)
	end
end --}}}
bib:dispatch_get(depends_get,"/depends/(%w+)/(%d+)/?")

function render_edit(web,args,obj_type,obj,fields) --{{{ fields now is a table of fields.
	local m = models.obj_type
	local tit
	if obj then -- not editing a newly created object
		tit = h2{strings.edit," ", strings[obj_type] ," ",obj.id,": ",obj:concat_fields(obj.form.title,", ") }
	else
		tit = h2{strings.create_new," ",strings[obj_type]}
	end	
	local res={tit}

	for field_n=1,#fields do
		local field=fields[field_n]
		local readonly -- Contains whether this controll will be readonly because a matching GET parameter was found
		local prevVal = obj and obj[field.name] or "" -- fill the undefined values
		if web.GET[field.name] then
			prevVal = web.GET[field.name]
			readonly="readonly"
		end
		res[#res+1] = field.caption
		if field["type"]=="select" then --{{{
			res[#res+1]=('<select name="%s" %s>'):format(field.name,readonly and 'readonly="readonly"' or "")
			if field.options then
				-- construct select out of options
				for n_opt=1,#field.options do
					local option_table = {value=field.options[n_opt], field.options[n_opt]}
					if tostring(field.options[n_opt]) == tostring(prevVal) then -- If this is the current value, select it, so it is default.
						option_table.selected="selected"
					end
					res[#res+1]=option(option_table)
				end
				res[#res+1]='</select>'
			else
				-- construct select out of other model
				-- Build query for returning all elements from a model
				local query={"SELECT id,"}
				query[2]=table.concat(field.fields,",")
				query[3]=" FROM "
				query[4]=field.model.table_name
				query[5]=";"
				local curs,mess = field.model.model.conn:execute(table.concat(query))
				if mess then
					print("--Debug edit_get",mess,field.fields,field.model.table_name)
				end

				local opts = {} -- table which will contain the strings for the selectionbox
				local t = {} -- result table
				while curs:fetch(t) do
					opts[#opts+1]={table.remove(t,1),table.concat(t,', ')} -- pop of the index, concat the rest
				end
				for n_opt=1,#opts do
					local option_table={ value=opts[n_opt][1], opts[n_opt][2]}
					if tostring(prevVal) == tostring(opts[n_opt][1]) then -- If this is the current value, select it, so it is default.
						option_table.selected="selected"
					end
					res[#res+1]=option(option_table)-- Add an option for "None" in the database, not here.
				end
				res[#res+1]='</select>'
				if field.model then
					res[#res+1]=a{ href=web:link("/edit/"..field.model.name.."/"..prevVal),strings.edit," ",strings[field.model.name]:lower()," ",prevVal}
					res[#res+1]=" "
					res[#res+1]=a{ href=web:link("/new/"..field.model.name), strings.new, strings[field.model.name]:lower() }
				end
			end --}}}
		elseif field["type"]=="text" then
			res[#res+1] = input{ name = field.name, ["type"]=field["type"],value=prevVal,readonly=readonly}
		elseif field["type"]=="readonly" then
			res[#res+1] = input{ name = field.name, readonly="readonly", ["type"]="text",value=prevVal~="" and prevVal or field.autogen(models[obj_type],obj,web.GET)} --TODO TODO
		elseif field["type"]=="textarea" then
			res[#res+1] = textarea{ name = field.name, cols="100", rows="10",style="vertical-align:middle",readonly=readonly,prevVal}
			res[#res+1] = br()
			res[#res+1] = a{ href=web:link("/markdown",lang), target="_blank", strings.markdown_expl }
		end	
		res[#res+1]=br()
	end
	if web.input.create=="1" then -- pass the value from create on to the edit_post via the form.
		res[#res+1]=input{ type="hidden",name="create", value ="1"}
	end
	res[#res+1]=br()
	res[#res+1]=input{ type="submit", id="save",   name="op", value=strings.save }
	res[#res+1]=input{ type="submit", id="cancel", name="op", value=strings.cancel }
	res[#res+1]=input{ type="submit", id="delete", name="op", value=strings.delete }
	return admin_layout(web,args,div.group(form{action=web.path_info, method="POST", res}))
end --}}}

-- Views
function login_layout(web, params) --{{{
	return html{
		head{
			title{strings.login_page},
			meta{ ["http-equiv"]="Content-Type",content="text/html; charset=utf-8" },
			-- link{ rel="stylesheet", type = 'text/css', href = web:static_link('/admin_style.css'), media ='screen'}
		},
		body{
			div{ id="container",
				div{ id = "header", title="sitename", "Bib.lua ",strings.login_page },
				div{ id = "mainnav",
					ul{
						li{ a{ href = web:link"/",strings.homepage_name} }
					}
				},
				div{ id="contents",
					p.error(params.result_login),
					fieldset{
						legend{strings.login_page},
						form{ name="login", method="post", action=web:link("/login"), 
							strings.user_id,  input{ type="text", name="login",value=params.login or ""},
							strings.password, input{ type="password", name="password"},
							input{ type="submit",value=strings.login_button },
							input{ type = "hidden", name = "link_to", value = params.link_to },
						}
					},
				div{ id="footer",markdown(strings.copyright_notice) }
				}
			}
		}
	}
end --}}}

--- View-template for the adminpages, inner_html being render_admin or whatever.
function admin_layout(web, args, inner_html, rightsidebar) --{{{
	-- Args needed are:
	-- 	pages = all pages in the DB
	-- 	user = logged in user
	--
	return html{
		head{
			title{"Bib.lua ",strings.administration},
			meta{ ["http-equiv"] = "Content-Type", content = "text/html; charset=utf-8" },
			link{ rel = 'stylesheet', type = 'text/css', href = web:static_link('/admin_style.css'), media = 'screen' }
		},
		body{
			div{ id = "container",
				div{ id = "header", title = "sitename", "Bib.lua ",strings.administration },
				div{ id = "menu", _menu(web,args) }, -- Uses the same _menu as in layout
				div{ id = "sidebar", _admin_sidebar(web, args) },  
				div{ id = "contents", inner_html },
				rightsidebar and div{ id="sidebar_right",style="clear:both", rightsidebar} or "",
				div{ id = "footer", markdown(strings.copyright_notice) }
			}
		}
	} 
end

function _admin_sidebar(web,args)
	local res = {}
	if user then
		res[#res + 1] = ul{
			li{ a{ href = web:link("/admin")	, strings.admin_home } },
			li{ a{ href = web:link("/new")		, strings.new,strings.object } },
			li{ a{ href = web:link("/edit")		, strings.edit,strings.object } },
			}
		res[#res + 1] = h3(strings.sections)
		local section_list = {}
		for section,name in ipairs({page=strings.page}) do
			section_list[#section_list + 1] = 
			li{ a{ href=web:link("/admin/" .. section), name } }
		end
		res[#res + 1] = ul(table.concat(section_list,"\n"))
	end
	return table.concat(res, "\n")
end --}}}

function render_admin(web,args, params) --{{{
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local part1 = {
		h2(strings.admin_home),
		h3(strings.lendings)
		}
	local ft = { input{type="text",name="lend_copy",value=web.GET.lend_copy},'<select name="user_id">'}
	for k=1,#args.allusers do
		local user=args.allusers[k]
		ft[#ft+1]=option{value=user.id,user.id,":",user.real_name}
	end
	ft[#ft+1]='</select>'
	ft[#ft+1]=input{type="submit",name="op",value=strings.lend_copy}
	ft2={
		input{type="text",name="return_copy",value=web.GET.return_copy},
		input{type="submit",name="op",value=strings.return_copy}
		}
	local part2 =  h3(strings.overdues)
	local tab_body={
		tr{
			th(strings.days),
			th(strings.name),
			th(strings.book),
			th(strings.copy_code),
			th(strings.telephone),
			--th{strings.email}
		}
	}
	for k = 1,#args.overdues do
		local item=args.overdues[k]
		local class
		if k%2==1 then class="alt" end --TODO CSS color according urgency.
		tab_body[#tab_body+1]= tr{td(tostring(math.floor(item.overdue))), td(item.real_name), td(item.title), td(item.copy_code), td(tostring(item.telephone))}
	end
	local url = web.path_info:gsub("/+$","") -- Strip extra // and make sure there is 1
	local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
	local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
	return admin_layout(web,args,{part1,form{name="lend",action=web.path_info, method="POST",ft},form{name="return",action=web.path_info, method="POST",ft2},
		part2,'<table id="overdues">',tab_body,'</table>',prevPage,nextPage},
		_sort_sidebar(web,args.fields,order,orderby,limit,offset))
	
end --}}}

function render_login(web,args,params) --{{{
   local res = {}
   local err_msg = ""
   if params.not_match then
      err_msg = p{ error_message(strings.password_not_match) }
   elseif params.not_found then
      err_msg = p{ error_message(strings.user_not_found) }
   end
   res[#res + 1] = h2"Login"
   res[#res + 1] = err_msg
   res[#res + 1] = form{
      method = "post",
      action = web:link("/login"),
      input{ type = "hidden", name = "link_to", value = params.link_to },
      p{
	 strings.login, br(), input{ type = "text", name = "login",
	    value = params.login or "" },
	 br(), br(),
	 strings.password, br(), input{ type = "password", name = "password" },
	 br(), br(),
	 input{ type = "submit", value = strings.login_button }
      }
   }
   return div(res)
end --}}}
--- Renders the delete page
function render_delete(web,args,object) --{{{
	local res = {
		h2{strings.delete, " ", strings[object.name]:lower(), " ", object.id,": ",object:concat_fields(object.form.title,", ")},
		div.group{(strings.confirm_delete:gsub("@(%w)",{a=object:concat_fields(object.form.title," ,"),b=object.name,c=object.id}))},
		form{ action = web.path_info, method = "POST",
			input{ type="submit", id="cancel", name="op", value=strings.cancel},
			input{ type="submit", id="delete", name="op", value=strings.delete},
			input{ type="hidden", name="link_to", value = web.input.link_to }
		}
	}
	print("--debug render_delete, link_to= ", web.input.link_to)
	return admin_layout(web,args,res)
end --}}}

--- Renders the dependancy resolution page
function render_depends(web,args,obj_type,new_id,objects,depends) --{{{
	local title = h2(strings.dependancy_title)
	local expl_text = div.mesg(strings.dependancy_expl:gsub("@(%w)",{a=strings[obj_type],b=strings[depends]}))
	local form_tab = {input{type="hidden",name="create",value="1"},('<select name=%s%s>'):format(depends,"_id")}
	local obj_form = models[depends].form
	for n_obj=1,#objects do
		form_tab[#form_tab+1]=option{value=objects[n_obj].id, objects[n_obj]:concat_fields(obj_form.title)}
	end
	print(table.concat(form_tab,"\n"))
	form_tab[#form_tab+1] = '</select>'
	form_tab[#form_tab+1] = input{ type="submit", id="submit", value=strings.confirm}
	print(form{form_tab})
	return admin_layout(web,args,{title,expl_text,form{action=web:link(("/edit/%s/%s"):format(obj_type,new_id)),method="GET",form_tab}})
end --}}}

--[[ TODO up to here
function render_add_user(web, params)
   local error_login, error_password, error_name = "", "", ""
   if params.error_login then 
      error_login = error_message(params.error_login) .. br()
   end
   if params.error_password then 
      error_password = error_message(params.error_password) .. br()
   end
   if params.error_name then 
      error_name = error_message(params.error_name) .. br()
   end
   return div{
      h2(strings.new_user),
      form{
	 method = "post",
	 action = web:link("/adduser"),
	 p{
	    strings.login, br(), error_login, input{ type = "text",
	       name = "login", value = params.login }, br(), br(),
	    strings.password, br(), error_password, input{ type = "password",
	       name = "password1" }, br(),
            input{ type = "password", name = "password2" }, br(), br(),
	    strings.name, br(), error_name, input{ type = "text",
	       name = "name", value = params.name }, br(), br(),
	    input{ type = "submit", value = strings.add }
	 }
      },
   }
end

function render_edit_section(web, params)
   local error_title = ""
   if params.error_title then
      error_title = error_message(params.error_title) .. br()
   end
   local page_header, button_text
   if not params.section.id then
      page_header = strings.new_section
      button_text = strings.add
   else
      page_header = strings.edit_section
      button_text = strings.edit
   end
   local action
   local delete
   if params.section.id then
      action = web:link("/editsection/" .. params.section.id)
      delete = form{ method = "post", action = web:link("/deletesection/" ..
							params.section.id), 
	 input{ type = "submit", value = strings.delete } }
   else
      action = web:link("/editsection")
   end
   return div{
      h2(page_header),
      form{
	 method = "post",
	 action = action,
	 p{
	    strings.title, br(), error_title, input{ type = "text",
	       name = "title", value = params.title or params.section.title },
	    br(), br(),
	    strings.description, br(), textarea{ name = "description",
	       rows = "5", cols = "40", params.description or
		  params.section.description }, br(), br(),
	    strings.tag, br(), input{ type = "text", name = "tag",
	       value = params.tag or params.section.tag }, br(), br(),
	    input{ type = "submit", value = button_text }
	 }
      }, delete
   }
end

function render_edit_post(web, params)
   local error_title = ""
   if params.error_title then
      error_title = error_message(params.error_title) .. br()
   end
   local page_header, button_text
   if not params.post.id then
      page_header = strings.new_post
      button_text = strings.add
   else
      page_header = strings.edit_post
      button_text = strings.edit
   end
   local action
   local delete
   if params.post.id then
      action = web:link("/editpost/" .. params.post.id)
      delete = form{ method = "post", action = web:link("/deletepost/" ..
							params.post.id), 
	 input{ type = "submit", value = strings.delete } }
   else
      action = web:link("/editpost")
   end
   local sections = {}
   for _, section in pairs(params.sections) do
      sections[#sections + 1] = option{ value = section.id, 
	 selected = (section.id == (tonumber(params.section_id) or
				    params.post.section_id)) or nil, 
	 section.title }
   end
   sections = "<select name=\"section_id\">" .. table.concat(sections, "\n") ..
      "</select>"
   local comment_status = {}
   for status, text in pairs({ closed = strings.closed, 
			        moderated = strings.moderated,
				unmoderated = strings.unmoderated }) do
      comment_status[#comment_status + 1] = option{ value = status,
	 selected = (status == (params.comment_status or 
				params.post.comment_status)) or nil, text }
   end
   local comment_status = "<select name=\"comment_status\">" ..
      table.concat(comment_status, "\n") .. "</select>"
   return div{
      h2(page_header),
      form{
	 method = "post",
	 action = action,
	 p{
	    strings.section, br(), sections, br(), br(),
	    strings.title, br(), error_title, input{ type = "text",
	       name = "title", value = params.title or params.post.title },
	    br(), br(),
	    strings.index_image, br(), error_title, input{ type = "text",
	       name = "image", value = params.image or params.post.image },
	    br(), br(),
	    strings.external_url, br(), input{ type = "text",
	       name = "external_url", value = params.external_url or 
		  params.post.external_url },
	    br(), br(),
	    strings.abstract, br(), textarea{ name = "abstract",
	       rows = "5", cols = "40", params.abstract or
		  params.post.abstract }, br(), br(),
	    strings.body, br(), textarea{ name = "body",
	       rows = "15", cols = "80", params.body or
		  params.post.body }, br(), br(),
	    strings.comment_status, br(), comment_status, br(), br(),
	    strings.published_at, br(), input{ type = "text",
	       name = "published_at", value = params.published_at or
		  os.date("%d-%m-%Y %H:%M", params.post.published_at) }, br(), br(),
	    input{ type = "checkbox", name = "published", value = "1",
	       checked = params.published or params.post.published or nil },
	    strings.published, br(), br(),
	    input{ type = "checkbox", name = "in_home", value = "1",
	       checked = params.in_home or params.post.in_home or nil },
	    strings.in_home, br(), br(),
	    input{ type = "submit", value = button_text }
	 }
      }, delete
   }
end

function render_manage_comments(web, params)
   local for_mod = {}
   for _, comment in ipairs(params.for_mod) do
      for_mod[#for_mod + 1] = div{
	 p{ id = comment.id, strong{ strings.comment_by, " ", 
	       comment:make_link(), " ",
	       strings.on_post, " ", a{ 
		  href = web:link("/post/" .. comment.post_id), comment.post_title },
	       " ", strings.on, " ", time(comment.created_at), ":" } },
	 markdown(comment.body),
	 p{ form{ action = web:link("/comment/" .. comment.id .. "/approve"),
	       method = "post", input{ type = "submit", value = strings.approve }
	    }, form{ action = web:link("/comment/" .. comment.id .. "/delete"),
	       method = "post", input{ type = "submit", value = strings.delete }
	    }
	 },
      }
   end
   local approved = {}
   for _, comment in ipairs(params.approved) do
      approved[#approved + 1] = div{
	 p{ id = comment.id, strong{ strings.comment_by, " ", 
	       comment:make_link(), " ",
	       strings.on_post, " ", a{ 
		  href = web:link("/post/" .. comment.post_id), comment.post_title },
	       " ", strings.on, " ", time(comment.created_at), ":" } },
	 markdown(comment.body),
	 p{ form{ action = web:link("/comment/" .. comment.id .. "/delete"),
	       method = "post", input{ type = "submit", value = strings.delete }
	 } },
      }
   end
   if #for_mod == 0 then for_mod = { p{ strings.no_comments } } end
   if #approved == 0 then approved = { p{ strings.no_comments } } end
   return div{
      h2(strings.waiting_moderation),
      table.concat(for_mod, "\n"),
      h2(strings.published),
      table.concat(approved, "\n")
   }
end
--]]
orbit.htmlify(bib, "_.+", "admin_layout","login_layout", "render_.+","edit_get","new_get")
-- vim:fdm=marker
