### Installing Postgresql extensions

**1. PostGIS**

PostGIS packages are built for CentOS/RHEL only.
For Ubuntu (and for others) PostGIS should be built from source. Specific sources available at [https://github.com/greenplum-db/geospatial](https://github.com/greenplum-db/geospatial)

To compile PostGIS do the following(assuming all actions under root):

**a. Install necessary additional packages:**
```shell
# apt-get install autoconf automake libtool gdal gdal-data expat libexpat1 libjson-c-dev geos-devel \
proj-devel libgeos++-dev libproj-dev libcunit1-dev libcunit1-doc gdal-bin libgdal-dev xsltproc docbook-xsl docbook-mathml libxslt1-dev libxslt1
```
**b. Clone postgis sources prepared special for greenplum:**

clone sources from:
```shell
# git clone --recursive https://github.com/denismatveev/Greenplum_PostGIS_deb.git .
```
The repository above has git submodule and cloning `Greenplum_PostGIS_deb.git` repository will bring PostGIS repository too(repository in submodule is cloning only that commit which was at creating moment).

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
# make deb
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
If you want to check:
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
Then ensure the database to be restarted: ```gpadmin@master:~$ gpstop -ra```
For more information, please read official [documentation](https://github.com/greenplum-db/geospatial)

### A few notes regarding gppkg file format and installation process

gppkg is a format of greenplum packages ready to install. It implies fast installing on all nodes by one command on the master. These files are an archive of preliminarily built OS-specific packages. It can be rpm or deb. Now officially they support rpm packages only. It means if you use Debian-based Linux, you should build from sources.

**a. Build a gppkg package**

To build postgis gppkg package, type the following command in a terminal:

```
# make
```
you will get the package named like **postgis-ossv2.5.4+pivotal.3_pv2.5_gpdb6.0-debian-amd64.gppkg**

For Debian, it has some features.

**b. gppkg installation process description**

Before installing gppkg you shoud perform some preparations.

Export postgres and greenplum specific environmental variables:
 ```
 # export MASTER_DATA_DIRECTORY=/data/master/gpseg-1
 # export PGUSER=gpadmin
 # export PGDATABASE=postgres
 # export PGHOST=127.0.0.1
 ```
 
 Source the 
 
 ```
# source /opt/greenplum-db-6-6.13.0/greenplum_path.sh
```

gppkg format implies installing into chroot(for greenplum it is GPHOME that is /opt/greenplum-<version>). Learning sources, I realized, from 

```
# vi /opt/greenplum-db-6-6.13.0/lib/python/gppylib/operations/package.py +861
```
that
```
 gppkg -i postgis-ossv2.5.4+pivotal.3_pv2.5_gpdb6.0-debian-amd64.gppkg
```
copying deb package into
```
"$GPHOME"/.tmp/
```
and 

launches the command like

```
# fakeroot dpkg --force-not-root  --log=/dev/null --admindir="$GPHOME"/.tmp/ --instdir="$GPHOME" -i <package.deb>
```

which means a package will be installed into *instdir* directory and for storing information about installed packages will be used *admindir*(like /var/lib/dpkg in normal installation). From man follows that for installing into *instdir* is used chroot. So it is irrelevant if your package doesn't have any scripts inside like postinst or postrm.
If you are going to install deb package contains postinst, postrm etc scrtips, this will not work, because for chrooting it should have at least an interpreter for launching scripts (bash or sh etc).

Yes, there is an approach to install bash and minimal system into a specific directory and then chrooting there. Such approach is useful for many cases such as installing a system for a virtual machine(debootstrap). I consider it is not a suitable process for installing packages especially installing on all nodes in a cluster. 

By the way, since gppkg installs a deb pacakge into a specific directory as a root, deb package should contain directories tree relatively installing directory as root("/").
For this reason, the approach when the deb package is installed into the system packages database is more suitable at the moment because it does not require modifying greenplum sources. 

**c. gppkg dependencies**

Moreover, if your deb package has dependencies the

```
# dpkg -i <package>
```
cannot resolve dependencies of the package. If the deb package depends on other software, you should resolve them after unsuccessful installation, running the following:
```
# apt-get -f install
```
The command above will install all packages necessary for the deb and then will install the deb package itself.

Modify `/opt/greenplum-db-6-6.13.0/greenplum_path.sh` as said above on all nodes. 
**Disclaimer**
I am not sure if the deb package has Half-inst status on the master, this package will appear on all nodes at the same status. Most likely, nodes will not have such package.

**d. Remove the deb package**

To remove half installed deb package(since it is impossibe to remove using `gppkg --remove` command)
Use the following:

```
# dpkg --admindir=/opt/greenplum-db-6-6.13.0/share/packages/database/deb  --remove --force-remove-reinstreq greenplum-db-6-postgis
# rm /opt/greenplum-db-6-6.13.0/.tmp/ -rf
```

The latter command will remove copied deb package.
