#!/bin/sh
cd "$(dirname "$0")"
{
	cat current.txt
	cat current-cfg.txt | ./backup-util find_updated_configs;
} | ./backup-util make_backup_points
