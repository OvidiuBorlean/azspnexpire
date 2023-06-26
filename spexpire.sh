#! /bin/bash
#   Script to check AKS Cluster SPN and report the remaining days
#   for the SPN credentials to expire.
#
#   Authors:  Mohammed Abu-Taleb
#   Date        : 2019-12-07
#   Version     : 1.0

#NOTE: For this to work, you should be logged in with a global administrator in AzureCLI.

#Usage message
usage()
{
   echo "Options:"
   echo " -s      AKS Subscription ID"
   echo " -g      AKS Resource Group"
   echo " -n      AKS Cluster Name"
   echo " -h      Shows this help menue"
   echo " "
   echo "Example: $0 -s <AKS_SUBSCRIPTION_ID> -g <AKS_ResourceGroup> -n <AKS_Resource_Name>"
}

while getopts ":g:s:n:h" option; do
  case $option in
    g ) RG=$OPTARG
    ;;
    s ) AKSSUBSCRIPTIONID=$OPTARG
    ;;
    n ) AKSRESOURCEID=$OPTARG
    ;;
    h ) usage
    exit 0
    ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      usage
      exit 1
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done

if [ "$#" -ne 6 ]
then
  echo "Invalid options"
  echo "Try $0 -h"
  usage
  exit 1
fi

#Switch AZ directory to AKS subscription.
az account set -s "$AKSSUBSCRIPTIONID"

#Get the SPN Associated with the AKS Cluster
CLIENTID=$(az aks show --resource-group "$RG" --name "$AKSRESOURCEID" --query servicePrincipalProfile.clientId -o tsv)
CLIENTDDISPLAY=$(az ad sp show --id "$CLIENTID" --query appDisplayName -o tsv)

echo "Your AKS cluster $AKSRESOURCEID is associated with SPN $CLIENTDDISPLAY ClientID=$CLIENTID"
echo " "

#List defined credentials for the SPN.

mapfile -t ENDDATE < <(az ad app credential list --id "$CLIENTID" -o tsv | grep -v KeyID | cut -f3 | cut -d 'T' -f 1)
mapfile -t STARTDATE < <(az ad app credential list --id "$CLIENTID" -o tsv | grep -v KeyID | cut -f7 | cut -d 'T' -f 1)
mapfile -t KEYID < <(az ad app credential list --id "$CLIENTID" -o tsv | grep -v KeyID | cut -f4 | cut -d ' ' -f 1)

echo $KEYID
echo $STARTDATE
echo $ENDDATE
COUNT=0

#Loop all credentials and devide ENDDATE from STARTDATE to find the number left for the credentials to expire.
for date in "${ENDDATE[@]}"
do
    echo "your SPN credentials with KEYID=${KEYID[$COUNT]} will expire in $(( ($(date -d "${ENDDATE[$COUNT]}" +%s) - $(date -d "${STARTDATE[$COUNT]}" +%s)) / 86400 )) days"
    COUNT=$((COUNT+1))
done