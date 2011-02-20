#!/bin/sh
cd "$(dirname "$0")"
{
	cat archive.txt
} | ./backup-util make_backup_points
