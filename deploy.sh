#!/bin/bash
clear

SUBSCRIPTION='929097d0-4c3c-47d7-b59e-e5e609f1d71f'
LOCATION='westeurope'
RESET='false'

usage() { 
	echo "Usage: $0"
	echo "======================================================================================"
	echo " -s [OPTIONAL]	The target subscription id"
	echo " -l [OPTIONAL]	The target location"
	echo " -n [REQUIRED] 	The name of the server"
	echo " -u [REQUIRED] 	The admin username"
	echo " -p [REQUIRED] 	The admin password"
	echo " -w [REQUIRED] 	The world seed"
	echo " -r [FLAG] 	Reset (delete) the server"
	exit 1; 
}

# SAMPLES
# ===============================================================================================
# ./deploy.sh -n Savannah -u godfather -p T00ManySecrets -w '-2043930859508072149' -r

while getopts 's:l:n:u:p:w:r' OPT; do
    case "$OPT" in
		s)
			SUBSCRIPTION="${OPTARG}" ;;
		l)
			LOCATION="${OPTARG}" ;;
		n)
			NAME="${OPTARG}" ;;
		u)
			USERNAME="${OPTARG}" ;;
        p) 
			PASSWORD="${OPTARG}" ;;
        w) 
			WORLDSEED="${OPTARG}" ;;
		r) 
			RESET='true' ;;
		*) 
			usage ;;
    esac
done

RESOURCEGROUP="minecraft-$(echo $NAME | tr '[:upper:]' '[:lower:]')"

az account set --subscription $SUBSCRIPTION

[ "$RESET" == 'true' ] && [ "$(az group exists --resource-group $RESOURCEGROUP)" == 'true' ] \
	&& echo "Deleting resource group: $RESOURCEGROUP" \
	&& az group delete \
		--resource-group $RESOURCEGROUP \
		--force-deletion-types Microsoft.Compute/virtualMachines \
		--yes \
		-o none

[ "$(az group exists --resource-group $RESOURCEGROUP)" == 'false' ] \
	&& echo "Creating resource group: $RESOURCEGROUP" \
	&& az group create \
		--resource-group $RESOURCEGROUP \
		--location $LOCATION \
		-o none

echo "Deploying to resource group: $RESOURCEGROUP" \
	&& az deployment group create \
		--name $(uuidgen) \
		--resource-group $RESOURCEGROUP \
		--template-file ./resources/main.bicep \
		--parameters \
			ServerName=$NAME \
			AdminUsername=$USERNAME \
			AdminPassword=$PASSWORD \
			WorldSeed=$WORLDSEED \
		--query 'properties.outputs.sshCommand.value'
