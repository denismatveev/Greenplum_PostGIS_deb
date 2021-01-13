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
	mkdir -p buildroot/$(GPHOME)/bin
	cp $(POSTGIS_DIR)/loader/.libs/* buildroot/$(GPHOME)/bin
	cp $(POSTGIS_DIR)/raster/loader/.libs/raster2pgsql buildroot/$(GPHOME)/bin
	
	mkdir -p buildroot/$(GPHOME)/lib/postgresql
	cp $(POSTGIS_DIR)/postgis/postgis-2.5.so buildroot/$(GPHOME)/lib/postgresql/
	
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
	# The string below is right, but greenplum geospatial repository has wrong file with wrong version.
	#cp $(POSTGIS_DIR)/../../package/postgis.control-$(POSTGIS_VER) buildroot/$(GPHOME)/share/postgresql/extension/postgis.control
	# The line below is a workaround of wrong file above
	#cp postgis.control-$(POSTGIS_VER) buildroot/$(GPHOME)/share/postgresql/extension/postgis.control
	# Actually, postgis.control file should appear in the directory below:
	cp $(POSTGIS_DIR)/extensions/postgis.control buildroot/$(GPHOME)/share/postgresql/extension/
	cp -r DEBIAN buildroot/
$(POSTGIS_DEB):
	dpkg-deb --build buildroot $(POSTGIS_DEB)

deb: prepare $(POSTGIS_DEB)
clean:
	rm -rf buildroot/* && rm -f $(POSTGIS_DEB) 
	make -C $(POSTGIS_DIR) clean


.PHONY: clean prepare build all

endif
