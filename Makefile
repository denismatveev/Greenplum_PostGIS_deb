#!/usr/bin/make -f
# Author Denis Matveev(denis.matveev@ignitia.se)
ifeq ($(shell cat /etc/issue | grep 'Ubuntu\|Debian' | wc -l), 1)
ifndef GPHOME
$(error GPHOME variable is not defined. Run 'source ~/.bashrc' first)
endif
include greenplum-db-6-postgis/geospatial/postgis/Makefile.version
POSTGIS_DIR=greenplum-db-6-postgis/geospatial/postgis/build/postgis-$(POSTGIS_VER)
# for so files should be used $(GPHOME)/glib
ARCH=$(shell arch)
POSTGIS_DEB=greenplum-db-6-postgis-$(POSTGIS_VER)-$(POSTGIS_REL).$(ARCH).deb
# Targets
all: deb 
build:
	cd $(POSTGIS_DIR) && ./autogen.sh && ./configure --with-pgconfig=$(GPHOME)/bin/pg_config --with-raster --without-topology --prefix=$(GPHOME) && make USE_PGXS=1 -j $(nproc)
prepare: build
	make  DESTDIR=$(shell pwd)/buildroot -C $(POSTGIS_DIR) install
	cp -r DEBIAN buildroot/
$(POSTGIS_DEB):
	dpkg-deb --build buildroot $(POSTGIS_DEB)

deb: prepare $(POSTGIS_DEB)
clean:
	rm -rf buildroot/* && rm -f $(POSTGIS_DEB) 
	make -C $(POSTGIS_DIR) clean


.PHONY: clean prepare build all

endif
