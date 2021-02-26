
The manual below is telling about how to install greenplum on three segments and one master with no redundancy.

All machines connected via local network and have internet connection. Initially all machines have Ubuntu 18.04 on board. Newer versions are not suitable, greenplum does not have prepared packages(repository) 
### Installation
**1. Install greenplum package**

It should be done on all nodes and on the master:
```shell
# sudo apt update
# sudo apt install software-properties-common
# sudo add-apt-repository ppa:greenplum/db

# sudo apt update
# apt-get install greenplum-db-6
```

Create user gpadmin(this is the main user is used for greenplum work)

```shell
# groupadd gpadmin
# useradd gpadmin -r -m -g gpadmin -s /bin/bash
# passwd gpadmin
```

Add the user to group sudo:

```shell
# usermod -aG sudo gpadmin
```

Generate rsa key(gpadmin user)

```shell
$ ssh-keygen -t rsa -b 4096
```

Add in `~/.bashrc` the following(only for gpadmin user):

```shell
source /opt/greenplum-db-6-6.13.0/greenplum_path.sh
```

Create a hostlist, let's say at `~/cluster/hostlist:`

```bash
segment01
segment02
segment03
```

Of course, these hosts should be in `/etc/hosts` on all nodes:

```bash
127.0.1.1 master01 master01
172.16.10.3 segment01
172.16.10.4 segment02
172.16.10.5 segment03
```

Copy ssh open keys from the master to each node:
(it's enough to copy for gpadmin)
```bash
$ ssh-copy-id segment01
$ ssh-copy-id segment02
$ ssh-copy-id segment03
```

Enable passwordless access in sshd_config(if necessary) and copy keys between nodes
(segment01<->segment02<->segment03)

on the master:
```shell
$ cd ~/cluster/
$ gpssh-exkeys -f cluster_hostlist
```

The command above will distribute keys among segments(will make passwordless access from segment02-segment03, segment02-segment03 etc )

**2. Check GreenPlum installation**

On the master:

```shell
$ gpssh -f ~/cluster/cluster_hostlist -e 'ls -l /opt/greenplum-db-6-6.12.1/
```

Also, check availability segment01 from segment02 and vice versa

**3. Create data directories**
On the master:

```shell
# mkdir -p /data/master
# chown gpadmin: /data/master
```

```shell
# cd /home/gpadmin/cluster
# source /opt/greenplum-db-6-6.13.0/greenplum_path.sh
# gpssh -f cluster_hosts -e 'mkdir -p /data/primary'
# gpssh -f cluster_hosts -e 'chown -R gpadmin /data/*'
```

Then add the string on the master ONLY:

```shell
$ echo 'export MASTER_DATA_DIRECTORY=/data/master/gpseg-1' >> /home/gpadmin/.bashrc
```

**4. Perform tests**

Network test

```shell
$ /opt/greenplum-db-6-6.13.0/bin/gpcheckperf -f cluster_hostlist -r N -d /tmp/
```

You'll see something like this(cpx21 and cx21):

```shell
-------------------
--  NETPERF TEST
-------------------
NOTICE: -t is deprecated, and has no effect
NOTICE: -f is deprecated, and has no effect
NOTICE: -t is deprecated, and has no effect
NOTICE: -f is deprecated, and has no effect

====================
==  RESULT 2020-12-11T14:43:51.595891
====================
Netperf bisection bandwidth test
segment01 -> segment02 = 398.050000
segment02 -> segment01 = 796.920000

Summary:
sum = 1194.97 MB/sec
min = 398.05 MB/sec
max = 796.92 MB/sec
avg = 597.49 MB/sec
median = 796.92 MB/sec

[Warning] connection between segment01 and segment02 is no good
```

**4. Configure NTP**
On master node open `/etc/ntp.conf`
the following allows to connect from local network:
```shell
restrict 172.16.10.0 mask 255.255.255.0
```

on each segment node in ` /etc/ntp.conf` should be present:
```shell
server master01 prefer
```

**5. Adjust some kernel parameters**
```shell
#vi /etc/sysctl.conf
```

```bash
net.ipv4.tcp_syncookies = 1
vm.overcommit_memory = 2
vm.swappiness = 10
vm.overcommit_ratio = 95
kernel.shmall = 996669
kernel.shmmax = 4082356224
vm.dirty_background_ratio = 3
vm.dirty_ratio = 10
net.ipv4.ip_local_port_range = 10000 65535 # See Port Settings
kernel.sem = 500 2048000 200 4096
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.zone_reclaim_mode = 0
```


`kernel.shmall` and `kernel.shmmax` should be calculated as
```
kernel.shmall = _PHYS_PAGES / 2
kernel.shmmax = kernel.shmall * PAGE_SIZE
```

Apply the changes:
```shell
# sysctl -p
```

Add the lines below to 
```shell
/etc/security/limits.conf
```
```shell
* 		soft 	 nofile 	524288
* 		hard 	 nofile 	524288
* 		soft 	 nproc 		131072
* 		hard 	 nproc 		131072
```




**7. Security related**
Setup the firewall:
 ```# ufw allow from any to any port 22
 # ufw allow from 172.16.10.0/24
 ```
 Enable:
 ```shell 
 # ufw enable
 ```
### Initialization

**1. Prepare**
Copy config file(only on the master)
```shell
$ cd /home/gpadmin/cluster
$ cp /opt/greenplum-db-6-6.13.0/docs/cli_help/gpconfigs/gpinitsystem_config
```
**2. Edit the config file on the master**
For this case enough to replace the following parameters:
```shell
declare -a DATA_DIRECTORY=(/data/primary)
MASTER_HOSTNAME=master01
MASTER_DIRECTORY=/data/master
```
**3. Initialize**
```bash
$ cd /home/gpadmin/cluster
$ gpinitsystem -c gpinitsystem_config -h cluster_hostlist
```
Then on the question
```bash
=> Continue with Greenplum creation? Yy/Nn
```
answer yes

You should see a message the initialization process has finished.
**4. Enable SSL** 

Client which is connecting to master node must support SSL, otherwise server will refuse connecting.
SSL connection between segments is not required, because it already uses ssh.

To enable server's SSL generate SSL certificates:
a. Generate a private key and a signing request
`$ openssl req -out CSR.csr -new -newkey rsa:2048 -nodes -keyout master.key`
b. Generate a self signed certificate
`$ openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 -keyout master.key -out master.crt`

Put the key and the certificate into, let's say, `/data/master/gpseg-1/ssl/` subdirectory.
Then configure master node postgresql to use SSL:
uncomment the following strings in the 

```shell
$ vi /data/master/gpseg-1/postgresql.conf
```

```shell
   ssl = on
   ssl_cert_file = 'ssl/master.crt'
   ssl_key_file = 'ssl/master.key
   password_encryption = on
   ```

Restart postgres instances:
```shell
$ gpstop -ra
```
### How to connect to the master with psql

**Note.** Should be used master node to work with greenplum

```shell
$ psql -h 127.0.0.1 -U gpadmin "sslmode=require" -d postgres
```

gpadmin role is a superuser in postgresql and then you can create regular user and database

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
