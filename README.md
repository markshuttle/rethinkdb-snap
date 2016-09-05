# rethinkdb-snap

This is an 'external' snap of RethinkDB 2.3.5, meaning it downloads the
source and builds it.

## Building

On Ubuntu 16.04 LTS with snapcraft installed ('sudo apt install snapcraft'):

```
  git clone https://github.com/markshuttle/rethinkdb-snap
  cd rethinkdb-snap
  snapcraft
```

## Installing

Installing the snap you built yourself means you are installing an unsigned
snap, hence the --force-dangerous below. You will be able to install
'rethinkdb' directly from the store shortly, signed by the publisher.

```
  sudo snap install --force-dangerous ./rethinkdb_2.3.5_amd64.snap
```

## Using it

The RethinkDB snap creates a 'default' database on installation.
Configuration of that database is at:

```
  /var/snap/rethinkdb/common/config/default.conf
```

You can add additional configuration files 'foo.conf' in that same directory
to get additional instances of RethinkDB. Don't set runuser, rungroup or any
of the file path configuration items, those are opinionated in the snap
because snaps are opinionated about data persistence :)

Snaps run sandboxed, so there is a modified launch script that is passed to
the init system. That makes sure that data is in places that the snap can
write. The default port for the web adminiistration interface is 28080:

```
  http://localhost:28080
```

RethinkDB starts on boot after the snap is installed. The launch script is
`bin/snap-launch.sh` which is also executable as `rethinkdb.launch` after
installation. RethinkDB itself is executable directly as `rethinkdb`.

Data for the instances managed by the snap service is stored in:

```
  /var/snap/rethinkdb/common/data/<instance>/
```


## Feedback

I am `sabdfl` on Freenode, feedback to me directly or in #snappy on Freenode
please.

If the snap proves useful I can rework this as a PR for RethinkDB itself,
enabling snaps to be published automatically to the edge channel in the
store from Travis hooks.
