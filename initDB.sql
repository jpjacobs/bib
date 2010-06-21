-- Static Pages (help, contact, ...) / Páginas staticas (ayuda, contacto, ...)
CREATE TABLE bib_page (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"title" TEXT,
	"body" TEXT,
	"body_html" TEXT DEFAULT ""
	);
-- Book management / Gestion de libros
CREATE TABLE bib_book (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"title" TEXT,
	"author_id" INTEGER, -- Ref to Author.AuthorID 
	"cat_id" INTEGER,
	"isbn" TEXT,
	"abstract" TEXT,
	"abstract_html" TEXT DEFAULT "",
	"rating" TEXT,
	"url_ref" TEXT,
	"url_cover" TEXT
);

CREATE TABLE bib_copy (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"book_id" INTEGER, -- Ref to Book.BookID
	"copy_nr" INTEGER, -- Number of copy per book
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
	"login" TEXT,
	"password" TEXT,
	"real_name" TEXT, -- Real name, only for displaying DON'T CALL IT NAME, ORBIT WILL BORK!
	"auth" TEXT DEFAULT NULL,
	"is_admin" INTEGER,
	"center_id" INTEGER, -- reference to centers table, out of the bib-system, 0 when unknown
	"telephone" INTEGER,
	"email" TEXT,
	"debt" INTEGER
	);

CREATE TABLE bib_center (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"real_name" TEXT,
	"center_id" INTEGER, -- For indicating if center depends on other center.
	"address" TEXT,
	"telephone" TEXT,
	"email" TEXT,
	"contact" TEXT,
	"logo" TEXT
	);

CREATE TABLE bib_lending (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"user_id" INTEGER, -- Ref to User.UserID
	"copy_id" INTEGER, -- Ref to Copy.CopyID
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
CREATE TABLE bib_cat ( -- Categories / Catégorias o rubros
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"cat_text" TEXT
	);

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
INSERT INTO bib_page VALUES(1,"It Works!","*It Works!*","");

-- Some authors
-- Unos autores
INSERT INTO bib_author VALUES (1,"Doyle","Sir Arthur Conan","http://en.wikipedia.org/wiki/Arthur_Conan_Doyle");
INSERT INTO bib_author VALUES (2,"Márquez","Gabriel García","http://en.wikipedia.org/wiki/Gabriel_garcia_marquez");
-- Some books and  their copies
-- Unos libros y sus ejemplares
INSERT INTO bib_cat VALUES (1,"Roman");
INSERT INTO bib_cat VALUES (2,"Education");
INSERT INTO bib_cat VALUES (3,"Psycology");
INSERT INTO bib_book VALUES (1,"Sherlock Holmes: A study in scarlet",1,1,"","Classic detective story","",5,"http://en.wikipedia.org/wiki/A_Study_in_Scarlet","/covers/cover1-Sherlock_Holmes_A_study_in_scarlet.jpg");
INSERT INTO bib_copy VALUES (1,1,1,"2010-05-15","first edition","1887-01-01",100);
INSERT INTO bib_book VALUES (2,"Love in the Time of Cholera",2,1,"9580600007","Classic book about love","",5,"http://en.wikipedia.org/wiki/Love_in_the_Time_of_Cholera","");
INSERT INTO bib_copy VALUES (2,2,1,"2010-05-15","second edition","1985-01-01",200);
INSERT INTO bib_book VALUES (3,"Chronicle of a Death Foretold",2,1,"9780140157543","The story recreates a murder that took place in Sucre, Colombia in 1951. The character named Santiago Nasar is based on a good friend from García Márquez's childhood, Cayetano Gentile Chimento. Pelayo classifies this novel as a combination of journalism, realism and detective story","",5,"http://en.wikipedia.org/wiki/Gabriel_garcia_marquez","/covers/cover3-Chronicle_of_a_Death_Foretold.jpg");
INSERT INTO bib_copy VALUES (3,3,1,"2010-05-17","second edition","1983-01-01",150);
INSERT INTO bib_copy VALUES (4,3,2,"2010-05-20","third edition","1985-01-01",170);

-- Information about the centers
-- Informaciones sobre los centros
INSERT INTO `bib_center` (id,real_name,center_id) VALUES(0,"None",0); 
INSERT INTO `bib_center` VALUES(1, 'Plataforma UNIDOS',0 , 'Calle Mendiola 320', '', '','', 'plataforma.jpg');
INSERT INTO `bib_center` VALUES(2, 'CERENID',0,  'Calle Ballivián, 1196 Segundo Anillo','335 16 44','choquita34@hotmail.com', 'María José del Pino Martín', 'cerenid.jpg');
INSERT INTO `bib_center` VALUES(3, 'Alalay','0' ,'Calle Teniente Rivero #158','70590727','','Omar Herrera', 'alalay.jpg');
INSERT INTO `bib_center` VALUES(20, 'Casa de niños','3' , 'Calle Teniente Rivero #158','332 72 91','' ,'Vivian Montaño','alalay.jpg');
INSERT INTO `bib_center` VALUES(21, 'Casa de niñas','3' , 'Calle 2 #39 Barrio Universitario entrando por el radial 19, segundo puente','356 56 13','', 'Patricia Justiniano', 'alalay.jpg');
INSERT INTO `bib_center` VALUES(22, 'Aldea El Torno','3' , 'Antigua carretera a Cochabamba Km. 30 Santa Rita, el Torno','382 23 36','', 'Paul Salonero', 'alalay.jpg' );
INSERT INTO `bib_center` VALUES(4, 'Asociación Mi Rancho', '0', '', '','','', 'mi_rancho.jpg');
INSERT INTO `bib_center` VALUES(18, 'Mi Rancho','4', 'Carretera Cotoca Km 18, detras del surtidor de la Virgen Cotoca','388 20 92','' ,'Gregorio Monroy Toledano', 'mi_rancho.jpg');
INSERT INTO `bib_center` VALUES(19, 'Pahuichi','4', 'Barrio Guapilo Norte, Línea 32 verde Al lado CEMETRA','349 80 11','', 'Rosa Ruiz', 'mi_rancho.jpg');
INSERT INTO `bib_center` VALUES(5, 'CALLECRUZ','0', 'Hogar la Republíca: pasado Cotoca (16 km Las Pavas) Oficina Central: Av. Piraí, Calle Mutun, # 63.', '359 96 64','callecruz@cotas.com.bo','Cleotilde Morales Sandoval', 'calle_cruz_v.jpg');
INSERT INTO `bib_center` VALUES(6, 'Misión Timoteo Betel','0', 'Calle Tristan Roca esquina Angostura, # 191','354 06 39','alfredo_cvn@hotmail.com', 'Alfredo Negrete', 'mision_timoteo.jpg');
INSERT INTO `bib_center` VALUES(7, 'Proyecto Oikia','0', 'Av. Panamericana entre Av. La Campana y Radial 10 Plan 3000','364 74 42 362 41 07','delatraba@gmail.com', 'Padre Pepe Cervantes Daniel de la Traba', 'oikia.jpg');
INSERT INTO `bib_center` VALUES(8,  'Proyecto Don Bosco','0', '', '','','Padre Octavio Sabaddim', 'proyecto_don_bosco.jpg');
INSERT INTO `bib_center` VALUES(11, 'Techo Pinardi','8', 'Calle Junín # 438 entre la calle Santa Bárbara y la calle Sara','3371016', '','', 'techo_pinardi.jpg');
INSERT INTO `bib_center` VALUES(12, 'Patio Don Bosco','8', 'Barrio 12 de Octubre frente al Centro de Salud "San Carlos"','3412693', '','', 'db-patio-don-bosco.jpg');
INSERT INTO `bib_center` VALUES(13, 'Hogar Granja Moglia','8', 'Carretera de Santa Cruz a Montero, Km 49 al lado del Servicio Nacional de Camino','9224465', '','', 'db-hogar-granja-moglia.jpg');
INSERT INTO `bib_center` VALUES(14, 'Mano amiga','8', 'Av. Hernando Sanabria 2755 (ex centenario entre 2º y 3er anillo)','3532716','', '', 'db-mano-amiga.jpg');
INSERT INTO `bib_center` VALUES(15, 'Hogar Don Bosco','8', 'Av. Hernando Sanabria 2775 (Ex Centenario) entre 2º y 3er anillo.','3541100','', '', 'db-hogar-don-bosco.jpg');
INSERT INTO `bib_center` VALUES(16, 'Barrio Juvenil','8', 'Zona La Cuchilla entre Barrio España y Universidad Evangélica','358 59 93','', '', 'db-barrio-juvenil.jpg');
INSERT INTO `bib_center` VALUES(17, 'Patio Don Bosco Defensoría','8', 'Barrio 12 de Octubre frente al Centro de Salud "San Carlos"','3412693','', '', 'db-patio-don-bosco.jpg');

INSERT INTO bib_user VALUES(1,"admin","admin",'Administrator',NULL,1,1,"12341234","admin@blah.com",0);
INSERT INTO bib_user VALUES(2,"user","user",'User Luser',NULL,0,1,"43214321","user@blah.com",0);

INSERT INTO bib_tag VALUES (1,"roman");
INSERT INTO bib_tag VALUES (2,"detective");
INSERT INTO bib_tag VALUES (3,"colombia");

INSERT INTO bib_taglink VALUES (1,1,2); -- tag roman -> love in times of cholera
INSERT INTO bib_taglink VALUES (2,1,3); -- tag roman -> Chronicle ...
INSERT INTO bib_taglink VALUES (3,3,3); -- tag colombia -> Chronicle ...
INSERT INTO bib_taglink VALUES (4,2,1); -- tag detective -> A study in scarlet
