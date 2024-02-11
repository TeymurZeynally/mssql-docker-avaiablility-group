This repository contains a script to deploy a SQL Server Always On availability group with Docker containers. The script automates the setup process by pulling the SQL Server Docker image, creating a Docker network, deploying multiple SQL Server containers, enabling Always On availability groups, generating certificates, creating an availability group, and joining secondary replicas.

## Prerequisites

Before running the script, ensure you have the following:

- Docker installed on your system.
- Basic understanding of Docker and SQL Server.

## Configuration

Before running the script, you need to configure the following variables in the script:

- `PASSWORD`: Set your SQL Server SA password.
- `ENCRYPTION_PASSWORD`: Set your encryption password.
- `NODE_LOGIN_PASSWORD`: Set your node login password.
- `CONTAINER_PREFIX`: Prefix for container names.
- `NETWORK`: Name of the Docker network.
- `AGROUP_NAME`: Name of the availability group.
- `DATABASE_NAME`: Name of the database.
- `DELAY`: Time delay for SQL Server instances to start/restart.
- `NODE_COUNT`: Number of SQL Server nodes in the availability group.

## Usage

1. Clone this repository to your local machine.
2. Navigate to the repository directory.
3. Configure the variables in the script according to your environment.
4. Run the script using the following command:

    ```
    bash deploy-msssql-ag.sh
    ```

## Notes

- The script will pull the SQL Server Docker image, create a Docker network, deploy SQL Server containers, enable Always On availability groups, generate certificates, create an availability group, join secondary replicas, and create a database.
- Make sure to review the script and adjust the configurations as per your requirements before running it.
- It's recommended to run the script on a clean environment or ensure that existing containers or networks do not conflict with the configurations.
- After running the script, you should have a SQL Server Always On availability group setup with the specified configuration.

## Disclaimer

This script is provided as-is without any warranty. Use it at your own risk. Make sure to test it in a development environment before deploying it to production.
