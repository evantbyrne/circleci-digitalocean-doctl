#!/bin/bash

# Exit immediately if any command fails.
set -e
set -o pipefail

# Positional arguments.
build_branch=${1}          # Deployment branch. Supplied by `$CIRCLE_BRANCH`.
build_number=${2}          # Droplet tag. Supplied by `$CIRCLE_BUILD_NUM`.
do_image=${3}              # Droplet image. Supplied by `$DO_IMAGE`.
do_region=${4:-nyc1}       # Droplet region. Supplied by `$DO_REGION`.
do_size=${5:-s-1vcpu-1gb}  # Droplet size. Supplied by `$DO_SIZE`.
do_count=${6:-1}           # Number of droplets to create. Supplied by `$DO_COUNT`.

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

# Finding old droplets.
doctl compute droplet list --output json > tmp/list.json
droplet_old_ids=$(cat tmp/list.json | jq "map(select(.name == \"nginx-$build_branch\").id) | join(\",\")" --raw-output)
echo "Found old droplets: $droplet_old_ids"

# Get SSH keys.
droplet_keys=$(doctl compute ssh-key list --output json | jq "map(.id) | join(\",\")")
droplet_name="nginx-$build_branch"
load_balancer_id=$(cat tmp/load-balancer.json | jq "map(select(.name == \"load-balancer-$build_branch\")) | .[0].id" --raw-output)

# Create droplets.
for ((i=1; i <= $do_count; i++)); do
  echo "Create droplet #$i {image:$do_image name:$droplet_name region:$do_region size:$do_size}"
  doctl compute droplet create $droplet_name --image $do_image --ssh-keys $droplet_keys --region $do_region --size $do_size --tag-names "nginx,$build_number" --output json --wait > tmp/create.json
  droplet_ip=$(cat tmp/create.json | jq ".[0].networks.v4[0].ip_address" --raw-output)

  # Wait for SSH connection.
  echo "Wait for SSH..."
  for j in {1..5}; do ssh -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null "root@$droplet_ip" "whoami" && break || sleep 2; done

  # Copy files to droplet.
  echo "Upload static files..."
  scp -q -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null public/* $(echo "root@$droplet_ip:/var/www/html")

  # Add new droplet to load balancer.
  droplet_new_id=$(cat tmp/create.json | jq ".[0].id")

  echo "Add droplet #$i to load balancer {droplet_id:$droplet_new_id load_balancer_id:$load_balancer_id}"
  doctl compute load-balancer add-droplets $load_balancer_id --droplet-ids $droplet_new_id
done

# Delete old droplets.
if [ "$droplet_old_ids" != "" ]; then
  echo "Remove droplets from load balancer {droplet_ids:$droplet_old_ids load_balancer_id:$load_balancer_id}"
  doctl compute load-balancer remove-droplets $load_balancer_id --droplet-ids $droplet_old_ids
  echo "Delete droplets {id:$droplet_old_ids}"
  doctl compute droplet delete $droplet_old_ids -f --output json > tmp/delete.json
fi
