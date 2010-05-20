--
--------------------------------------------------------------------------------
--         FILE:  bib_config.lua
--        USAGE:  ./bib_config.lua 
--  DESCRIPTION:  Configurationfile for Bib / Archivo de configuración para Bib
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  Jan-Pieter Jacobs (jpjacobs), <janpieter.jacobs@gmail.com>
--      COMPANY:  Plataforma Unidos
--      VERSION:  1.0
--      CREATED:  05/15/2010 07:39:40 PM BOT
--     REVISION:  ---
--------------------------------------------------------------------------------
--

module ("bib", package.seeall)
require"bib.trans"

-- Enable debugging functions
-- Activar funcciones de reparación de errores
debug = true

-- Language selection, possibilities: en, es, nl
language_def="en"
strings=bib.trans.strings[language_def]

-- Database connection data
-- Datos de conexión a la base de datos
database = {
  driver = "sqlite3",
    conn_data = { bib.real_path .. "/bib.db" }
	--  driver = "mysql",
	--  conn_data = { "blog", "root", "password" }
	}

-- Name of the template to be used by the application
-- Nombre del patrón para ser utilizado por la aplicación
template_name = "bib"

-- Configuration of the cache
-- Configuración del antememoria
cache_path=bib.real_path .. "/page_cache"
-- Remove existing file cache
os.remove(cache_path)

-- Uncomment the following line to set a url prefix
-- prefix  "/foobar"

-- Use the next 2 lines if you want the templates' static files
-- and post images to be served by the web server instead of Bib
-- template_vpath should point to the folder where the template you use is,
-- image_vpath to the folder where Bib stores post's images

-- Utilize los 2 proximos lineas si quiere que el servidor de web sirve los archivos
-- staticos y los imagenes post del patrón en vez de Bib.
-- template_vpath debería puntar a la carpeta donde esta el patrón utilizado,
-- imagae_vpath a la carpeta donde Bib pone sus imagenes post.

-- template_vpath = "/templates"
-- image_vpath = "/images"

-- Utility functions

time = {}
date = {}
month = {}

local datetime_mt = { __call = function (tab, date) return tab[language_def](date) end }

setmetatable(time, datetime_mt)
setmetatable(date, datetime_mt)
setmetatable(month, datetime_mt)

function time.es(date)
  local time = os.date("%H:%M", date)
  date = os.date("*t", date)
  return date.day .. " de "
    .. months.es[date.month] .. " de " .. date.year .. " às " .. time
end

function date.es(date)
  date = os.date("*t", date)
  return weekdays.es[date.wday] .. ", " .. date.day .. " de "
    .. months.es[date.month] .. " de " .. date.year
end

function month.es(month)
  return months.es[month.month] .. " de " .. month.year
end

local function ordinalize(number)
  if number == 1 then
    return "1st"
  elseif number == 2 then
    return "2nd"
  elseif number == 3 then
    return "3rd"
  else
    return tostring(number) .. "th"
  end
end

function time.en(date)
  local time = os.date("%H:%M", date)
  date = os.date("*t", date)
  return months.en[date.month] .. " " .. ordinalize(date.day) .. " " ..
     date.year .. " at " .. time
end

function date.en(date_in)
	local s=strings
	local date={}
	date.year,date.month,date.day=date_in:match("(%d%d%d%d)-(%d%d)-(%d%d)")
	date.wday=os.date("*t",os.time(date)).wday
	print("--debug time =",date.year,date.month,date.day,date.wday)
	for k,v in pairs(date) do
		date[k]=tonumber(v)
	end
  return s.weekdays[date.wday] .. ", " .. s.months[date.month] .. " " ..
     ordinalize(date.day) .. " " .. date.year 
end

function month.en(month)
  return months.en[month.month] .. " " .. month.year
end
