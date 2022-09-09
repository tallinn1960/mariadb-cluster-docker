# mariadb-cluster-docker
Run a mariadb galera cluster with three nodes 

## Setup
The cluster is composed of three database services _mariadb_server_1_, _mariadb_server_2_ and _mariadb_server_3_,
and an _phpmyadmin_ service. The database services use volumes named as the service they are bound to for all 
database related data. They are connected to each other by an docker network _db_network_. The database services expose
the following ports to the host:

* 3306 _mariadb_server_1_
* 3307 _mariadb_server_2_
* 3308 _mariadb_server_3_
* 50080 _phpmyadmin_

The root account and password is _root/rootpass_.
### Bootstrapping the cluster
A new galera cluster needs to be bootstrapped. For that purpose run
```
docker compose -f docker-compose.yml -f bootstrap1.yaml up -d
```
This will boot all services with _mariadb-server-1_ as the bootstrap node. As this node cannot be restarted 
the same way, once all containers are up and running, redeploy _mariadb-server-1_ as a standard node
with
```
docker compose up -d mariadb-server-1
```
## Managing the cluster
### Shutting down and restarting a galera node
Each individual service may be stopped by 
```
docker compose stop <servicename>
```
and restarted deliberately by
```
docker compose up <servicename>
```
Just note that _phpmyadmin_ connects to _mariadb-server-1_ only, so do not expect _phpmyadmin_ being operational
with _mariadb-server-1_ down. Once that node is restarted, _phpmyadmin_ will reconnect.
### Shutting down and restarting two data nodes
As a galera cluster decides quorum-based for the most advanced data node to synchronize
with, stopping two nodes and restarting them requires care: restart one node and
wait for this node to catch up with the unstopped node, then start the other node. This will 
ensure that each returning node is in sync with the unstopped node.
### Stopping and restarting all nodes
In short: avoid doing this as recovery from that is work. With all nodes gone the cluster's life has come to
an end, and you need to create a new one. However, for not loosing any data you first have
to identify which was the last node turned off. If that node is unknown or just uncertain (which is the case when
the whole cluster has been stopped by _docker compose stop_), determine that last node off by running:
```
docker compose -f docker-compose.yml -f recovery.yaml up | grep "Recovered position"
```
This will give you an output like this:
```
mariadb-server-1: [Note] WSREP: Recovered position: ...:1122
mariadb-server-2: [Note] WSREP: Recovered position: ...:1127
mariadb-server-3: [Note] WSREP: Recovered position: ...:1124
```
not necessarily with the nodes reporting in that order. Note the numbers at the end of 
the lines, those are sequence numbers. The node with the highest sequence number needs to
be started as the bootstrap node for a new cluster. In the example given this is 
_mariadb-server-2_, so let's do what we did to bootstrap the cluster, but this time with
_mariadb-server-2_ as the bootstrap node:
```
docker compose -f docker-compose.yml -f bootstrap2.yaml up -d
```
Again, once all nodes are up and running, restart the bootstrap node in normal mode:
```
docker compose up -d
```
I warned you.
### Crash recovery
This is almost similar to stopping and restarting all nodes, but with nodes shutdown 
non gracefully you need to check and modify state data in the identified bootstrap 
node with the most advanced recovered position. Before bootstrapping the cluster with 
that node, you need to enable it to boostrap by running, 
```
docker compose run <bootstrapnodename> sed -i -e's/safe_to_bootstrap: 0/safe_to_bootstrap: 1/' /var/lib/mysql/grastate.dat
```
with the service name of the bootstrap node used in place of `<bootstrapname>`.
Then bootstrap the cluster and switch all nodes to normal mode after that.
## Adding nodes
You can add nodes to the cluster utilizing any service definition of a database cluster node from _docker-compose.yml_
as a template. Requirements are:
- a distinguished service name,
- a distinguished port mapping for the container port 3306,
- a distinguished _bootstrap.yml_ file for that node to be started as a bootstrap node
- a distinguished volume for _/var/lib/mysql_ (**double check that!**), do not forget to add
that volume to the list of volumes in _docker-compose.yml_,
- a distinguished node name passed in _command_ to _mysqld_ by -_-wsrep-node-name_ (**important!**),
- adding that node name to the list of nodes in _my.cnf_

Be aware that a working galera cluster needs an odd number of nodes to avoid split-brain
situations. If you add nodes, please keep the number of nodes odd.

Once you're done with editing the config files, add the nodes to the cluster one at a time 
with
```
docker compose up -d <servicesname1> <servicesname2> ...
```
with your new node service names replacing the placeholders.

## Caveats
Don't do 
```
docker compose restart
```
This will kill the cluster but skips the bootstrap step for a new one. You will end up with data nodes
endlessly trying to raise from the dead. Stop all nodes and bootstrap a new cluster on the most advanced 
data node.

Don't share volumes for _/var/lib/mysql_ between services. This is a nothing-shared cluster!

## Acknowledgements
This work is based on https://github.com/habibiefaried/mysql-ndb.git, who gives a docker
setup for MySQL NDB Cluster. Thank you.