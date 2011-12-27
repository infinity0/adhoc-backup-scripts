# Useful common settings

config_version	1.2

## Global settings

no_create_root	1
use_lazy_deletes	1
rsync_numtries	3
one_fs		1
link_dest	0	# not needed because we have GNU cp

## Logging and locking

verbose	2
loglevel	3
logfile	/var/log/rsnapshot.log
lockfile	/var/run/rsnapshot.pid

## Components

cmd_cp		/bin/cp
cmd_rm		/bin/rm
cmd_rsync	/usr/bin/rsync
cmd_ssh	/usr/bin/ssh
#cmd_logger	/usr/bin/logger
#cmd_du		/usr/bin/du
#cmd_rsnapshot_diff	/usr/local/bin/rsnapshot-diff
#cmd_preexec	/path/to/preexec/script
#cmd_postexec	/path/to/postexec/script

## Component args

#ssh_args	-p 22
#du_args	-csh
