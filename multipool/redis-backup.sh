#!/bin/bash
REDIS_SOURCE=~/unomp/multipool/backup/redis.dump.rdb
BACKUP_DIR=~/unomp/multipool/backup/

BACKUP_PREFIX="redis.dump.rdb"
DAY=`date '+%a'`
REDIS_DEST="$BACKUP_DIR/$BACKUP_PREFIX.$DAY"

cp $REDIS_SOURCE $REDIS_DEST
