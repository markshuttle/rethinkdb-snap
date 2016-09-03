# rethinkdb-snap

This is an 'external' snap of RethinkDB 2.3.5.

## Building

  git clone https://github.com/markshuttle/rethinkdb-snap
  cd rethinkdb-snap
  snapcraft

## Installing

Installing the snap you built yourself means you are installing an unsigned
snap, hence the --force-dangerous below. You will be able to install
'rethinkdb' directly from the store shortly, signed by the publisher.

  sudo snap install --force-dangerous ./rethinkdb_2.3.5_amd64.snap

## Using it

The RethinkDB snap creates a 'default' database on installation.
Configuration of that database is at:

  /var/snap/rethinkdb/common/config/default.conf

Snaps run sandboxed, so there is a modified launch script that is passed to
the init system. That makes sure that data is in places that the snap can
write. The default port for the web adminiistration interface is 28080:

  http://localhost:28080


