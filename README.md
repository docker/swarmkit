# [SwarmKit](https://github.com/docker/swarmkit)

[![GoDoc](https://godoc.org/github.com/docker/swarmkit?status.png)](https://godoc.org/github.com/docker/swarmkit)
[![Circle CI](https://circleci.com/gh/docker/swarmkit.svg?style=shield&circle-token=a7bf494e28963703a59de71cf19b73ad546058a7)](https://circleci.com/gh/docker/swarmkit)
[![codecov.io](https://codecov.io/github/docker/swarmkit/coverage.svg?branch=master&token=LqD1dzTjsN)](https://codecov.io/github/docker/swarmkit?branch=master)
[![Badge Badge](http://doyouevenbadge.com/github.com/docker/swarmkit)](http://doyouevenbadge.com/report/github.com/docker/swarmkit)

*SwarmKit* is a toolkit for orchestrating distributed systems at any scale. It includes primitives for node discovery, raft-based consensus, task scheduling and more.

Its main benefits are:

- **Distributed**: *SwarmKit* implements the [Raft Consensus Algorithm](https://raft.github.io/) in order to coordinate and does not rely on a single point of failure to perform decisions.
- **Secure**: Node communication and membership within a *Swarm* are secure out of the box. *SwarmKit* uses mutual TLS for node *authentication*, *role authorization* and *transport encryption*, automating both certificate issuance and rotation.
- **Simple**: *SwarmKit* is operationally simple and minimizes infrastructure dependencies. It does not need an external database to operate.

## Overview

Machines running *SwarmKit* can be grouped together in order to form a *Swarm*, coordinating tasks with each other. Once a machine joins, it becomes a *Swarm Node*. Nodes can either be *Worker Nodes* or *Manager Nodes*.

- **Worker Nodes** are responsible for running Tasks using an *Executor*. *SwarmKit* comes with a default *Docker Container Executor* that can be easily swapped out.
- **Manager Nodes** on the other hand accept specifications from the user and are responsible for reconciling the desired state with the actual cluster state.

An operator can dynamically update a Node's role by promoting a Worker to Manager or demoting a Manager to Worker.

*Tasks* are organized in *Services*. A service is a higher level abstraction that allows the user to declare the desired state of a group of tasks.  Services define what type of task should be created as well as how to execute them (e.g. run this many instances at all times) and how to update them (e.g. rolling updates).

## Build

Requirements:

- go 1.6 or higher
- A [working golang](https://golang.org/doc/code.html) environment

From the project root directory, run:
```
make binaries
```

## Test

Before running tests for the first time, setup the tooling:

```bash
$ make setup
```

Then run:

```bash
$ make all
```

## Usage Examples

### 3 Nodes Cluster

These instructions assume that `swarmd` and `swarmctl` are in your PATH.

(Before starting, make sure `/tmp/node-N` don't exist)

Initialize the first node:

```sh
$ swarmd -d /tmp/node-1 --listen-control-api /tmp/manager1/swarm.sock --hostname node-1
```

In two additional terminals, join two nodes (note: replace `127.0.0.1:4242` with the address of the first node)

```sh
$ swarmd -d /tmp/node-2 --hostname node-2 --join-addr 127.0.0.1:4242
$ swarmd -d /tmp/node-3 --hostname node-3 --join-addr 127.0.0.1:4242
```

In a fourth terminal, use `swarmctl` to explore and control the cluster. Before
running swarmctl, set the `SWARM_SOCKET` environment variable to the path to the
manager socket that was specified to `--listen-control-api` when starting the
manager.

To list nodes:

```
$ export SWARM_SOCKET=/tmp/manager1/swarm.sock
$ swarmctl node ls
ID                         Name      Status  Availability
87pn3pug404xs4x86b5nwlwbr  node-1    READY   ACTIVE
by2ihzjyg9m674j3cjdit3reo  node-2    READY   ACTIVE
87pn3pug404xs4x86b5nwlwbr  node-3    READY   ACTIVE

```

**Create and manage a service**

Start a 'redis' service:
```
$ swarmctl service create --name redis --image redis
```

List the running services:

```
$ swarmctl service ls
ID                         Name   Image  Instances
--                         ----   -----  ---------
enf3gkwlnmasgurdyebp555ja  redis  redis  1
```

Inspect the service:

```
$ swarmctl service inspect redis
ID                : enf3gkwlnmasgurdyebp555ja
Name              : redis
Instances         : 1
Template
 Container
  Image           : redis

Task ID                      Service    Instance    Image    Desired State    Last State              Node
-------                      -------    --------    -----    -------------    ----------              ----
8oobrcr5u9lofmcbg7goaluyw    redis      1           redis    RUNNING          RUNNING 1 minute ago    node-1
```

Now change the instance count:

```
$ swarmctl service update redis --instances 4
enf3gkwlnmasgurdyebp555ja
$
$ swarmctl service inspect redis
ID                : enf3gkwlnmasgurdyebp555ja
Name              : redis
Instances         : 4
Template
 Container
  Image           : redis

Task ID                      Service    Instance    Image    Desired State    Last State               Node
-------                      -------    --------    -----    -------------    ----------               ----
8oobrcr5u9lofmcbg7goaluyw    redis      1           redis    RUNNING          RUNNING 2 minutes ago    node-1
cdv2oca2zc5upft24494orn1v    redis      2           redis    RUNNING          RUNNING 6 seconds ago    node-2
0x7e6a1d74nrwgcbbk9c12cqo    redis      3           redis    RUNNING          RUNNING 6 seconds ago    node-2
1c8zxfj0eifhbdxrgforqz4dp    redis      4           redis    RUNNING          RUNNING 6 seconds ago    node-1
```


## Starting a cluster with Compose

You can use the included `docker-compose.yml` to start a cluster as a set of containers for testing purposes:

    $ docker-compose up -d
    [...build output...]
    Creating swarmv2_manager_1
    Creating swarmv2_agent_1

    $ docker-compose scale agent=4
    Creating and starting swarmv2_agent_2 ... done
    Creating and starting swarmv2_agent_3 ... done
    Creating and starting swarmv2_agent_4 ... done

    $ docker-compose ps
          Name                    Command              State              Ports
    ---------------------------------------------------------------------------------------
    swarmv2_agent_1     swarmd agent -m manager:4242   Up
    swarmv2_agent_2     swarmd agent -m manager:4242   Up
    swarmv2_agent_3     swarmd agent -m manager:4242   Up
    swarmv2_agent_4     swarmd agent -m manager:4242   Up
    swarmv2_manager_1   swarmd manager                 Up      192.168.64.24:4242->4242/tcp

    $ alias swarmctl='docker-compose run agent swarmctl -a manager:4242'

    $ swarmctl node ls
    ID                         Name    Status  Availability
    --                         ----    ------  ------------
    3y773r5as4ritj55ckqg12l7l  docker  READY   ACTIVE
    5w2i03cyyhv7hsd2roysnssyu  docker  READY   ACTIVE
    6j9lfh33mruhyrjq58bbv2fyh  docker  READY   ACTIVE
    81hneegzxp7o0ghs5851pxclk  docker  READY   ACTIVE

    $ swarmctl service create -f examples/service/ping.yml
    5an56xpuich7uxqf2y73mpbgq

    $ swarmctl task ls
    ID                         Service  Status   Node
    --                         -------  ------   ----
    7cwxbnaw7voxoepd8ezycuk03  ping     RUNNING  docker
    dmldn80vuosfqaju3dkap2x8p  ping     RUNNING  docker

    $ docker-compose down
    [containers and network are removed]
