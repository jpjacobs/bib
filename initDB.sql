-- Book management / Gestion de libros
CREATE TABLE bib_book (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"Title" TEXT,
	"Author" INTEGER, -- Ref to Author.AuthorID 
	"ISBN" TEXT,
	"Abstract" TEXT,
	"Rating" TEXT,
	"URLRef" TEXT
);

CREATE TABLE bib_copy (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"BookID" INTEGER, -- Ref to Book.BookID
	"DateAquisition" TEXT, -- Using Julian days
	"Edition" TEXT,
	"DatePublished" TEXT,
	"Price" TEXT
	);

CREATE TABLE bib_author (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"LastName" TEXT,
	"RestName" TEXT,
	"URLRef" TEXT
	);
-- User management / Gestion de usuarios
CREATE TABLE bib_user (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"Center" INTEGER, -- reference to centers table, out of the bib-system, 0 when unknown
	"Telephone" INTEGER,
	"Email" TEXT,
	"Debt" INTEGER
	);

CREATE TABLE bib_loan (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"UserID" INTEGER, -- Ref to User.UserID
	"CopyID" INTEGER, -- Ref to Copy.CopyID
	"DateReturn" TEXT -- Using Julian days
	);

CREATE TABLE bib_reservation (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"UserID" INTEGER, -- Ref to User.UserID
	"BookID" INTEGER, -- Ref to Book.BookID
	"Date" TEXT -- Using Julian days
	);
-- Tags & Co. / Etiquetas y compania
-- Tags work like this : N tags can match M books, hence, we need 2 tables: one defining the tags, one linking books and tags
-- Etiquetas funccionan así: N etiquetas pueden coresponder a M libros, de ahí hay que tener 2 tablas: uno describiendo las etiquetas y uno conectando las etiquetas y los libros.

CREATE TABLE bib_tag (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"TagText" TEXT
	);

CREATE TABLE bib_taglink (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	"TagID" INTEGER, -- Ref to Tag.TagID
	"BookID" INTEGER -- Ref to Book.BookID
	);

-- Some junk data for testing
-- Un poco de datos para testear

INSERT INTO bib_author VALUES (1,"Doyle","Sir Arthur Conan","http://en.wikipedia.org/wiki/Arthur_Conan_Doyle");
INSERT INTO bib_author VALUES (2,"Márquez","Gabriel García","http://en.wikipedia.org/wiki/Gabriel_garcia_marquez");
INSERT INTO bib_book VALUES (1,"Sherlock Holmes: A study in scarlet",1,"","Classic detective story",5,"http://en.wikipedia.org/wiki/A_Study_in_Scarlet");
INSERT INTO bib_copy VALUES (1,1,"17-05-2010","first edition","01-01-1887",100);
INSERT INTO bib_book VALUES (2,"Love in the Time of Cholera",2,"9580600007","Classic book about love",5,"http://en.wikipedia.org/wiki/Love_in_the_Time_of_Cholera");
INSERT INTO bib_copy VALUES (2,2,"17-05-2010","second edition","01-01-1985",200);
INSERT INTO bib_book VALUES (3,"Chronicle of a Death Foretold",2,"9780140157543","The story recreates a murder that took place in Sucre, Colombia in 1951. The character named Santiago Nasar is based on a good friend from García Márquez's childhood, Cayetano Gentile Chimento. Pelayo classifies this novel as a combination of journalism, realism and detective story",5,"http://en.wikipedia.org/wiki/Gabriel_garcia_marquez");
INSERT INTO bib_copy VALUES (3,3,"17-05-2010","second edition","01-01-1983",150);
