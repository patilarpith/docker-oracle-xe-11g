#!/bin/bash

# avoid dpkg frontend dialog / frontend warnings
export DEBIAN_FRONTEND=noninteractive

# Prepare to install Oracle
apt-get update
apt-get install -y libaio1 net-tools bc
mkdir -p /var/lock/subsys
mv /assets/chkconfig /sbin/chkconfig
chmod 755 /sbin/chkconfig

# Install Oracle
cat /assets/oracle-xe_11.2.0-1.0_amd64.deba* > /assets/oracle-xe_11.2.0-1.0_amd64.deb &&
dpkg --install /assets/oracle-xe_11.2.0-1.0_amd64.deb

# Backup listener.ora as template
cp /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora.tmpl
cp /u01/app/oracle/product/11.2.0/xe/network/admin/tnsnames.ora /u01/app/oracle/product/11.2.0/xe/network/admin/tnsnames.ora.tmpl

mv /assets/init.ora /u01/app/oracle/product/11.2.0/xe/config/scripts
mv /assets/initXETemp.ora /u01/app/oracle/product/11.2.0/xe/config/scripts

printf 8080\\n1521\\noracle\\noracle\\ny\\n | /etc/init.d/oracle-xe configure

echo 'export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe' >> /etc/bash.bashrc
echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> /etc/bash.bashrc
echo 'export ORACLE_SID=XE' >> /etc/bash.bashrc

# Install startup script for container
cp /assets/startup.sh /usr/sbin/startup.sh
cp /assets/cleanup.sh /usr/sbin/cleanup.sh
chmod +x /usr/sbin/startup.sh
chmod +x /usr/sbin/cleanup.sh

# Create initialization script folders
mkdir /docker-entrypoint-initdb.d

# Disable Oracle password expiration
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE

echo "ALTER PROFILE DEFAULT LIMIT PASSWORD_VERIFY_FUNCTION NULL;" | sqlplus -s SYSTEM/oracle
echo "alter profile DEFAULT limit password_life_time UNLIMITED;" | sqlplus -s SYSTEM/oracle
echo "alter user SYSTEM identified by oracle account unlock;" | sqlplus -s SYSTEM/oracle
cat /assets/apex-default-pwd.sql | sqlplus -s SYSTEM/oracle

# Configure oracle server
sqlplus SYS/oracle as sysdba << EOM
create temporary tablespace temp2 tempfile '/u01/app/oracle/oradata/XE/temp02.dbf' size 1000m autoextend on next 100m maxsize 4000m;
ALTER database datafile '/u01/app/oracle/oradata/XE/system.dbf' AUTOEXTEND ON maxsize 2G;
ALTER SYSTEM SET NLS_DATE_FORMAT='YYYY-MM-DD' SCOPE=SPFILE;
alter system set processes=400 scope=spfile;
alter system set sessions=600 scope=spfile;
EOM

# Add cron
crontab -l > cronfile
#echo new cron into cron file
echo "* * * * /usr/sbin/reboot.sh" >> cronfile
#install new cron file
crontab cronfile
rm cronfile
