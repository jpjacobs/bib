
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
		local query = ([[SELECT julianday("now")-julianday(date_return) AS overdue, bib_lending.copy_id, bib_copy.book_id, bib_book.title, bib_book.id||"/"||copy_id as copy_code, user_id, bib_user.real_name, bib_user.telephone, bib_user.email
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
					print("--warn admin_post, no un-reserved copies available, lending NOT made")
					return web:redirect(web:link("/admin")) -- TODO message & link_to 
				else
					local t=models.lending:new()
					t.user_id = user_lend.id
					t.copy_id = copy.id
					t.date_return = os.date("%Y-%m-%d",os.time()+86400*7*3) -- TODO hardcodedvalue warning!
					t:save()
					local r = models.reservation:find_by_user_id_and_book_id({user_lend.id,copy.book_id})
					if r then
						--print("--debug admin_post, reservation",r.id,"deleted") 
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
			return web:redirect(web:link("/admin")) -- TODO message & link_to --}}}
		elseif web.POST.op==strings.reserve then --{{{
			local book_id = web.POST.reserve_book:match("%d+")
			local user_id = web.POST.user_id:match("%d+")
			-- Check user, Check id, check book exists, check previous reservation, check lendings if already lend
			if not user_id then
				print("--warn user_id should be numerics only")
			elseif not models.user:find(tonumber(user_id)) then
				print("--warn user",user_id,"does not exist in the DB")
			elseif not book_id then
				print("--warn reserve_book malformed, should contain a decimals only book_id")
			elseif not models.book:find(book_id) then
				print("--warn book with id",book_id,"does not exists in the DB")
			elseif models.reservation:find_first("user_id = ? and book_id = ?",{user_id,book_id}) then
				print("--warn a reservation for book",book_id,"already exists for user",web.POST.user_id)
			else
				local copies = models.copy:find_all("book_id = ?",book_id)
				local copy_ids = {}
				for k=1,#copies do
					copy_ids[k]=copies[k].id
				end
				if models.lending:find_first("user_id = ? and copy_id = ?",{user_id,copy_ids}) then
					print("--warn user",web.POST.user_id," still has a copy of book",book_id)
				else
					local t=models.reservation:new()
					t.user_id = user_id
					t.book_id = book_id
					t.date = os.date("%Y-%m-%d")
					t:save()	
					print("reserved",web.POST.reserve_book)
				end
			end
			return web:redirect(web:link("/admin")) -- TODO message & link_to --}}}
		elseif web.POST.op==strings.cancel_reservation then --{{{
			local reservation_id = web.POST.cancel_reservation:match("%d+")
			-- Check user, Check id, check book exists, check previous reservation, check lendings if already lend
			if not reservation_id then
				print("--warn reservation_id should be numerics only")
			end
			local reservation = models.reservation:find(tonumber(reservation_id)) 
			if not reservation then
				print("--warn reservation",reservation_id,"does not exist in the DB")
			end
			reservation:delete()	
			print("canceled reservation",web.POST.cancel_reservation)
			return web:redirect(web:link("/admin")) -- TODO message & link_to --}}}
		else
			return not_found(web)

		end
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
			print("-- warn edit_get: no model found for type ",obj_type)
			return not_found(web) --TODO rewrite not_found to include an error message
		elseif not models[obj_type].form then -- The model obj_type exists, but isn't editable (eg, has no form)
			print("--warn edit_get","object type doesn't have a form-table, add form table to the model")
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
						print("--warn edit object not found and create ~= 1")
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

	local function save_multi_field(input,this_object,this_model,this_form,this_field) --{{{
		-- Truth table + actions for this
		-- tag in form		0	0	1	1
		-- tag in object	0	1	0	1
		-- 00,11 -> nop
		-- 01 -> add link between info and object, if not existing in models.tag then make new
		-- 10 -> remove link between info and object (implement here for automatic collection of unused tags)
		-- Separate infos from list (comma-seperated)
		local infos={}
		-- Make sure there is a tag -- TODO copy to validation function
		for info_text in (input..","):gmatch("%s*(%w+)%s*,") do
			local info = this_field.model:find_first(this_field.field.." = ?",{info_text})
			if not info then -- Make new info!
				if this_field.model.form.valid then
					info_text=this_field.model.form.valid(info_text)
				end
				if info_text then -- it was either validated or not checked
					info = this_field.model:new()
					info[this_field.field] = info_text
					info:save()
					print("--debug edit_post, created new tag:",info_text)
				end
			end
			if info_text then -- it was either validated or not checked
				infos[#infos+1]=info
				print("--debug edit_post: found tag",info,"with id",info.id)
			end
		end -- after this, info_texts contain all infos in the form
		local infos_rev = {} -- Build a reverse table, which contains true for all info_id's that have been given in the form
		for _,info in pairs(infos) do
			infos_rev[info.id]=true
		end

		-- Get link_model id's for the current object
		local cur_links = this_field.model_link:find_all(this_object.name.."_id = ?",{this_object.id})
		local cur_infos_ids = {}
		local info_id_name = this_field.model.name.."_id"
		for k=1,#cur_links do
			cur_infos_ids[cur_links[k][info_id_name]]=true
			print("--debug edit_post, found connection to this object with info",cur_links[k][info_id_name])
		end
		-- verify all infos
		for _,info in pairs(infos) do -- loop through all info in the form
			if not cur_infos_ids[info.id] then -- in the form and not linked to the object
				-- create new link
				local new_link = this_field.model_link:new()
				new_link[this_field.model.name.."_id"]=info.id
				new_link[this_object.name.."_id"]=this_object.id
				new_link:save()
				print("--debug edit_post, created link from object to tag",this_field.model:find(info.id).tag_text)
			end -- else there was already a link, and no new link needs to be made
		end
		for info_id in pairs(cur_infos_ids) do -- loop through all infos linked to the object
			if not infos_rev[info_id] then -- it's not in the form and it's linked to the object
				-- remove link
				local link = this_field.model_link:find_first(("%s_id = ? and %s_id = ?"):format(this_object.name,this_field.model.name),{this_object.id,info_id})
				link:delete()
				print("--debug edit_post, removed link from object to tag",this_field.model:find(info_id).tag_text)
			end -- else, it's also in the form, and nothing has to be done
		end
	end --}}}

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
				for idx=1,#this_object.form.fields do
					local this_field=this_object.form.fields[k]
					if this_field["type"]=="upload" then
						print("--debug edit_post, delete, moving uploaded file",this_object[this_field],"to trash")
						os.rename(this_object[this_field],bib.real_path.."trash/"..this_object[this_field])
					end
				end
				return web:redirect(web:link("/edit/"..obj))
			else
				--print("--debug edit_post, link_to = ",web.path_info)
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
						local this_field = this_form.fields[k]
							--if this_field["type"]=="select_disabled" or this_field["type"] == "read_only" then
							-- These types don't change anything any way... so just jump out of the loop here
						--else
						if this_field.valid then -- Form field contains a validation function, receives string to validate/filter and the object
							local dummy -- To protect the field from getting overwritten upon errors
							dummy,mesg[#mesg+1]=this_field.valid(v,this_object) -- if there is a message, capture and forward.
							if dummy and tostring(this_object[k]) ~= dummy then -- TODO check this whole if-then-else-structure
								field_changed,obj_changed = true,true
								if this_field["type"] == "multi" then -- The multi type is the only one not getting saved to the object itself
									print("--debug Validation function returned ok, and field is multi")
									save_multi_field(v,this_object,this_model,this_form,this_field)
									-- if they are not the same, save, else ignore
								else
									this_object[k]=dummy -- TODO change
								end
							else
							-- TODO Checkme, why is this here?
							end
						else -- no validation function present for this field
							if tostring(this_object[k])~=v then -- the value is new
								field_changed,obj_changed = true,true
								if this_form.fields[k]["type"] == "multi" then -- The multi type is the only one not getting saved to the object itself
									print("--debug no Validation function field is multi")
									save_multi_field(v,this_object,this_model,this_form,this_field)
								else
									this_object[k]=v  -- TODO Change
								end
							end
						end
						if this_form.fields[k].update and field_changed then -- Field has an update function
							this_form.fields[k].update(k,this_object) 
						end
					end
				end
				print("--debug edit_post, this_object=",tprint(this_object))
				this_object:save()
			end
			return web:redirect(web:link("/edit/"..obj.."/"..id),{mesg=mesg}) --}}}
		elseif web.POST.op==strings.cancel then
			if web.POST.create == "1" then
				print("--debug edit_post, deleted object",this_object.name,this_object.id)
				this_object:delete()
			end
			return web:redirect(web:link("/edit/"..obj)) -- TODO use link_to
		elseif web.POST.op==strings.upload then -- Handles uploading of files
			print("--debug edit_post, we're uploading a file")
			for var,value in pairs(web.POST) do
				if this_form.fields[var] and this_form.fields[var]["type"] == "upload" then
					print("--debug tprint(web.POST)", tprint(web.POST))
					local f=web.POST[var] -- Handles uploading of files
					print("--debug edit_post,",var,"= ",f.name)--tprint(f))
					if type(f)=="table" then
						this_object.ext=f.name:match(".*%.(%w%w+)$") -- save the extension temporarly to the object
						print("--debug edit_post, var is",var,"and ext is",this_object.ext,"and this_form.file1 is",tprint(this_form.fields[var]))
						if not this_form.fields[var].accept[this_object.ext:lower()] then
							print("--warn edit_post: extension",this_object.ext,"not supported for field",var)
						else -- TODO message
							local filename=this_form.fields[var].location:gsub("@([%w_]+)",this_object):gsub("[^%w%-/%.]","_") -- Optional check for clean filenames.
							this_object.ext=nil -- wipe extension from the object, for 
							print("--debug edit_post, writing uploaded file to",filename)
							local dest = io.open(web.real_path..filename,"wb")
							if dest then
								dest:write(f.contents)
								dest:close()
								this_object[var]=filename
								this_object:save()
								print("--debug this_object after save",tprint(this_object))
							else
								print("--warn edit_post, could not open file",filename,"for writing")
								-- Return a TODO message
							end
						end
					end --TODO return message if nothing filled in?
				end
			end
			return web:redirect(web:link(("/edit/%s/%s"):format(obj,id))) --TODO use link_to
		elseif web.POST.op==strings.delete_file then -- Handles removing of uploaded files.
			print("--debug removing file for field",web.POST.fieldname)
			local function deleteFile(fieldname)
				local filename=this_object[fieldname]
				this_object[fieldname] = nil
				this_object:save()
				if not os.rename(bib.real_path..filename,bib.real_path.."trash"..filename) then
					print("--warn, could not move file",filename," to trash, try manually")
				end
			end

			if type(web.POST.fieldname) == "string" then -- Only one file checked for deletion
				deleteFile(web.POST.fieldname)
			elseif type(web.POST.fieldname) == "table" then -- More than one file checked for deletion
				for k=1,#web.POST.fieldname do
					deleteFile(web.POST.fieldname[k])
				end
			end -- else do nothing and return to page anyway

			return web:redirect(web:link(("/edit/%s/%s"):format(obj,id))) --TODO use link_to
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
			--print("--debug new_get, we matched the generic new page!") 
			local title = h2(strings.edit_objects)
			local res = {}
			for name,model in pairs(models) do
				if model.form then
					res[#res+1] = li{ a{ href=web:link("/new/"..name), " ", strings[name]}}
				end
			end
			-- TODO prev/next page are overkill here.
			local prevPage = a{href=web:link(web.path_info,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
			local nextPage = a{href=web:link(web.path_info,{offset = offset+limit}), strings.nextPage}
			return admin_layout(web,{user=user,pages=pages},div.group{title,ul(res),br(),prevPage," ",nextPage})
		elseif not models[obj] then
			print("--warn new_get, no model exists for",obj)
		elseif not models[obj].form then
			print("--warn new_get, the model does not have a form")
		else -- The model really is editable
			-- Get the last assigned autoid, and add 1 to it... will work fine until after 9223372036854775807 inserts in a table ... which I hope no one ever has to enter ;)
			local curs,mess = models[obj].model.conn:execute(([[SELECT seq FROM sqlite_sequence WHERE name = '%s%s']]):format(models[obj].model.table_prefix,models[obj].name))
			local new_id = curs:fetch()+1
			if mess then print("--warn new_get",obj,"max(id) returned",mess) end 
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
			print("--warn depends_get, we need a model for dependancy checking")
			return web:redirect("/new")
		elseif not models[obj] then
			print("--warn depends_get, model does not exist")
			return web:redirect("/new")
		elseif not models[obj].form then
			print("--warn depends_get, model does not have a form")
			return web:redirect("/new")
		elseif not models[obj].form.depends then
			print("--warn depends_get, model has no dependancies")
			return web:redirect("/new/"..obj)
		elseif not new_id then
			print("--warn depends_get, we do need the new id number of what is getting created")
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


--- Controller for the lendings page
function lendings_get(web) --{{{
	local user = check_user(web)
	local pages = models.page:find_all()
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		local def_entries = 20
		local order = web.input.order or "ASC"
		local limit = tonumber(web.input.limit) or def_entries
		local offset = tonumber(web.input.offset) or 0
		if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
			order = "ASC"
		end
		limit = limit >= 0 and limit or def_entries -- The maximum number of results to return (number or nil)
		offset = offset >=0 and offset or 0 -- The offset from book 0 (number or nil)
		local fields = {date_return="date_return",copy_code="copy_code",real_name="real_name",user_id="user_id",title="title"}
		local orderby = web.input.orderby and web.input.orderby:lower() or "date_return"-- The search criterium
		-- Sanitation of the parameters
		orderby = fields[orderby] or "date_return"
		-- Find users that have over-due books
		-- using SQL because of WAY to complicated using Orbit
		local query = ([[SELECT date_return, bib_book.title, bib_copy.book_id, bib_lending.copy_id, bib_book.id||"/"||copy_id AS copy_code, user_id, bib_user.real_name, bib_user.telephone, bib_user.email
		FROM bib_lending, bib_user, bib_book, bib_copy
		WHERE bib_lending.copy_ID = bib_copy.id -- connect copy with lending
		and bib_copy.book_id = bib_book.id -- connect copy with book
		and bib_lending.user_ID = bib_user.id -- connect user with lending
		ORDER BY %s %s LIMIT %s OFFSET %s;]]):format(orderby,order,limit,offset)
		local curs,err = models.book.model.conn:execute(query)
		if err then print("-- warn, lendings query in lendings_get returned ",err) end
		local lendings = {}
		local t={}
		while curs:fetch(t,"a") do
			lendings[#lendings+1] = t
			t={}
		end
		-- TODO pass fields for sorting sidebar
		return render_lendings(web,{user=user,lendings=lendings,fields=fields,order=order,limit=limit,offset=offset,orderby=orderby})
	end
end --}}}
bib:dispatch_get(lendings_get,"/lendings/?")

--- Controller for the reservations page
function reservations_get(web) --{{{
	local user = check_user(web)
	local pages = models.page:find_all()
	if not user or user.is_admin ~= 1 then
		return web:redirect(web:link("/login",{link_to=web.path_info,no_admin="1"}));
	else
		local def_entries = 20
		local order = web.input.order or "ASC"
		local limit = tonumber(web.input.limit) or def_entries
		local offset = tonumber(web.input.offset) or 0
		if order:upper() ~= "ASC" and order:upper() ~="DESC" then -- Only allow asc or desc
			order = "ASC"
		end
		limit = limit >= 0 and limit or def_entries -- The maximum number of results to return (number or nil)
		offset = offset >=0 and offset or 0 -- The offset from book 0 (number or nil)
		local fields = {date="date",book_id="book_id",real_name="real_name",user_id="user_id",title="title"}
		local orderby = web.input.orderby and web.input.orderby:lower() or "date"-- The search criterium
		-- Sanitation of the parameters
		orderby = fields[orderby] or "date"
		-- Find users that have over-due books
		-- using SQL because of WAY to complicated using Orbit
		local query = ([[SELECT date, bib_book.title, bib_reservation.book_id, user_id, bib_user.real_name, bib_user.telephone, bib_user.email, bib_reservation.id as reservation_id
		FROM bib_reservation, bib_user, bib_book
		WHERE bib_reservation.book_id = bib_book.id -- connect copy with reservation
		and bib_reservation.user_id = bib_user.id -- connect user with reservation
		ORDER BY %s %s LIMIT %s OFFSET %s;]]):format(orderby,order,limit,offset)
		local curs,err = models.book.model.conn:execute(query)
		if err then print("-- warn, reservations query in reservations_get returned ",err) end
		local reservations = {}
		local t={}
		while curs:fetch(t,"a") do
			reservations[#reservations+1] = t
			local book = models.book:find(t.book_id)
			local all_copies = models.copy:find_all("book_id = ?",{t.book_id})
			local all_copies_ids ={}
			for k=1,#all_copies do
				all_copies_ids[k] = all_copies[k].id
			end
			local copies_lend = models.lending:find_all("copy_id = ?",{all_copies_ids})
			local copies_available = #all_copies - #copies_lend
			local older_reservations = models.reservation:find_all(('book_id = ? and julianday(date) < julianday("%s")'):format(t.date),{t.book_id})
			if copies_available - #older_reservations > 0 then
				t.available = true
			end
			t={}
		end
		-- TODO pass fields for sorting sidebar
		return render_reservations(web,{user=user,reservations=reservations,fields=fields,order=order,limit=limit,offset=offset,orderby=orderby})
	end
end --}}}
bib:dispatch_get(reservations_get,"/reservations/?")

-- Views
function login_layout(web, params) --{{{
	return html{
		head{
			title{strings.login_page},
			meta{ ["http-equiv"]="Content-Type",content="text/html; charset=utf-8" },
			link{ rel="stylesheet", type = 'text/css', href = web:static_link('/css/style.css'), media ='screen'}
		},
		body{
			div{ id="container",
				div{ id = "header", title="sitename", h1{strings.header," ",strings.login_page}},
				div{ id = "sidebar",
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
				},
				div{ id="footer",markdown(strings.copyright_notice) }
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
			link{ rel = 'stylesheet', type = 'text/css', href = web:static_link('/css/style.css'), media = 'screen' }
		},
		body{
			div{ id = "container",
				div{ id = "header", title = "sitename", h1{strings.header," ",strings.administration}},
				div{ id = "menu", _menu(web,args) }, -- Uses the same _menu as in layout
				div{ id = "sidebar", _admin_sidebar(web, args) },  
				rightsidebar and div{ id="sidebar_right", rightsidebar} or "",
				div{ id = "contents", inner_html },
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
--- Renders the administration inner_html
function render_admin(web,args, params) --{{{
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local header1 = {
		}
	users_select={}
	for k=1,#args.allusers do
		local user=args.allusers[k]
		users_select[#users_select+1]=option{value=user.id,user.id,":",user.real_name}
	end

	local form_lend = { input{type="text",name="lend_copy",value=web.GET.lend_copy},'<select name="user_id">',users_select,'</select>',
		input{type="submit",name="op",value=strings.lend_copy}
		}
	local form_return={
		input{type="text",name="return_copy",value=web.GET.return_copy},
		input{type="submit",name="op",value=strings.return_copy}
	}
	local form_reserve_book = {
		input{ type="text",name="reserve_book",value=web.GET.reserve_book},'<select name="user_id">',users_select,'</select>',
		input{ type="submit",name="op",value=strings.reserve}
	}
	local form_cancel_reservation= {
		input{ type="text",name="cancel_reservation",value=web.GET.cancel_reservation},
		input{ type="submit",name="op",value=strings.cancel_reservation}
	}
	local overdues_table
	if #args.overdues == 0 then
		overdues_table = strings.warn.no_overdues
	else
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
			tab_body[#tab_body+1]= tr{ class=class,
				td(tostring(math.floor(item.overdue))),
				td(item.real_name),
				td(a{href=web:link("/book/"..item.book_id, {copy=item.copy_id}),item.title}),
				td(item.copy_code),
				td(tostring(item.telephone))
				}
		end
		local url = web.path_info:gsub("/+$","") -- Strip extra // and make sure there is 1
		local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
		local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
		overdues_table = {'<table id="overdues">',tab_body,'</table>',prevPage," ",nextPage}
	end
	return admin_layout(web,args,{
		h2(strings.admin_home),
		h3(strings.lendings),
			form{name = "lend",action=web.path_info, method="POST",form_lend},
			form{name = "return",action=web.path_info, method="POST",form_return},
			a { href = "/lendings",strings.lendings_list},
		h3(strings.reservations),
			form{name = "reserve",action=web.path_info, method="POST",form_reserve_book},
			form{name = "cancel_reservation",action=web.path_info, method="POST",form_cancel_reservation},
			a { href = "/reservations",strings.reservations_list},
		h3(strings.overdues),
		overdues_table},
		_sort_sidebar(web,args.fields,order,orderby,limit,offset))
	
end --}}}
--- Renders the login's inner_html
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
--- Renders the editing inner_html
function render_edit(web,args,obj_type,obj,fields) --{{{ fields now is a table of fields.
	local this_model = models[obj_type]
	local tit
	if obj then -- not editing a newly created object
		tit = h2{strings.edit," ", strings[obj_type] ," ",obj.id,": ",obj:concat_fields(obj.form.title,", ") }
	else
		print("--debug render_edit, obj_type=",obj_type)
		tit = h2{strings.create_new," ",strings[obj_type]}
	end	
	local res={tit}

	for field_n=1,#fields do
		local field=fields[field_n]
		local readonly -- Contains whether this controll will be readonly because a matching GET parameter was found
		local prevVal = obj and obj[field.name] or "" -- fill the undefined values
		if web.GET[field.name] then
			print("--debug render_edit, web.GET[",field.name,"]=",web.GET[field.name])
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
		elseif field["type"]=="select_disabled" then --{{{
			-- construct select out of other model
			-- Build query for returning all elements from a model
			local str
			if field.model then -- If there is a model, get the object, and write it's readable name instead of the ID
				local refObj = field.model:find(prevVal) -- TODO TODO hier loopt het mis met het verversen na het POSTen van de data.
				str = refObj:concat_fields(field.fields)
			end
			res[#res+1]=input{ name = field.name.."fake", size="35", readonly="readonly", ["type"]="text",value=str}
			res[#res+1]=input{ name = field.name, type="hidden",value=web.GET[field.name]}
			if field.model then
				res[#res+1]=a{ href=web:link("/edit/"..field.model.name.."/"..prevVal),strings.edit," ",strings[field.model.name]:lower()," ",prevVal}
				res[#res+1]=" "
				res[#res+1]=a{ href=web:link("/new/"..field.model.name), strings.new, strings[field.model.name]:lower() }
			end --}}}
		elseif field["type"]=="text" then
			res[#res+1] = input{ name = field.name, ["type"]=field["type"],value=prevVal,readonly=readonly}
		elseif field["type"]=="readonly" then
			res[#res+1] = input{ name = field.name, readonly="readonly", ["type"]="text",value=prevVal~="" and prevVal or field.autogen(models[obj_type],obj,web.GET)}
		elseif field["type"]=="textarea" then
			res[#res+1] = textarea{ name = field.name, cols="100", rows="10",style="vertical-align:middle",readonly=readonly,prevVal}
			res[#res+1] = br()
			res[#res+1] = a{ href=web:link("/markdown",lang), target="_blank", strings.markdown_expl }
		elseif field["type"]=="multi" then -- For n-to-n relations as in tags for books
			local links = field.model_link:find_all(("%s_id = ?"):format(obj.name),{obj.id}) -- Find all links where the id is that of the object being edited.
			local str=""
			if #links >0 then
				local info_ids = {} -- Build a table containing all the id's of the used info bits.
				local info_id_str = field.model.name.."_id"
				for k=1,#links do
					info_ids[k] = links[k][info_id_str]
				end
				local infos = {}
				print("--debug render_edit, tprint(info_ids)",tprint(info_ids))
				local infos = field.model:find_all("id = ?",{info_ids}) -- Get all needed infos
				local info_texts = {}
				for k=1,#infos do
					info_texts[k]=infos[k][field.field]
				end
				str = table.concat(info_texts,", ")
				print("--debug render_edit, str=",str)
			else
				print("--debug render_edit, no tags found, str= ''")
			end
			res[#res+1] = input{ name = field.name, size="35", ["type"]="text",value=str}
		elseif field["type"] == "upload" then -- For uploading electronic documents, covers, ... to the server running bib.lua
			local accept = {}
			for k,v in pairs(field.accept) do
				accept[#accept+1] = v
			end
			res[#res+1] = input{ type="file", name = field.name, size="35",accept=table.concat(accept,",")} --handling accepted types
			res[#res+1] = input{ type="submit", name = "op", value=strings.upload}
			print("--debug render_edit, prevVal= ",prevVal)
			if prevVal ~= "" then
				res[#res+1] = input{ type="submit", name = "op", value=strings.delete_file}
				res[#res+1] = strings.warn.delete_file_sure
				res[#res+1] = input{ type="checkbox", name = "fieldname", value=field.name}
				res[#res+1] = a{ href=web:link(prevVal), target="_blank", strings.show_file}
			end
			-- We need here : upload box, if already existing, link to file and one to delete it.
			-- For the post part see: /home/jpjacobs/.luarocks/lib/luarocks/rocks/orbit/2.1.0-1/samples/pages/test.op
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
	return admin_layout(web,args,div.group(form{enctype="multipart/form-data",action=web.path_info, method="POST", res}))
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
--- Renders the administration's lendings list inner_html
function render_lendings(web,args) --{{{
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local part1 = {
		h2(strings.lendings)
		}
	local tab_body={
		tr{
			th(strings.date_return),
			th(strings.copy_code),
			th(strings.book),
			th(strings.login),
			th(strings.user_id),
			th(strings.actions),
		}
	}
	for k = 1,#args.lendings do
		local item=args.lendings[k]
		local class
		if k%2==1 then class="alt" end --TODO CSS color according urgency.
		tab_body[#tab_body+1]= tr{ class=class,
			td(item.date_return),
			td(item.copy_code),
			td(a{ href = web:link("/book/"..item.book_id,{copy=item.copy_id}),item.title}),
			td(a{ href = "/edit/user/"..item.user_id,item.real_name}),
			td(tostring(item.user_id)),
			td(a{ href = web:link("/admin",{return_copy=item.copy_id}),strings.return_copy})
		}
	end
	
	local url = web.path_info:gsub("/+$","") -- Strip extra // and make sure there is 1
	local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
	local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
	return admin_layout(web,args,{part1,'<table id="lendings">',tab_body,'</table>',prevPage," ",nextPage},_sort_sidebar(web,args.fields,order,orderby,limit,offset))
end --}}}
--- Renders the administration's reservation list inner_html
function render_reservations(web,args) --{{{
	local offset,limit,order,orderby=args.offset, args.limit, args.order, args.orderby
	local part1 = {
		h2(strings.reservations)
		}
	local tab_body={
		tr{
			th(strings.date),
			th(strings.book),
			th(strings.login),
			th(strings.user_id),
			th(strings.available),
			th(strings.actions),
		}
	}
	for k = 1,#args.reservations do
		local item=args.reservations[k]
		local class
		if k%2==1 then class="alt" end --TODO CSS color if book should be already returned by previous lender.
		tab_body[#tab_bodyA+1]= tr{ class=class,
			td(item.date),
			td(a{ href = web:link("/book/"..item.book_id,{copy=item.copy_id}),item.title}),
			td(a{ href = "/edit/user/"..item.user_id,item.real_name}),
			td(tostring(item.user_id)),
			td(item.available and strings.available or strings.unavailable), -- TODO put into reservations_get
			td(a{ href = web:link("/admin",{cancel_reservation=item.reservation_id}),strings.cancel_reservation})
		}
	end
	
	local url = web.path_info:gsub("/+$","") -- Strip extra // and make sure there is 1
	local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
	local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
	return admin_layout(web,args,{part1,'<table id="reservations">',tab_body,'</table>',prevPage," ",nextPage},_sort_sidebar(web,args.fields,order,orderby,limit,offset))
end --}}}

orbit.htmlify(bib, "_.+", "admin_layout","login_layout", "render_.+","edit_get","new_get")
-- vim:fdm=marker
