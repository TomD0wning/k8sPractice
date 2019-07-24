#!/bin/env bash

#####################################
#Script to clear a redis cache then run a full load calling our backend service
#Parameters:
#$1 = Whether an full load or update is being made
#$2 = Application ID for using a service principal when logging into azure 
#$3 = Tenant ID for using a service principal when logging into azure 
#$4 = Password for using a service principal when logging into azure 
#$5 = The url to call to either load or update redis. Note this should match the first parameter or there will be unexpected behaviour
#$6 = The username for service authentication
#$7 = the password for service authentication
#$8 = 
#####################################
set -x

#Parameters
az_subscription="75b295e5-523c-426e-bbcf-920eb6a700a9"
call_type=$1
app_id=$2 #1f9ccc20-55cb-44d0-83f7-ae538eb539d9
tentant_id=$3 #e11fd634-26b5-47f4-8b8c-908e466e9bdf 
secret=$4 #qa+P72ytm/dyJPR1CsEInqSKGQyZBhF+UgtdEC12A5s=
namespace=$5
service_user=$6 #propertyservices
service_pwd=$7 #E5g^N0vOzog%o$wU2HNn^D
api_url=$8
redis_result=""
redis_name="property-redis"

#Functions

#Clear redis cache, logging into azure and running commands against k8s
function accessAzure {
    echo "Logging into azure"
    az login --service-principal --username $app_id --password $secret --tenant $tenant_id
    # echo "switching account"
    # az account set -s az_subscription
}

function performRedisOperation {
    echo "Getting Redis pod name"
    redis_pod=`kubectl get pods -n default -o jsonpath='{.items[?(@.metadata.labels.app=="property-redis")].metadata.name}'`
    echo "Flushing data from $redis_pod"
    redis_result=`kubectl exec -it -n $namepace $redis_pod redis-cli flushall`
}

function makeServiceRequest {
    echo "Calling service -- ($1)"
    curl --user $service_user:$service_pwd $1 | echo
    # curl http://localhost:5000/investments | echo 
}

#start of script

if [ $# -ne 8 ] 
then
  echo "Clears a redis cache and makes a service call to reload or update"
  echo "Usage: $0 <CallType> <ApplicationID> <TenantID> <Secret> <Namespace> <Service User Name> <Service Password> <API URL>  "
  exit 1
fi

if [ $1 = 'load' ]
then
    performRedisOperation
    if [ `echo $redis_result | tr -d '\r'` = 'OK' ]
    then
        echo "Running full Redis Load and starting timer"
        SECONDS=0
        makeServiceRequest $api_url
        t=$SECONDS
        echo "Load completed in $(($t / 60)):$(($t % 60))"
    else
        echo "Unable to flush redis: $redis_result"
        exit 1
    fi
elif [ $1 = 'update' ]
then
    echo "Running Redis update"
    SECONDS=0
    makeServiceRequest $api_url
    t=$SECONDS
    echo "Load completed in $(($t / 60)):$(($t % 60))"
else
    echo "Incorrect load type passed. Exiting with no action"
    exit 1
fi

set +x



