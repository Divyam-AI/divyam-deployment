#!/bin/bash

# List of Azure providers to register
providers=(
  Microsoft.ApiManagement
  Microsoft.AppConfiguration
  Microsoft.AppPlatform
  Microsoft.AVS
  Microsoft.Cache
  Microsoft.Cdn
  Microsoft.Compute
  Microsoft.CustomProviders
  Microsoft.Databricks
  Microsoft.DataFactory
  Microsoft.DataLakeAnalytics
  Microsoft.DataLakeStore
  Microsoft.DataProtection
  Microsoft.DBforMariaDB
  Microsoft.DBforMySQL
  Microsoft.Devices
  Microsoft.DevTestLab
  Microsoft.DocumentDB
  Microsoft.EventGrid
  Microsoft.Kusto
  Microsoft.Logic
  Microsoft.ManagedServices
  Microsoft.MixedReality
  Microsoft.NotificationHubs
  Microsoft.OperationsManagement
  Microsoft.PowerBIDedicated
  Microsoft.RecoveryServices
  Microsoft.Relay
  Microsoft.Search
  Microsoft.SecurityInsights
  Microsoft.ServiceBus
  Microsoft.SignalRService
  Microsoft.StreamAnalytics
  Microsoft.Web
)

echo "Starting Azure provider registration..."

for provider in "${providers[@]}"; do
  echo "Registering $provider..."
  az provider register --namespace "$provider"
done

echo "Waiting for provider registration to complete..."

for provider in "${providers[@]}"; do
  echo -n "Checking $provider..."
  while true; do
    status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
    echo -n "."
    if [[ "$status" == "Registered" ]]; then
      echo " done"
      break
    fi
    sleep 2
  done
done

echo "All specified providers are registered."
