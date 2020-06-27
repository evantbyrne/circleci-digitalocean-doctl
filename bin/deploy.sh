#!/bin/bash

# Exit immediately if any command fails.
set -e
set -o pipefail

# Positional arguments.
build_branch=${1}          # Supplied by `$CIRCLE_BRANCH`.
build_number=${2}          # Supplied by `$CIRCLE_BUILD_NUM`.
do_image=${3}              # Supplied by `$DO_IMAGE`.
do_region=${4:-nyc1}       # Supplied by `$DO_REGION`.
do_size=${5:-s-1vcpu-1gb}  # Supplied by `$DO_SIZE`.

if [ "$build_branch" = "" ]; then
  echo "Error: Missing positional argument 'build_branch'."
  exit 1
fi

if [ "$build_number" = "" ]; then
  echo "Error: Missing positional argument 'build_number'."
  exit 1
fi

if [ "$do_image" = "" ]; then
  echo "Error: Missing positional argument 'do_image'."
  exit 1
fi

# Exit here if the load balancer does not exist.
doctl compute load-balancer list --output json > tmp/load-balancer.json
load_balancer_count=$(cat tmp/load-balancer.json | jq "map(select(.name == \"load-balancer-$build_branch\")) | length")
if [ $load_balancer_count -ne 1 ]; then
  echo "Error: Load balancer with name 'load-balancer-$build_branch' not found."
  exit 1
fi

# Create droplet.
droplet_keys=$(doctl compute ssh-key list --output json | jq "map(.id) | join(\",\")")
droplet_name="nginx-$build_branch"
echo "Create droplet {image:$do_image name:$droplet_name region:$do_region size:$do_size}"
doctl compute droplet create $droplet_name --image $do_image --ssh-keys $droplet_keys --region $do_region --size $do_size --tag-names "nginx,$build_number" --output json --wait > tmp/create.json
droplet_ip=$(cat tmp/create.json | jq ".[0].networks.v4[0].ip_address" --raw-output)

# Wait for SSH connection.
echo "Wait for SSH..."
for i in {1..5}; do ssh -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null "root@$droplet_ip" "whoami" && break || sleep 5; done

# Copy files to droplet.
echo "Upload static files..."
scp -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null public/* $(echo "root@$droplet_ip:/var/www/html")

# Add new droplet to load balancer.
doctl compute droplet list --output json > tmp/list.json
droplet_count=$(cat tmp/list.json | jq "map(select(.name == \"nginx-$build_branch\")) | length")
droplet_new_id=$(cat tmp/create.json | jq ".[0].id")
load_balancer_id=$(cat tmp/load-balancer.json | jq "map(select(.name == \"load-balancer-$build_branch\")) | .[0].id" --raw-output)
echo "Add droplet to load balancer {droplet_id:$droplet_new_id load_balancer_id:$load_balancer_id}"
doctl compute load-balancer add-droplets $load_balancer_id --droplet-ids $droplet_new_id

# Delete old droplet.
if [ $droplet_count -gt 1 ]; then
  droplet_old_id=$(cat tmp/list.json | jq "map(select(.name == \"nginx-$build_branch\")) | sort_by(\".id\") | .[0].id")
  echo "Remove droplet to load balancer {droplet_id:$droplet_old_id load_balancer_id:$load_balancer_id}"
  doctl compute load-balancer remove-droplets $load_balancer_id --droplet-ids $droplet_old_id
  echo "Delete droplet {id:$droplet_old_id}"
  doctl compute droplet delete $droplet_old_id -f --output json > tmp/delete.json
fi
