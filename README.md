
The manual below is telling about how to install greenplum on three segments and one master with no redundancy.

### Installing Postgresql extensions
**1. PostGIS**
PostGIS packages are built for CentOS/RHEL only.
For Ubuntu (and for others) PostGIS should be built from source. Specific sources available at [https://github.com/greenplum-db/geospatial](https://github.com/greenplum-db/geospatial)

To compile PostGIS do the following(assuming all actions under root):

**a. install necessary additional packages:**
```shell
# apt-get install autoconf automake libtool gdal gdal-data expat libexpat1 libjson-c-dev geos-devel \
proj-devel libgeos++-dev libproj-dev libcunit1-dev libcunit1-doc gdal-bin libgdal-dev xsltproc docbook-xsl docbook-mathml libxslt1-dev libxslt1
```
**b. clone postgis sources prepared special for greenplum:**

clone sources from:
```shell
# git clone --recursive https://github.com/denismatveev/Greenplum_PostGIS_deb.git .
```
The repository above has git submodule and cloning `GP_PostGIS_deb.git` repository will bring PostGIS repository too(repository in submodule is cloning only that commit which was at creating moment).

Since postgis-2.5.4 cannot be built by gcc-7 and later, it is supposed to modify one source file ```postgis/build/postgis-2.5.4/raster/rt_pg/rtpg_mapalgebra.c``` in 937 line:
replace the piece
```
if (arg->numraster > 1) {
   	i = 1;	
break;	
}
```
By the following:
```
i = (arg->numraster > 1) ? 1 : 0;
break;
```

**c. Build a deb package:**
```shell
# make
```
You'll see the file ```greenplum-db-6-postgis-2.5.4-1.x86_64.deb```
Then copy the file from buildhost to the master node.
**d. Copy the file from masternode among all nodes:**
Before copying do the executables from greenplum availabe (source that .bashrc which contains this)
```shell
# gpscp -v -f cluster_hostlist  ../greenplum-db-6-postgis-2.5.4-1.x86_64.deb =:~/
```
**e. Install the package on all nodes:**
```shell
# gpssh -f cluster_hostlist 'dpkg -i greenplum-db-6-postgis-2.5.4-1.x86_64.deb; apt-get -y -f install
```
If you want ti check:
```shell
gpssh -f cluster_hostlist -e  'dpkg -l | grep greenplum'
```
**f. Restart the Greenplum database:**
```shell
# su - gpadmin
$ gpstop -ra
```
**g. Check if the Greenplum has postGIS extension:**
Connect to any database you want to create extension. Then type the following:
```
database=# CREATE EXTENSION postgis ;

database# CREATE EXTENSION postgis; -- enables postgis and raster
database# CREATE EXTENSION fuzzystrmatch; -- required for installing tiger geocoder
database# CREATE EXTENSION postgis_tiger_geocoder; -- enables tiger geocoder
database# CREATE EXTENSION address_standardizer; -- enable address_standardizer
database# CREATE EXTENSION address_standardizer_data_us;
```
Also, you should set up environmental variables listed below. Just put them in ```/opt/greenplum-db-6-6.13.0/greenplum_path.sh```
```
export GDAL_DATA=$GPHOME/share/gdal
export POSTGIS_ENABLE_OUTDB_RASTERS=0
export POSTGIS_GDAL_ENABLED_DRIVERS=DISABLE_ALL
```
The fastest way to do that is to use the following command:
```
# gpssh -f cluster_hostlist -e  'echo -en "export GDAL_DATA=\$GPHOME/share/gdal\nexport POSTGIS_ENABLE_OUTDB_RASTERS=0\nexport POSTGIS_GDAL_ENABLED_DRIVERS=DISABLE_ALL\n" >> /opt/greenplum-db-6-6.13.0/greenplum_path.sh'
```
Then ensure the database to be restarted: ```gpadmin@master01:~$ gpstop -ra```
For more information, please read official [documentation](https://github.com/greenplum-db/geospatial)
