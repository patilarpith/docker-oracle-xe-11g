#!/bin/bash

FREQUENCY=360
ADDR_CMD="/sbin/ifconfig | grep ether| awk '{print $2}'"
SEED=$(echo "$(eval $ADDR_CMD | tr -d '[:punct:][:space:][:alpha:]')% $FREQUENCY" | bc | awk '{print $1 + 0}')
TIME=$(echo $(date +[%H*60+%M])% $FREQUENCY | tr  '[' '(' | tr ']' ')' | bc)
echo "Seed: $SEED, Time: $TIME"
if [[ $SEED != $TIME ]]
then
    exit 0
fi

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE

# Stop the listener
$ORACLE_HOME/bin/lsnrctl STOP

# Delete unwanted trace and log files
rm -rf /u01/app/oracle/admin/XE/adump/*
rm -rf /u01/app/oracle/diag/rdbms/xe/XE/trace/*
rm -rf /u01/app/oracle/diag/tnslsnr/*

# Alter the tempspace
# http://dev-notes.com/code.php?q=65
# This should already be created
# create temporary tablespace temp2 tempfile '/u01/app/oracle/oradata/XE/temp02.dbf' size 1000m autoextend on next 100m maxsize 4000m;
sqlplus sys/codelabs11 as sysdba << EOM
alter database default temporary tablespace temp2;
alter database tempfile '/u01/app/oracle/oradata/XE/temp.dbf' drop including datafiles;
alter tablespace temp add tempfile '/u01/app/oracle/oradata/XE/temp.dbf' size 10000m autoextend on next 1000m maxsize 15000m;
alter database default temporary tablespace temp;
EOM

# Reboot server
/sbin/reboot

