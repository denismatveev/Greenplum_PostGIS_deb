#!/usr/bin/make -f
# Author Denis Matveev(denis.matveev@ignitia.se)
ifeq ($(shell cat /etc/issue | grep 'Ubuntu\|Debian' | wc -l), 1)
ifndef GPHOME
$(error GPHOME variable is not defined. Run 'source ~/.bashrc' first)
endif
include greenplum-db-6-postgis/geospatial/postgis/Makefile.version
POSTGIS_DIR=greenplum-db-6-postgis/geospatial/postgis/build/postgis-$(POSTGIS_VER)
SHELL:=/bin/bash
ARCH=$(shell dpkg-architecture -qDEB_BUILD_ARCH)
OS=debian
POSTGIS_DEB=greenplum-db-$(GPDB_VER)-postgis-$(POSTGIS_VER)-$(POSTGIS_REL).$(ARCH).deb
DEB_DESTDIR = $(shell pwd)/buildroot
ifndef DEB_DESTDIR
$(error DEB_DESTDIR variable is not defined. Please check)
endif
all: gppkg

compile:
	cd $(POSTGIS_DIR) && ./autogen.sh && ./configure --with-pgconfig=$(GPHOME)/bin/pg_config --with-raster --without-topology --prefix=$(GPHOME) && make USE_PGXS=1 -j $(nproc)

deb: compile
	make  DESTDIR=$(DEB_DESTDIR) -C $(POSTGIS_DIR) install
	cp -r DEBIAN $(DEB_DESTDIR)
	dpkg-deb --build $(DEB_DESTDIR) $(POSTGIS_DEB)
gppkg:  compile
	make  DESTDIR=$(DEB_DESTDIR) -C $(POSTGIS_DIR) install
	cp -r DEBIAN $(DEB_DESTDIR)
	mv $(DEB_DESTDIR)$(GPHOME)/* $(DEB_DESTDIR)$(GPHOME)/../../
	dpkg-deb --build $(DEB_DESTDIR) $(POSTGIS_DEB)
	mkdir -p gppkg
	sed "s/#arch/$(ARCH)/g" greenplum-db-6-postgis/geospatial/postgis/package/gppkg_spec.yml.in | sed "s/#os/$(OS)/g" | sed "s/#gpver/$(GPDB_VER)/g" > gppkg/gppkg_spec.yml
	mkdir -p gppkg/deps
	cp $(POSTGIS_DEB) gppkg/
	source $(GPHOME)/greenplum_path.sh && gppkg --build gppkg

clean_gppkg:
	rm -rf gppkg
	rm -f *.gppkg
clean: clean_gppkg
	rm -rf $(DEB_DESTDIR)/* && rm -f $(POSTGIS_DEB)
	make -C $(POSTGIS_DIR) clean

.PHONY: clean clean_gppkg gppkg deb compile all

endif
