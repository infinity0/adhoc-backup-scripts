Contents

- [rsconf](#rsconf): simple backup framework for rsnapshot
- [luksblk](#luksblk): manage simple LUKS block devices
- [btsync](#btsync): synchronise a file over bittorrent
- [git-apt](#git-apt): track interesting parts of APT package state
- [git-etc](#git-etc): track subparts of a filesystem

rsconf+luksblk+btsync is my personal backup solution.

I'll describe why I wrote my own rather than use existing ones as well :)

----

# rsconf

A backup framework on top of rsnapshot - which is flexible and powerful, but
because of this, its config files are fairly complex to set up and understand.

Current restrictions - **READ**:

- only backs up to local fs. This includes mounted remote resources (e.g. nfs,
  sshfs), but not non-fs resources even if rsnapshot supports it (e.g. ssh://)
- only backs up files, not e.g. database dumps, but could be easily extended to

Features on top of rsnapshot:

- provides sensible defaults for a large chunk of a typical rsnapshot config.
	- separates backup source config vs. rotation/schedule config. admins can focus
	  on customising the former; developers can refine the latter for better reuse.
	- joins rsnapshot rotation times with crontab schedules, which unfortunately are
	  separated in rsnapshot and annoying to keep consistent.
- utility methods to automate more complex but important backup cases.
	- detects system config files customised by the user, and ignores files that are
	  unchanged from installation.

## Pre-use

Depends: rsnapshot (>= 1.3.1), debsums, dlocate

You may also need to patch rsnapshot:

- if using upstream 1.3.1, you need to apply [r401][], [r406][]
- if using debian 1.3.1-1, you need to apply [r401][], [r406][]
- if using debian 1.3.1-2 or -3, you need to apply [r406][]

[r401]: http://rsnapshot.cvs.sourceforge.net/viewvc/rsnapshot/rsnapshot/rsnapshot-program.pl?r1=1.400&r2=1.401&view=patch
[r406]: http://rsnapshot.cvs.sourceforge.net/viewvc/rsnapshot/rsnapshot/rsnapshot-program.pl?r1=1.405&r2=1.406&view=patch

## Use

Run `rsconf` to print a quick checklist for setting up a backup. It will give
you a list of things to customise; please do so if necessary. If the help text
in the default config files are unclear, you can read below for a more detailed
explanation.

Each backup is stored in a directory `$BACKUP_ROOT` (we'll refer to this as ~)
on the local filesystem. `~/backup.list` defines the source files of the backup,
and it also points to a scheme file which defines when a snapshot is made, how
rotations work, when old snapshots are expired, etc (we'll refer to this as the
rotation/schedule).

Both backup.list and *.scheme are divided up into "chapters" (delimited by `==`)
and "sections" (delimited by `--`). Each chapter defines a named backup target,
stored in ~/[NAME]/. Each backup target effectively has its own rsnapshot config
(which rsconf dynamically generates), including the rotation/schedule config.

The chapters in backup.list MUST match the ones in the scheme it points to.

Scheme files are intended to be distributed together with rsconf to save the
user having to specify their own rotation/schedule (which is quite fiddly) but
you can write your own as well if the ones provided really don't satisfy your
needs. Currently scheme files are found in the /share/ subdirectory of the real
path of `rsconf`, but this could be extended to be more easily customisable.

### backup.list chapters

Each section has a heading (which is the method used to select files) and some
content (usually a list) to apply to the method. See `examples/backup.list` for
a list of all the methods and brief notes on what the content should be.

You can test the output of some content applied to a particular find-method by
sending it to `rsconf test_find_method [METHOD]`. e.g.

	$ echo /etc | rsconf test_find_method all
	backup	/etc	$BACKUP_TARGET/

Note that $BACKUP_TARGET/ will be replaced by the actual backup target.

There is currently no support for adding and using your own methods, but I might
accept a patch for it. However, I would prefer to add new methods to rsconf
itself, rather than encourage users to implement their custom solutions. We are
trying to save work and encourage reuse, after all.

### scheme file chapters

There are two sections, RETAIN and CRONTAB.

RETAIN is what goes into the generated rsnapshot config - see the "retain"
keyword in the rsnapshot manual for more details.

CRONTAB is what goes into your crontab, when you install your backup.list.
$RS_CONF will automatically be set to the correct filename. The rsnapshot manual
tells you how you set up your crontab entries to match your "retain" settings.

See 2tier.scheme for an example.

----

# luksblk

A tool for managing simple LUKS block devices.

Current restrictions - **READ**:

- the LUKS-formatted block device must contain exactly one normal (mountable)
  filesystem, and not some other abstraction like partition tables or LVM

Features on top of cryptsetup:

- provides simple commands for common high-level operations
- keeps metadata together at a pre-defined location so commands mostly take no
  arguments
- additional helper commands for acting on a disk image file

## Pre-use

Depends: cryptsetup

## Use

Run `luksblk` for detailed help text. This should be enough to get you started.

### Editing the crypto settings

If you need to edit the crypto settings, you'll need to re-backup the new LUKS
header afterwards using the `header` subcommand.

### Non-root read access

You probably want non-root read access to the LUKS-formatted block devices
managed by this script - e.g. to use `btsync` to do remote backups. Read access
is only to the encrypted form of the data, so there less potential for a leak.

You can create a single-purpose user for this, but you probably also need to
give it access that persists across reboots. One way to do this is via udev. If
your arrangement is quirky enough that online help isn't easily available, see
examples/99-local-*.rules for some not-so-common use cases. In most cases, you
probably want to set GROUP="<NON_ROOT_USER>" MODE="0640".

On a related note, `luksblk` itself tries to avoid using root privileges. It
assumes it has read access to the block device, so you need to set up the above
if you want to run this script not as root. It assumes that it needs root for
write access and various other things such as cryptsetup and device access;
these operations use sudo automatically.

----

# btsync

Synchronise snapshots of a dynamic file to multiple peers over bittorrent.

The bittorrent protocol is transfer-efficient for *in-place* edits, but not
*insertions* or *deletions*, i.e. iff [Hamming distance][] is short, regardless
of [Levenshtein distance][]. This covers the primary design use case, where the
"file" is a block device that holds a (maybe encrypted) filesystem. Typically,
efficiency is maintained when you expand the filesystem, but not necessarily
when you shrink it. Efficiency may also be lost when/if you defragment the
filesystem, but this is a necessary cost.

On the other hand, if, for your use-case, Hamming distance is typically large
but Levenshtein distance is small (e.g. ABCDEFGH -> ABXCDEFGH), `rsync` is more
transfer-efficient between each sender/receiver pair, but the peer-to-peer
nature of bittorrent may still give a quicker overall transfer time when the
total number of peers is large - so run some tests if performance is an issue.
(One way better than either of these, would be to use the rsync diff algorithm
but have peer-to-peer transfers like bittorrent; but this seems very complex to
achieve.)

[Hamming distance]: http://en.wikipedia.org/wiki/Hamming_distance
[Levenshtein distance]: http://en.wikipedia.org/wiki/Levenshtein_distance

## Pre-use

Depends (origin node): bittornado (>= 4.0), python, ssh, (transmission-create | mktorrent), {peer node dependencies}

Depends (peer nodes): (transmission-daemon, transmission-remote, nc) | (rtorrent, screen, python, xmlrpc2scgi)

Manual patching (origin node only):

- bttrack: use the version from bittornado's CVS
	- `$ cvs -d:pserver:anonymous@cvs.degreez.net/cvsroot co bittornado && cd bittornado`
	- `bittornado$ for i in $THIS_GIT_REPO/patches/bttrack_*.patch; do patch -lp0 < "$i"; done`
	- `bittornado$ mkdir -p ~/bin && sed -e '1s/env python/python/g' bttrack.py > ~/bin/bttrack`

If you plan to create torrents from block devices, you'll need to apply one of
the following too, and rebuild+reinstall as appropriate (origin node only):

- mktorrent: [github fork][blkdev_mktorrent]
- transmission-create: TODO send a patch to them for this

[blkdev_mktorrent]: https://github.com/infinity0/mktorrent/tree/blkdev

Other notes:

- [xmlrpc2scgi.py][] ([DL][xmlrpc2scgi.raw]) is included in this git repo for
  your convenience. `btsync` will automatically copy this to each peer, but you
  can optionally install it into the normal PATH of each peer (inc. origin), if
  you prefer not to keep binaries with your run-time data. You should install it
  with the .py extension; this is because it contains a -p option which is
  python-specific and I didn't want to make assumptions about any potential
  "xmlrpc2scgi" tool that might pop up in the future.

[xmlrpc2scgi.py]: http://libtorrent.rakshasa.no/wiki/UtilsXmlrpc2scgi
[xmlrpc2scgi.raw]: http://libtorrent.rakshasa.no/raw-attachment/wiki/UtilsXmlrpc2scgi/xmlrpc2scgi.py

## Use

Run `btsync init` until it stops complaining at you. It will give you a list of
things to customise; please do so if necessary. If the help text in the default
config files are unclear, you can read below for a more detailed explanation.

After everything is validated, run `btsync dist <file> <snapshot label>` each
time you want to synchronise a snapshot. It is assumed that a label is newer
than another if it appears later in sort order (which must be the same across
all peers). Older labels are expired as appropriate, and re-used as initial
data for a newer torrent.

You only ever run `btsync` on the origin host, although every peer, including
the origin, needs to have a work_dir where btsync puts its run-time files. On
the origin, this is given by the standard "current working directory", or the
env var CWD if set. On the remote peers, this is read from `remotes.txt` in the
origin work_dir. (This file is created automatically when you run `btsync init`
enough times.) You need SSH access to each peer; see `remotes.txt` for details.

You also *must* customise `bttrack.vars` (origin host only) - see the operation
section below for a more detailed explanation on what everything means, if the
hints are unclear.

You also may want to customise `btsync.vars` on each peer. This is typically
optional, but may be necessary for certain setups, e.g. if the firewall settings
don't allow incoming traffic on arbitrary ports, which would prevent the default
"random" port setting from working.

### Operation

Each peer (including the origin node) runs a bittorrent client; the origin node
additionally runs a HTTPS bittorrent tracker. The tracker treats knowledge of a
torrent's info_hash as implicit authorisation to obtain data for that torrent.
To protect the info_hash, each client only presents it to a tracker if its
certificate is signed by your own CA cert, which is distributed out-of-band via
SSH to the client as part of the normal operation of this tool (see below).

See [this helpful article][d-a_openssl] for a walkthrough on how to create your
own CA cert and sign a domain certificate using it. TODO make this a script

[d-a_openssl]: http://www.debian-administration.org/articles/284

The only reason we use SSL is because the bittorrent protocol currently doesn't
support any other signature method for the tracker. Treat the tracker's SSL
certificate like a GPG signature, and the CA cert like a GPG public/private key.
In other words, the CA cert must be controlled by YOU, and you should not sign
certificates for other people since they can use it to masquerade as you, for
the purposes of this tool.

As a corollary, note that using an actual root CA cert completely voids these
security properties, since anyone can get a certificate signed by a root CA for
a price, and can then trick your clients into revealing the info_hash simply by
doing MITM on the client-tracker connection.

NB: the security framework only supports one-CA-cert-per-client, meaning that
all the torrents on that client must use the same tracker. One workaround is to
use a different btsync work_dir for each distinct tracker you need to use. (This
doesn't seem easy to fix, as there is no way to instruct "this tracker must be
signed by this particular CA" on a per-torrent basis, only per-client.)

### HTTPS reverse proxy

So far we've been talking about an HTTPS tracker. In actual fact, this tool
currently uses bttrack which is HTTP only. Therefore you need to also set up an
HTTPS reverse proxy to the bttrack process, which listens on the local interface
only. Make sure the reverse proxy sets the X-Forwarded-For header correctly;
most non-anonymising web servers do this.

See examples/bttrack.*.conf for snippets on how to configure various web servers
to set up the reverse proxy.

You might also need to tweak the TRACKER_HACK variable in bttrack.vars. Due to
this reverse proxy setup, `--fallback_ip` is likely necessary in most cases.

----

# git-apt

Keeps track of the "interesting" parts of aptitude package state.

## Pre-use

Depends: python, aptitude, git

## Use

$ apt-pkg i
$ apt-pkg u

----

# git-etc

(intro)

## Pre-use

Depends: git, liblchown-perl

## Use
