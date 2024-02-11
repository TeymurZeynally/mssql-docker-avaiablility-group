# Define variables
PASSWORD='YourStrong!Passw0rd'
ENCRYPTION_PASSWORD='<YourEncryptionPassword>'
NODE_LOGIN_PASSWORD='<EncryptionPassword>'
NETWORK='your_docker_network'
DATABASE_NAME='your_database_name'
DELAY=10
NODE_COUNT=3

# Pull the SQL Server Docker image
docker pull mcr.microsoft.com/mssql/server:2019-latest

# Remove existing containers if they exist
EXISTING_CONTAINERS=$(docker ps -a --filter name=sqlserver-node --format "{{.Names}}")
if [ "$EXISTING_CONTAINERS" != "" ]; then
	docker rm -f $(docker ps -a --filter "name=^/sqlserver-node" -q)
fi

# Remove the existing network if it exists
EXISTING_NETWORK=$(docker network ls --filter name=$NETWORK --format="{{ .Name }}")
if [ "$EXISTING_NETWORK" != "" ]; then
    echo "Removing existing network: $NETWORK"
    docker network rm $NETWORK
fi

# Create Docker network
echo "Creating network: $NETWORK"
docker network create $NETWORK

# Deploy SQL Server containers
for ((node=1; node<=$NODE_COUNT; node++)); do
    docker run -e 'ACCEPT_EULA=Y' -e "SA_PASSWORD=$PASSWORD" \
        --name sqlserver-node$node \
        --hostname sqlserver-node$node \
        --network $NETWORK \
        -p $((14430 + node)):1433 \
        -d mcr.microsoft.com/mssql/server:2019-latest
done

# Wait for SQL Server instances to start
sleep $DELAY

# Enable Always On availability groups
for ((node=1; node<=$NODE_COUNT; node++)); do
    docker exec -u 0 -it sqlserver-node$node /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
done

# Restart SQL Server containers
echo "Restarting SQL Server containers..."
for ((node=1; node<=$NODE_COUNT; node++)); do
    docker restart sqlserver-node$node
done

# Wait for SQL Server instances to restart
sleep $DELAY

# Enable Always On availability groups and generate certificates
for ((node=1; node<=$NODE_COUNT; node++)); do
    CERT_NAME="LinAGN${node}_Cert"
    docker exec -u 0 -it sqlserver-node$node bash -c "
        /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P '$PASSWORD' -Q \"
        CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$ENCRYPTION_PASSWORD';
        CREATE CERTIFICATE $CERT_NAME WITH SUBJECT = 'LinAGN${node} AG Certificate';
        BACKUP CERTIFICATE $CERT_NAME TO FILE = '/var/opt/mssql/data/$CERT_NAME.cer';
        CREATE ENDPOINT AGEP STATE = STARTED AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL) FOR DATABASE_MIRRORING(AUTHENTICATION = CERTIFICATE $CERT_NAME, ROLE = ALL);
        \"
    "

    # Copy certificate file to host machine
    docker cp sqlserver-node$node:/var/opt/mssql/data/$CERT_NAME.cer /tmp/$CERT_NAME.cer
    chmod 777 /tmp/$CERT_NAME.cer
done

# Copy certificate files from host to other nodes
for ((node=1; node<=$NODE_COUNT; node++)); do
    CERT_NAME="LinAGN${node}_Cert"
    for ((other_node=1; other_node<=$NODE_COUNT; other_node++)); do
        if [ "$other_node" != "$node" ]; then
            docker cp /tmp/$CERT_NAME.cer sqlserver-node$other_node:/var/opt/mssql/data/$CERT_NAME.cer
        fi
    done
done

# Grant connection
for ((node=1; node<=$NODE_COUNT; node++)); do
    # Execute additional SQL commands
    for ((other_node=1; other_node<=$NODE_COUNT; other_node++)); do
        if [ "$other_node" != "$node" ]; then
            OTHER_CERT_NAME="LinAGN${other_node}_Cert"
            docker exec -u 0 -it sqlserver-node$node bash -c "
                /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P '$PASSWORD' -Q \"
                CREATE LOGIN LinAGN${other_node}_Login WITH PASSWORD = '$NODE_LOGIN_PASSWORD';
                CREATE USER LinAGN${other_node}_User FOR LOGIN LinAGN${other_node}_Login;
                CREATE CERTIFICATE $OTHER_CERT_NAME AUTHORIZATION LinAGN${other_node}_User FROM FILE = '/var/opt/mssql/data/$OTHER_CERT_NAME.cer';
                GRANT CONNECT ON ENDPOINT::AGEP TO LinAGN${other_node}_Login;
                \"
            "
        fi
    done
done

# Create availability group
AVAILABILITY_GROUP_QUERY="CREATE AVAILABILITY GROUP $AGROUP_NAME WITH (CLUSTER_TYPE = NONE) FOR REPLICA ON "
for ((node=1; node<=$NODE_COUNT; node++)); do
    AVAILABILITY_GROUP_QUERY+=" 'sqlserver-node$node' WITH (
        ENDPOINT_URL = 'TCP://sqlserver-node$node:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    )"
    if [ $node -lt $NODE_COUNT ]; then
        AVAILABILITY_GROUP_QUERY+=","
    fi
done

docker exec -it sqlserver-node1 /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $PASSWORD -Q "
$AVAILABILITY_GROUP_QUERY;

ALTER AVAILABILITY GROUP $AGROUP_NAME GRANT CREATE ANY DATABASE;
"

# Join secondary replicas to the availability group
for ((node=2; node<=$NODE_COUNT; node++)); do
    docker exec -it sqlserver-node$node /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $PASSWORD -Q "
    ALTER AVAILABILITY GROUP $AGROUP_NAME JOIN WITH (CLUSTER_TYPE = NONE);
    ALTER AVAILABILITY GROUP $AGROUP_NAME GRANT CREATE ANY DATABASE;
    "
done

# Create database
docker exec -it sqlserver-node1 /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P $PASSWORD -Q "
    CREATE DATABASE $DATABASE_NAME;
    ALTER DATABASE $DATABASE_NAME SET RECOVERY FULL;
    BACKUP DATABASE $DATABASE_NAME TO DISK='/var/opt/mssql/data/$DATABASE_NAME.bak';

    ALTER AVAILABILITY GROUP $AGROUP_NAME ADD DATABASE $DATABASE_NAME;
    "
