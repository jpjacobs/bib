Dus:

* upload sources tar-bal naar www/projects/bib/
* pas bib-version-revision.rockspec aan
* luarocks pack bib-version-revision.rockspec
* upload bib-version-revision.src.rock en bib-version-revision.src.rockspec naar www/projects/rocks
* luarocks-admin make_manifest ./
* upload manifest en index.html naar www/projects/rocks
* installeer bib met luarocks --from-server=http://jpjacobs.ulyssis.org/projects/rocks bib

