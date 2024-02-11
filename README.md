This script sets up a SQL Server Always On Availability Group using Docker containers. It performs the following steps:

- Defines variables such as passwords, network details, database name, delay, and node count.
- Pulls the SQL Server Docker image.
- Removes existing containers and networks if they exist.
- Creates a Docker network.
- Deploys SQL Server containers for the specified number of nodes.
- Enables Always On availability groups and restarts SQL Server containers.
- Generates certificates for each node and copies them to other nodes.
- Grants connection permissions between nodes.
- Creates an availability group and joins secondary replicas to it.
- Creates a database, sets recovery mode, performs a backup, and adds it to the availability group.
