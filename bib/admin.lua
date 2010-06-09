
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
function admin(web,params) --{{{
	-- List of admin pages, except the admin mainpage.
	local adminPageList = {
		page="page"}
--		adduser=render_adduser,
--		edituser=render_edituser,
--
--		addbook=render_addbook,
--		editbook=render_editbook,
--		addauthor=render_addauthor,
--		editauthor=render_editauthor,
	local user=check_user(web)
	-- If the user is not set/known, then redirect to the login page
	if not user then
		return web:redirect(web:link("/login", { link_to = web:link("/admin") }))
	else
		-- If the user is an admin, redirect to the admin page
		if user.is_admin == 1 then
			if params==nil then
				return admin_layout(web, render_admin(web, params))
			-- Received a capture, indicating that 
			else
				local page_requested=adminPageList[params:match("(%w+)")]
				local params_pass
				if page_requested then
					params_pass = params:match("%w+/(.+)")
					return admin_layout(web,_M["render_admin_".. page_requested ](web,params_pass))
				else
					return not_found
				end
			end
		-- Logged is as a normal user, redirect to the loginpage, in order to log in as an admin instead
		else
			return web:redirect(web:link("/login", { link_to = web:link("/admin"), not_admin="1"}))
		end
	end
end --}}}

bib:dispatch_get(admin, "/admin","/admin/(%w+.+)")

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
	offset = tonumber(web.input.offset) or 0
	limit = tonumber(web.input.limit) or 10
	local user = check_user(web)
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
			return admin_layout(web,div.group{title,ul(res)})
		elseif not models[obj_type] then -- There is no model named obj_type
			print("-- debug edit_get: no model found for type ",obj_type)
			return not_found(web) --TODO rewrite not_found to include an error message
		elseif not models[obj_type].form then -- The model obj_type exists, but isn't editable (eg, has no form)
			print("--debug edit_get","object type doesn't have a form-table, add form table to the model")
			return not_found(web)
		else -- The obj_type exist and is editable
			if not id then -- no id given, edit is type /edit/<object>, so list all <objects>
				local title = h2(strings.edit," ",strings[obj_type])
				local res = {}
				local url = "/edit/"..obj_type.."/"
				local list = models[obj_type]:find_all_limit(models[obj_type].form.title,"DESC",limit,offset)
				for  item_n = 1,#list do
					local item = list[item_n]
					res[#res+1]= li{ a{href=web:link(url..item.id),item[item.form.title] }}
				end
				local prevPage = a{href=web:link(url,{offset = offset>limit and offset-limit or 0}), strings.prevPage}
				local nextPage = a{href=web:link(url,{offset = offset+limit}), strings.nextPage}
				return admin_layout(web,div.group{title,ul(res),br(),prevPage," ",nextPage})
			else
				object = models[obj_type]:find(id)
				if not object then
					print("--debug edit","object not found")
					return not_found(web)
				else
					local form=object.form
					return render_edit(web,obj_type,object,form.fields,object[form.title])
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
		-- parse web.POST parameters
		if web.POST.op==strings.delete then
			return web:redirect(web:link("/delete/"..obj.name.."/"..obj.id)) -- page asking for confirmation + processing in POST --TODO delete page
		elseif web.POST.op==strings.save then
			if not model[obj].form then print("-- debug edit_post :trying to edit an object from a non-editable model") else
			-- sanitize fields, set them, save object, if body or abstract updated -> obj:update_html(true)
			print("boe")
			end
			-- fields get validated when they match the "valid" pattern in form.field
			--
			-- runs "update" function if field is updated (like body -> body_html conversion)


			-- fields get filtered by the "filter" pattern in form.field
		elseif web.POST.op==strings.cancel then
			-- do nothing, just reload page
		end
	end
	
	return tprint(web):gsub("\n","<br />")
end --}}}

bib:dispatch_get(edit_get,"/edit/(%w+)/(%d+)","/edit/(%w+)/?","/edit/?")
bib:dispatch_post(edit_post,"/edit/(%w+)/(%d+)")

function render_admin_page(web,params)
	return h2(params)
end

function render_edit(web,obj_type,obj,fields,title) --{{{
	local m = models.obj_type
	local tit =	h2{strings.edit," ", obj_type ," ",obj.id,": ",title }
	local res={tit}

	for field_n=1,#fields do
		local field=fields[field_n]
		res[#res+1] = field.caption
		if field["type"]=="select" then --{{{
			res[#res+1]='<select name="'..field.name..'">'
			if field.options then
				-- construct select out of options
				for n_opt=1,#field.options do
					local option_table = {value=field.options[n_opt], field.options[n_opt]}
					if obj[field.name] == field.options[n_opt] then -- If this is the current value, select it, so it is default.
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
				local curs = field.model.model.conn:execute(table.concat(query))
				local opts = {} -- table which will contain the strings for the selectionbox
				local t = {} -- result table
				while curs:fetch(t) do
					opts[#opts+1]={table.remove(t,1),table.concat(t,', ')} -- pop of the index, concat the rest
				end
				for n_opt=1,#opts do
					local option_table={ value=opts[n_opt][1], opts[n_opt][2]}
					if obj[field.name] == opts[n_opt][1] then -- If this is the current value, select it, so it is default.
						option_table.selected="selected"
					end
					res[#res+1]=option(option_table)-- Add an option for "None" in the database, not here.
				end
				res[#res+1]='</select>'
				if field.model then
					res[#res+1]=a{ href=web:link("/edit/"..field.model.name.."/"..obj[field.name]),strings.edit," ",strings[field.model.name]:lower()," ",obj[field.name]}
					res[#res+1]=" "
					res[#res+1]=a{ href=web:link("/new/"..field.model.name), strings.new, strings[field.model.name]:lower() }--TODO Add link to "new ..." 
				end
			end --}}}
		elseif field["type"]=="text" then
			res[#res+1] = input{ name = field.name, ["type"]=field["type"],value=obj[field.name]}
		elseif field["type"]=="textarea" then
			res[#res+1] = textarea{ name = field.name, cols="100", rows="10",style="vertical-align:middle",obj[field.name]}
			res[#res+1] = br()
			res[#res+1] = a{ href=web:link("/markdown",lang), target="_blank", strings.markdown_expl }
		end	
		res[#res+1]=br()
	end
	res[#res+1]=br()
	res[#res+1]=input{ type="submit", id="save",   name="op", value=strings.save }
	res[#res+1]=input{ type="submit", id="cancel", name="op", value=strings.cancel }
	res[#res+1]=input{ type="submit", id="delete", name="op", value=strings.delete }
	return admin_layout(web,div.group(form{action=web.path_info, method="POST", res}))
end --}}}


-- Views
function login_layout(web, params)
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
end

--- View-template for the adminpages, inner_html being render_admin or whatever.
function admin_layout(web, inner_html)
	return html{
		head{
			title{"Bib.lua ",strings.administration},
			meta{ ["http-equiv"] = "Content-Type", content = "text/html; charset=utf-8" },
			link{ rel = 'stylesheet', type = 'text/css', href = web:static_link('/admin_style.css'), media = 'screen' }
		},
		body{
			div{ id = "container",
				div{ id = "header", title = "sitename", "Bib.lua ",strings.administration },
				div{ id = "mainnav",
					ul {
						li{ a{ href = web:link("/admin"), strings.admin_home } },
						li{ a{ href = web:link("/page"), strings.pagina } },
					--[[	li{ a{ href = web:link("/adduser"), strings.new_user } },
						-- TODO add, change links
						li{ a{ href = web:link("/editsection"), strings.new_section } },
						li{ a{ href = web:link("/editpost"), strings.new_post } },
						li{ a{ href = web:link("/comments"), strings.manage_comments } },--]]
					}
				}, 
				div{ id = "menu", _admin_menu(web, args) },  
				div{ id = "contents", inner_html },
				div{ id = "footer", markdown(strings.copyright_notice) }
			}
		}
	} 
end

function _admin_menu(web)
	local res = {}
	local user = check_user(web)
	if user then
		res[#res + 1] = ul{ li{ strings.logged_in_as, user.login } }
		res[#res + 1] = h3(strings.sections)
		local section_list = {}
		for section,name in ipairs({page=strings.page}) do
			section_list[#section_list + 1] = 
			li{ a{ href=web:link("/admin/" .. section), name } }
		end
		res[#res + 1] = ul(table.concat(section_list,"\n"))
	end
	return table.concat(res, "\n")
end

function render_admin(web, params)
   local section_list
   local sections = models.section:find_all({ order = "id asc" })
   if params.section then
      local section = params.section
      local res_section = {}
      res_section[#res_section + 1] = "<div class=\"blogentry\">\n"
      res_section[#res_section + 1] = h2(strings.section .. ": " ..
					 a{ href = web:link("/editsection/" .. section.id),
					    section.title })
      local posts = models.post:find_all_by_section_id{ section.id,
	 order = "published_at desc" }
      res_section[#res_section + 1] = "<p>"
      for _, post in ipairs(posts) do
	 local in_home, published = "", ""
	 if post.in_home then in_home = " [HOME]" end
	 if post.published then published = " [P]" end
	 res_section[#res_section + 1] = a{ href =
	    web:link("/editpost/" .. post.id), post.title } .. in_home .. 
	    published .. br()
      end
      res_section[#res_section + 1] = "</p>"
      res_section[#res_section + 1] = 
	 p{ a.button{ href = web:link("/editpost?section_id=" .. section.id), 
	    button{ strings.new_post } } }
      res_section[#res_section + 1] = "</div>\n"
      section_list = table.concat(res_section, "\n")      
   elseif next(sections) then
      local res_section = {}
      for _, section in ipairs(sections) do
	 res_section[#res_section + 1] = "<div class=\"blogentry\">\n"
	 res_section[#res_section + 1] = h2(strings.section .. ": " ..
					    a{ href = web:link("/editsection/" .. section.id),
					       section.title })
	 local posts = models.post:find_all_by_section_id{ section.id,
	    order = "published_at desc" }
	 res_section[#res_section + 1] = "<p>"
	 for _, post in ipairs(posts) do
	    local in_home, published = "", ""
	    if post.in_home then in_home = " [HOME]" end
	    if post.published then published = " [P]" end
	    res_section[#res_section + 1] = a{ href =
	       web:link("/editpost/" .. post.id), post.title } .. in_home .. 
	       published .. br()
	 end
	 res_section[#res_section + 1] = "</p>"
	 res_section[#res_section + 1] = 
	    p{ a.button { href = web:link("/editpost?section_id=" .. section.id),
	       button{ strings.new_post } } }
	 res_section[#res_section + 1] = "</div>\n"
      end
      section_list = table.concat(res_section, "\n")
   else
      section_list = strings.no_sections
   end
   return div(section_list)
end

function render_login(web, params)
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
end

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
orbit.htmlify(bib, "_.+", "admin_layout","login_layout", "render_.+","edit_get")
-- vim:fdm=marker
