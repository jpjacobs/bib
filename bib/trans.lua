--
--------------------------------------------------------------------------------
--         FILE:  bib_trans.lua
--        USAGE:  ./bib_trans.lua 
--  DESCRIPTION:  Translation file for Bib
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  Jan-Pieter Jacobs (jpjacobs), <janpieter.jacobs@gmail.com>
--      COMPANY:  Plataforma Unidos
--      VERSION:  1.0
--      CREATED:  05/17/2010 11:40:20 AM BOT
--     REVISION:  ---
--------------------------------------------------------------------------------
--

module("bib.trans")
strings = {}

-- Strings in English
-- Cadenas en ingles
strings.en = {
	abstract = "Abstract",
	add = "Add",
	added_to_library_on = "Added to library on",
	admin = "Administrator",
	admin_console = "Admin console",
	admin_home = "Admin Home",
	admin_menu = "Administration Menu",
	administration = "Administration",
	anonymous_author = "Anonymous Author",
	at = "at",
	author = "Author",
	available_date = "Available from ",
	blank_name = "Name cannot be blank",
	blank_password = "Password cannot be blank",
	blank_title = "Title cannot be blank",
	blank_user = "Login cannot be blank",
	blogroll_title = "Links",
	body = "Body",
	bold = "bold",
	book = "Book",
	browse_by = "Browse by ",
	by_author = " by ",
	cancel_reservation = "Cancel reservation",
	category = "Category",
	center = "Centre",
	comments = "Comments",
	copies_available = "Copies available: ",
	copies = "Copies",
	cover_of = "Cover image of ",
	copyright_notice = "Licensed under the [MIT license](http://en.wikipedia.org/wiki/MIT_License) ",
	date_acquisition = "Acquisition date",
	debt = "Debt",
	delete = "Delete",
	delete_book = "Delete book",
	delete_copy = "Delete copy",
	delete_reservation_ok = "Reservation deleted",
	description = "Description",
	double_reservation = "Error when making the reservation, you already have a reservation for this book!",
	edition = "Edition",
	edit_book = "Edit Book",
	edit_copy = "Edit copy",
	edit = "Edit",
	email = "Email",
	external_url = "External URL",
	form_email = "Email:",
	form_name = "Name:",
	form_url = "Site:",
	homepage_name = "Homepage",
	italics = "italics",
	isbn = "ISBN",
	last_books = "Last Books",
	last_name = "Last name",
	link = "link",
	lend_copy = "Lend copy",
	logged_in_as = "Logged in as ",
	login_button = "Login",
	login_page = "Login page",
	login = "Username",
	markdown_expl = "Formatting rules",
	markdown_url = "http://daringfireball.net/projects/markdown/syntax",
	name = "Name",
	new_book = "Add Book",
	new_comment = "New comment",
	new_user = "Add User",
	no_books = "There are no books in the database.",
	no_reservation = "An error when canceling the reservation, you don't have a reservation for this book!",
	not_allowed_to_administration = "User is not allowed to do administration",
	on_date = "on",
	on = "on",
	order_asc = "Ascending",
	order_by = "Order by ",
	order_desc = "Descending",
	page = "Page",
	password_mismatch = "Passwords do not match",
	password_not_match = "Password does not match!",
	password = "Password",
	price = "Price",
	published_at = "Published at",
	published = "Published",
	reservation_ok = "Reservation succeeded!",
	reserve = "Reserve",
	reserved = "Reserved",
	rest_name = "Rest of name",
	return_copy = "Return copy",
	search = "Search",
	search_book = "Search Book", 
	search_by = "Search by",
	send = "Send",
	tag = "Tag",
	telephone = "Telephone number",
	title = "Title",
	this_book = "This Book",
	url_cover = "Cover image URL",
	url_ref = "Reference URL",
	user_id = "User ID",
	user_menu = "User Menu",
	user_not_found = "User not found!",
	users = "Users",
	written_by = "Written by",
	months= { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" },
	weekdays = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday","Sunday" },
}

strings.es={
	abstract = "Resumen",
	add = "Añadir",
	added_to_library_on = "Añadido en la biblioteca",
	admin = "Administrador",
	admin_console = "Consola Administrador",
	admin_home = "Pagina inicial de administración",
	admin_menu = "Menú de administracion",
	administration = "Administración",
	anonymous_author = "Anónimo",
	archive_title = "Archivo",
	at = "a",
	author = "Autor",
	available_from = "Disponible desde ",
	blank_name = "Nombre no puede ser vacia",
	blank_password = "Contraseña no puede ser vacia",
	blank_title = "Título  no puede ser vacia",
	blank_user = "Usuario no puede ser vacia",
	blogroll_title = "Enlaces",
	body = "Contenido",
	bold = "negrito",
	book = "Libro",
	browse_by = "Navegar por ",
	by_author = " de ",
	cancel_reservation = "Cancelar reservación",
	category = "Rubro",
	center = "Centro",
	comments = "Comentários",
	copies_available = "Ejemplares disponibles: ",
	cover_of = "Imagen de la tapa de ",
	copies = "Ejemplares",
	copyright_notice = "Lleva la [licensia MIT](http://es.wikipedia.org/wiki/MIT_License)",
	date_acquisition = "Fecha de adquisición",
	debt = "Deuda",
	delete = "Suprimir",
	delete_book = "Suprimir libro",
	delete_copy = "Suprimir ejemplar",
	delete_reservation_ok = "Reservación suprimado",
	description = "Descripción",
	double_reservation = "Un error ocurió haciendo su reservación: ya tiene un reservación en este libro.",
	edition = "Edición",
	edit_book = "Editar libro",
	edit_copy = "Editar ejemplar",
	edit = "Editar",
	email = "Correo electrónico",
	external_url = "URL externa",
	form_email = "Correo electrónico:",
	form_name = "Nombre:",
	form_url = "Sitio:",
	homepage_name = "Página Inicial",
	italics = "itálico",
	isbn = "ISBN",
	last_books = "Últimos Libros",
	last_name = "Apellido",
	link = "enlace",
	lend_copy = "Prestar ejemplar",
	logged_in_as = "Conectado como",
	login_button = "Conectase",
	login_page = "Página de conexión",
	login = "Usuario",
	markdown_expl = "Reglas de formatación",
	markdown_url = "http://es.wikipedia.org/wiki/Markdown",
	name = "Nombre",
	new_book = "Añadir libro",
	new_comment = "Nuevo comentário",
	new_user = "Añadir usurio",
	no_books = "No hay libros en la base de datos",
	no_reservation = "Un error se produció anulando su reservación: no tiene una reservación en este libro",
	not_allowed_to_administration = "Usuario no puede acceder a la administración",
	on_date = "en",
	on = "en",
	order_asc = "Subiendo",
	order_desc = "Bajando", 
	order_by = "Ordenar por ",
	page = "Página",
	password = "Contraseña",
	password_mismatch = "Contraseñas no corresponden",
	password_not_match = "Contraseña no corresponde",
	price = "Precio",
	published_at = "Publicado en",
	published = "Publicado",
	reservation_ok = "La reservación se ejecutó con éxito!",
	reserve = "Reservar",
	reserved = "Reservado",
	rest_name = "Otros nombres o apellidos",
	return_copy = "Devolver ejemplar",
	search = "Buscar",
	search_by = "Buscar por",
	search_book = "Buscar libro",
	send = "Enviar",
	tag = "Tag",
	telephone = "Número de teléfono",
	title = "Título",
	this_book = "Este Libro",
	url_ref = "URL de referencia",
	url_cover = "URL de la tapa del libro",
	user_id = "ID de usuario",
	user_not_found = "Usuario no encontrado!",
	user_menu = "Menú de usuario",
	users = "Usuarios",
	written_by = "Escrito por",
	months = { "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre" },
	weekdays = { "Lunes","Martes","Miercoles","Jeuves","Viernes","Sábado","Domingo"},
}

strings.nl={
	abstract = "Samenvatting",
	admin = "Administrator",
	administration = "Administratie",
	admin_menu = "Administratie menu",
	author = "Auteur",
	available_date = "Beschikbaar vanaf ",
	book = "Boek",
	browse_by = "Bladeren per ",
	by_author = " door ",
	cancel_reservation = "Reservatie annuleren",
	category = "Categorie",
	center = "Centrum",
	copies = "Exemplaren",
	copies_available = "Exemplaren beschikbaar: ",
	copyright_notice = "Beschikbaar onder de [MIT license][http://nl.wikipedia.org/wiki/MIT-licentie]",
	cover_of = "Afbeelding van de kaft van ",
	date_acquisition = "Datum aankoop",
	debt = "Schuld",
	delete_book = "Boek verwijderen",
	delete_copy = "Exemplaar verwijderen",
	delete_reservation_ok = "Reservatie verwijderd",
	double_reservation = "Een fout deed zich voor bij het maken van uw reservatie: U heeft reeds een reservatie voor dit boek.",
	edition = "Editie",
	edit_book = "Boek bewerken",
	edit_copy = "Exemplaar bewerken",
	email = "Email",
	isbn = "ISBN",
	last_name = "Achternaam",
	lend_copy = "Leen exemplaar uit",
	login = "Gebruikersnaam",
	login_page = "Login pagina",
	logged_in_as = "Ingelogd als ",
	markdown_expl = "Layout regels",
	markdown_url = "http://daringfireball.net/project/markdown/syntax/",
	not_allowed_to_administration = "De gebruiker heeft geen administratierechten",
	no_reservation = "Een fout deed zich voor bij het anuleren van uw reservatie: U heeft geen reservatie voor dit boek.",
	order_by = "Rangschik per ",
	order_asc = "Oplopend",
	order_desc = "Aflopend",
	page = "Pagina",
	price = "Prijs",
	reservation_ok = "Reservatie successvol!",
	reserve = "Reserveren",
	reserved = "Gereserveerd",
	rest_name = "Rest van de naam",
	return_copy = "Exemplaar teruggeven",
	search = "Zoeken",
	search_book = "Boek zoeken",
	search_by = "Zoeken op",
	tag= "Label",
	telephone = "Telefoonnummer",
	title = "Titel",
	this_book = "Dit Boek",
	months = { "Januari","Februari","Maart","April","Mei","Juni","Juli","Augustus", "September", "Oktober", "November", "December"},
	url_ref = "Referentie URL",
	url_cover = "URL van de kaftafbeelding",
	user_id = "Gebruikers ID",
	user_menu = "Gebruikers menu",
	weekdays = { "Maandag","Dinsdag","Woensdag","Donderdag","Vrijdag","Zaterdag","Zondag"}
}
