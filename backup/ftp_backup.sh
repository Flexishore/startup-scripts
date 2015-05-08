#!/bin/sh
# FLexishore script for backuping
#
# Piotr Nowak <piotr.n@flexishore.com>
#
# Based on many scripts and my experience
# ---------------------------------------------------------------------

### System Setup ###
DATE_TODAY=`date +%Y%m%d`
DATE_WEEKAGO=`date --date '7 days ago' +%Y%m%d`

TMP_DIR='/home/tmp/backup'
MYSQL_DIR='/home/db.dumps'
DIRS="/home/www"

### MySQL Setup ###
MUSER="root"
MPASS="sRhgQUfQW8ZlPLvV4V1F"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"

### FTP server Setup ###
FTP_HOST='ftpback-rbx6-73.ovh.net'
FTP_LOGIN='ns309610.ip-188-165-196.eu'
FTP_PASS='m2T6wppqrk'

### Other stuff ###
SERVERID="$(hostname)"
LOG="/tmp/backup.log"
REPORT="/tmp/backup.report"
EMAILID="rafal.k@flexishore.com"
STATUS=0

#save start time
echo "Start      $(date)">$REPORT

#directory works
BACKUP_FILE=backup-$DATE_TODAY.tar.gz
OLD_BACKUP_FILE=backup-$DATE_WEEKAGO.tar.gz
rm -f $TMP_DIR/$BACKUP_FILE
rm -f $MYSQL_DIR/*.sql
echo $OLD_BACKUP_FILE
### Start MySQL Backup ###
echo "********************"
echo "*** MYSQL Backup ***"
echo "********************"
# Get all databases name
DBS="$($MYSQL -u$MUSER -p$MPASS -h$MHOST -Bse 'show databases' 2>$LOG)"
if [ "$?" != "0" ]; then
  STATUS=3
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! ERROR: Getting db list failed !!!!!!!!!!!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
else
  for db in $DBS
  do
    if [ "$db" != "information_schema" ] && [ "$db" != "performance_schema" ]; then
      FILE=$MYSQL_DIR/mysql-$db.$DATE_TODAY.sql
      $MYSQLDUMP -u$MUSER -h$MHOST -p$MPASS $db >$FILE 2>>$LOG
      if [ "$?" != "0" ]; then
        STATUS=4
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!! ERROR: MYSQL DB $db backup failed !!!!!!!!"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      else
        echo "*** MYSQL DB $db dump saved ***"
      fi
    fi
  done
fi

### Start Backup for file system ###
echo "******************************"
echo "*** Backup for file system ***"
echo "******************************"

DIRS="$DIRS $MYSQL_DIR"

echo "*** Start full FS backup ***"
tar zcfP $TMP_DIR/$BACKUP_FILE $DIRS 2>$LOG
if [ "$?" != "0" ]; then
	STATUS=1
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!!! ERROR: Full backup failed !!!!!!!!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
else
	echo "*** Full FS backup done ***"
fi

### Dump backup using FTP ###
echo "******************" 
echo "*** FTP Backup ***" 
echo "******************" 
ncftpput -u$FTP_LOGIN -p$FTP_PASS $FTP_HOST / $TMP_DIR/$BACKUP_FILE
if [ "$?" != "0" ]; then
  STATUS=7
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! ERROR: FTP upload failed !!!!!!!!!!!!!!!!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
else
  echo "*** FTP upload finished ***"
fi

rm -rf $MYSQL_DIR/*.sql
rm -rf $TMP_DIR/*.tar.gz

#deleting old
ftp -in <<EOF
	open ${FTP_HOST}
	user ${FTP_LOGIN} ${FTP_PASS}
	bin
	verbose
	prompt
	delete $OLD_BACKUP_FILE
	bye
EOF

### Mailer ###
echo "**********************"
echo "*** Sending report ***"
echo "**********************"
rm -f $TMP_DIR/$OLD_BACKUP_FILE

echo "Finished $(date)">>$REPORT
echo "Hostname $(hostname)">>$REPORT
echo $status
for EMAIL in $EMAILID; do
    if [ "$STATUS" == "0" ]; then
      echo "Subject: $SERVERID Backup OK" | cat - "$REPORT" | /usr/sbin/sendmail "$EMAIL"
    else 
      echo>>$REPORT
      echo "Error code $STATUS">>$REPORT
      echo>>$REPORT
      echo "******* LOG *********">>$REPORT;    
      echo "Subject: $SERVERID Backup failed" | cat - "$REPORT" | cat - "$LOG" | /usr/sbin/sendmail "$EMAIL"
    fi
done
