# rsnapshot template file
#
# simplifies managing backup points, by including common defaults from rsnapshot.inc
# feel free to delete "rsync settings" unless you know what you're doing
#
# warning: some paths mean different things with/without a trailing /
# if in doubt, see the man page.
#

config_version	1.2
include_conf	/root/backup/rsnapshot.inc

## rsync settings

#rsync_short_args	-a
#rsync_long_args	--delete --numeric-ids --relative --delete-excluded
#one_fs	0

## Intervals

#sync_first	1
#retain	hourly	6
#retain	daily	7
#retain	weekly	4
#retain	monthly	3

## Backup points

#include	???
#exclude	???
#include_file	/path/to/include/file
#exclude_file	/path/to/exclude/file

#backup	/home/	localhost/
#backup	/etc/	localhost/
#backup	/var/	localhost/
#backup	/usr/local/	localhost/
