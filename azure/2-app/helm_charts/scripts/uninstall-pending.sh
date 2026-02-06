#!/bin/bash

# This script lists and uninstalls Helm releases that are in a 'pending-install' status.
# Use with caution, as uninstalling releases can lead to data loss or service disruption.

echo "🔍 Searching for Helm releases in 'pending-install' status across all namespaces..."

# Get all releases in 'pending-install' status across all namespaces
# The 'helm list' command with --pending and --all-namespaces flags will show releases
# that are in any pending state (pending-install, pending-upgrade, pending-rollback).
# We then use 'grep' to specifically filter for 'pending-install'.
# 'awk' is used to extract the release name (column 1) and namespace (column 2).
# The output is stored in an array called 'pending_releases'.
readarray -t pending_releases < <(helm list --all-namespaces --pending | grep "pending-install" | awk '{print $1 " " $2}')

# Check if any pending-install releases were found
if [ ${#pending_releases[@]} -eq 0 ]; then
  echo "✅ No Helm releases found in 'pending-install' status."
else
  echo "❗ Found the following Helm releases in 'pending-install' status:"
  echo "----------------------------------------------------------------"
  printf "%-30s %s\n" "RELEASE NAME" "NAMESPACE"
  echo "----------------------------------------------------------------"
  for release_info in "${pending_releases[@]}"; do
    # Split release_info into name and namespace
    release_name=$(echo "$release_info" | awk '{print $1}')
    release_namespace=$(echo "$release_info" | awk '{print $2}')
    printf "%-30s %s\n" "$release_name" "$release_namespace"
  done
  echo "----------------------------------------------------------------"

  # Ask for user confirmation before proceeding with uninstallation
  read -p "Do you want to uninstall these releases? (yes/no): " confirmation

  if [[ "$confirmation" == "yes" ]]; then
    echo "🚀 Proceeding with uninstallation..."
    for release_info in "${pending_releases[@]}"; do
      release_name=$(echo "$release_info" | awk '{print $1}')
      release_namespace=$(echo "$release_info" | awk '{print $2}')
      echo "Attempting to uninstall release '$release_name' in namespace '$release_namespace'..."
      # Execute the helm uninstall command
      # --no-hooks: Prevents pre-delete/post-delete hooks from running, which can sometimes be stuck.
      # --timeout 5m0s: Sets a timeout for the uninstall operation. Adjust as needed.
      helm uninstall "$release_name" --namespace "$release_namespace" --no-hooks --timeout 5m0s
      if [ $? -eq 0 ]; then
        echo "Successfully uninstalled '$release_name'."
      else
        echo "Failed to uninstall '$release_name'. Please check logs for details."
      fi
      echo "" # Add a newline for better readability between uninstallations
    done
    echo "🎉 Uninstallation process completed."
  else
    echo "🚫 Uninstallation cancelled by user."
  fi
fi

echo "Script finished."