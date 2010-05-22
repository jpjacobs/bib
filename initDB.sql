-- Static Pages (help, contact, ...) / Páginas staticas (ayuda, contacto, ...)
CREATE TABLE bib_page (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"body" TEXT,
	"title" TEXT
	);
-- Book management / Gestion de libros
CREATE TABLE bib_book (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"title" TEXT,
	"author_id" INTEGER, -- Ref to Author.AuthorID 
	"isbn" TEXT,
	"abstract" TEXT,
	"rating" TEXT,
	"url_ref" TEXT,
	"url_cover" TEXT
);

CREATE TABLE bib_copy (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"book_id" INTEGER, -- Ref to Book.BookID
	"date_acquisition" TEXT,
	"edition" TEXT,
	"date_published" TEXT,
	"price" TEXT
	);

CREATE TABLE bib_author (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"last_name" TEXT,
	"rest_name" TEXT,
	"url_ref" TEXT
	);
-- User management / Gestion de usuarios
CREATE TABLE bib_user (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"center_id" INTEGER, -- reference to centers table, out of the bib-system, 0 when unknown
	"telephone" INTEGER,
	"email" TEXT,
	"debt" INTEGER
	);

CREATE TABLE bib_center (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"name" TEXT,
	"center_id" INTEGER, -- For indicating if center depends on other center.
	"address" TEXT,
	"contact" TEXT,
	"logo" TEXT
	);

CREATE TABLE bib_loan (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"user_ID" INTEGER, -- Ref to User.UserID
	"copy_ID" INTEGER, -- Ref to Copy.CopyID
	"date_return" TEXT
	);

CREATE TABLE bib_reservation (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"user_id" INTEGER, -- Ref to User.UserID
	"book_id" INTEGER, -- Ref to Book.BookID
	"date" TEXT
	);
-- Tags & Co. / Etiquetas y compania
-- Tags work like this : N tags can match M books, hence, we need 2 tables: one defining the tags, one linking books and tags
-- Etiquetas funccionan así: N etiquetas pueden coresponder a M libros, de ahí hay que tener 2 tablas: uno describiendo las etiquetas y uno conectando las etiquetas y los libros.

CREATE TABLE bib_tag (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"tag_text" TEXT
	);

CREATE TABLE bib_taglink (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"tag_id" INTEGER, -- Ref to Tag.TagID
	"book_id" INTEGER -- Ref to Book.BookID
	);

-- Some junk data for testing
-- Un poco de datos para testear

-- A testpage
-- Una página de prueba
INSERT INTO bib_page VALUES(1,"*It Works!*","It Works!");

-- Some authors
-- Unos autores
INSERT INTO bib_author VALUES (1,"Doyle","Sir Arthur Conan","http://en.wikipedia.org/wiki/Arthur_Conan_Doyle");
INSERT INTO bib_author VALUES (2,"Márquez","Gabriel García","http://en.wikipedia.org/wiki/Gabriel_garcia_marquez");
-- Some books and  their copies
-- Unos libros y sus ejemplares
INSERT INTO bib_book VALUES (1,"Sherlock Holmes: A study in scarlet",1,"","Classic detective story",5,"http://en.wikipedia.org/wiki/A_Study_in_Scarlet","/covers/cover1-Sherlock_Holmes_A_study_in_scarlet.jpg");
INSERT INTO bib_copy VALUES (1,1,"2010-05-15","first edition","1887-01-01",100);
INSERT INTO bib_book VALUES (2,"Love in the Time of Cholera",2,"9580600007","Classic book about love",5,"http://en.wikipedia.org/wiki/Love_in_the_Time_of_Cholera","");
INSERT INTO bib_copy VALUES (2,2,"2010-05-15","second edition","1985-01-01",200);
INSERT INTO bib_book VALUES (3,"Chronicle of a Death Foretold",2,"9780140157543","The story recreates a murder that took place in Sucre, Colombia in 1951. The character named Santiago Nasar is based on a good friend from García Márquez's childhood, Cayetano Gentile Chimento. Pelayo classifies this novel as a combination of journalism, realism and detective story",5,"http://en.wikipedia.org/wiki/Gabriel_garcia_marquez","/covers/cover3-Chronicle_of_a_Death_Foretold.jpg");
INSERT INTO bib_copy VALUES (3,3,"2010-05-17","second edition","1983-01-01",150);
INSERT INTO bib_copy VALUES (4,3,"2010-05-20","third edition","1985-01-01",170);

-- Information about the centers
-- Informaciones sobre los centros
INSERT INTO `bib_center` VALUES(1, 'Plataforma UNIDOS',0 , '', '', 'plataforma.jpg');
INSERT INTO `bib_center` VALUES(2, 'CERENID',0,  'Calle Ballivián, 1196 Segundo Anillo<br>Directora: María José del Pino Martín<br>Teléfono: 335 16 44<br><a href="mailto:choquita34@hotmail.com">choquita34@hotmail.com</a><br><a href="mailto:choquita34@yahoo.com">choquita34@yahoo.com</a>', '', 'cerenid.jpg');
INSERT INTO `bib_center` VALUES(3, 'Alalay','0' ,'Calle Teniente Rivero #158', 'Director: Omar Herrera<br>Teléfono: 70590727', 'alalay.jpg');
INSERT INTO `bib_center` VALUES(20, 'Casa de niños','3' , 'Calle Teniente Rivero #158', 'Coordinadora: Vivian Montaño<br>Teléfono: 332 72 91', 'alalay.jpg');
INSERT INTO `bib_center` VALUES(21, 'Casa de niñas','3' , 'Calle 2 #39<br>Barrio Universitario entrando por el radial 19, segundo puente.', '<br>Coordinadora: Patricia Justiniano<br>Teléfono: 356 56 13', 'alalay.jpg');
INSERT INTO `bib_center` VALUES(22, 'Aldea El Torno','3' , 'Antigua carretera a Cochabamba Km. 30 Santa Rita, el Torno', 'Coordinador: Paul Salonero<br>Teléfono: 382 23 36', 'alalay.jpg' );
INSERT INTO `bib_center` VALUES(4, 'Asociación Mi Rancho', 'Asociación Mi Rancho', '', '', 'mi_rancho.jpg');
INSERT INTO `bib_center` VALUES(18, 'Mi Rancho','4', 'Carretera Cotoca Km 18,<br>detras del surtidor de la Virgen Cotoca<br>Director: Gregorio Monroy<br>Teléfono: 388 20 92', 'Gregorio Monrroy Toledano', 'mi_rancho.jpg');
INSERT INTO `bib_center` VALUES(19, 'Pahuichi','4', 'Barrio Guapilo Norte,<br>Línea 32 verde<br>Al lado CEMETRA<br>Teléfono: 349 80 11', 'Rosa Ruiz', 'mi_rancho.jpg');
INSERT INTO `bib_center` VALUES(5, 'CALLECRUZ','0', 'Hogar La República, pasado Cotoca (16 km Las Pavas)<br>Oficina Central: Av. Piraí, Calle Mutun, # 63.', 'Directora: Cleotilde Morales Sandoval<br>Teléfono: 359 96 64<br><a href="mailto:callecruz@cotas.com.bo">callecruz@cotas.com.bo</a>', 'calle_cruz_v.jpg');
INSERT INTO `bib_center` VALUES(6, 'Misión Timoteo Betel','0', 'Calle Tristan Roca esquina Angostura, # 191<br>Teléfono: 354 06 39<br><a href="mailto:alfredo_cvn@hotmail.com">alfredo_cvn@hotmail.com</a>', 'Alfredo Negrete', 'mision_timoteo.jpg');
INSERT INTO `bib_center` VALUES(7, 'Proyecto Oikia','0', 'Av. Panamericana entre Av. La Campana y Radial 10<br>Plan 3000<br>Teléfono: 364 74 42<br>362 41 07<br><a href="mailto:delatraba@gmail.com">delatraba@gmail.com</a>', 'Padre Pepe Cervantes<br>Daniel de la Traba', 'oikia.jpg');
INSERT INTO `bib_center` VALUES(8,  'Proyecto Don Bosco','0', '', 'Padre Octavio Sabaddim', 'proyecto_don_bosco.jpg');
INSERT INTO `bib_center` VALUES(11, 'Techo Pinardi','8', 'Calle Junín # 438<br>entre la calle Santa Bárbara y la calle Sara<br>Teléfono: 3371016<br>Santa Cruz', '', 'techo_pinardi.jpg');
INSERT INTO `bib_center` VALUES(12, 'Patio Don Bosco','8', 'Barrio 12 de Octubre<br>frente al Centro de Salud "San Carlos"<br>Teléfono: 3412693<br>Santa Cruz', '', 'db-patio-don-bosco.jpg');
INSERT INTO `bib_center` VALUES(13, 'Hogar Granja Moglia','8', 'Carretera de Santa Cruz<br>a Montero, Km 49 al lado del Servicio Nacional de Camino<br>Teléfono 9224465', '', 'db-hogar-granja-moglia.jpg');
INSERT INTO `bib_center` VALUES(14, 'Mano amiga','8', 'Av. Hernando Sanabria 2755<br>(ex centenario entre 2º y 3er anillo)<br>Teléfono: 3532716<br>Santa Cruz', '', 'db-mano-amiga.jpg');
INSERT INTO `bib_center` VALUES(15, 'Hogar Don Bosco','8', 'Av. Hernando Sanabria 2775 (Ex Centenario)<br>entre 2º y 3er anillo.<br>Teléfono: 3541100<br>Santa Cruz', '', 'db-hogar-don-bosco.jpg');
INSERT INTO `bib_center` VALUES(16, 'Barrio Juvenil','8', 'Zona La Cuchilla<br>entre Barrio España y Universidad Evangélica<br>Teléfono: 358 59 93', '', 'db-barrio-juvenil.jpg');
INSERT INTO `bib_center` VALUES(17, 'Patio Don Bosco Defensoría','8', 'Barrio 12 de Octubre<br>frente al Centro de Salud "San Carlos"<br>Teléfono: 3412693<br>Santa Cruz', '', 'db-patio-don-bosco.jpg');

INSERT INTO bib_tag VALUES (1,"roman");
INSERT INTO bib_tag VALUES (2,"detective");
INSERT INTO bib_tag VALUES (3,"colombia");

INSERT INTO bib_taglink VALUES (1,1,2); -- tag roman -> love in times of cholera
INSERT INTO bib_taglink VALUES (2,1,3); -- tag roman -> Chronicle ...
INSERT INTO bib_taglink VALUES (3,3,3); -- tag colombia -> Chronicle ...
INSERT INTO bib_taglink VALUES (4,2,1); -- tag detective -> A study in scarlet
