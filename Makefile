#!/usr/bin/make -f
# Author Denis Matveev(denis.matveev@ignitia.se)
ifeq ($(shell cat /etc/issue | grep 'Ubuntu\|Debian' | wc -l), 1)
ifndef GPHOME
$(error GPHOME variable is not defined. Run 'source ~/.bashrc' first)
endif
include ../Makefile.version
POSTGIS_DIR=$(shell cd ../build/postgis-$(POSTGIS_VER) && pwd)
# for so files should be used $(GPHOME)/glib
ARCH=$(shell arch)
POSTGIS_DEB=postgis-$(POSTGIS_VER)-$(POSTGIS_REL).$(ARCH).deb
# Targets
prepare:
	mkdir -p buildroot/$(GPHOME)/bin
	cp /root/geospatial/postgis/build/postgis-2.5.4/loader/.libs/* buildroot/$(GPHOME)/bin
	cp /root/geospatial/postgis/build/postgis-2.5.4/raster/loader/.libs/raster2pgsql buildroot/$(GPHOME)/bin
	
	mkdir -p buildroot/$(GPHOME)/lib/postgresql
	cp /root/geospatial/postgis/build/postgis-2.5.4/postgis/postgis-2.5.so buildroot/$(GPHOME)/lib/postgresql/
	
	mkdir -p buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/install
	mkdir -p buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade
	mkdir -p buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/uninstall
	mkdir -p buildroot/$(GPHOME)/share/postgresql/extension/
	cp $(POSTGIS_DIR)/postgis/postgis.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/install/
	cp $(POSTGIS_DIR)/raster/rt_pg/rtpostgis.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/install/
	cp $(POSTGIS_DIR)/spatial_ref_sys.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/install/
	cp $(POSTGIS_DIR)/postgis/postgis_upgrade_for_extension.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/postgis/postgis_upgrade.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/postgis/legacy_gist.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/postgis/legacy.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/postgis/legacy_minimal.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/postgis/uninstall_postgis.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/postgis/uninstall_legacy.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp $(POSTGIS_DIR)/../../package/postgis_manager.sh buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/postgis_manager.sh
	cp $(POSTGIS_DIR)/../../package/postgis_replace_views.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/postgis_replace_views.sql
	cp $(POSTGIS_DIR)/../../package/postgis--unpackaged--2.1.5.sql buildroot/$(GPHOME)/share/postgresql/contrib/postgis-2.5/upgrade/
	cp -r DEBIAN buildroot/
$(POSTGIS_DEB):
	dpkg-deb --build buildroot $(POSTGIS_DEB)

deb: prepare $(POSTGIS_DEB)

clean:
	rm -rf buildroot/* && rm -f $(POSTGIS_DEB) 

all: deb 

.PHONY: clean prepare

endif
