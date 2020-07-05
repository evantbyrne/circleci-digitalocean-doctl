# CircleCI and DigitalOcean: Automated Deployments

An example of using CircleCI to automate server deployments to DigitalOcean.

Features:

- Deploy on commit.
- Optional branch environments.
- One-line manual deployments.
- Horizontally or vertically scale instances.

## Deploy Script

Dependencies:

Name | Version
--- | ---
[doctl](https://github.com/digitalocean/doctl) | v1.45+
[jq](https://github.com/stedolan/jq) | v1.6+

Positional arguments:

Name | Default | Description
--- | --- | ---
build_branch | _required_ | Deployment branch. Supplied by `$CIRCLE_BRANCH` on CircleCI.
build_number | _required_ | Droplet tag. Supplied by `$CIRCLE_BUILD_NUM` on CircleCI.
do_image | _required_ | Droplet image ID. May be a snapshot. Supplied by `$DO_IMAGE` on CircleCI.
do_region | nyc1 | Droplet region. Supplied by `$DO_REGION` on CircleCI.
do_size | s-1vcpu-1gb | Droplet size. Supplied by `$DO_SIZE` on CircleCI.
do_count | 1 | Number of droplets to create. Max of 8. Supplied by `$DO_COUNT` on CircleCI.

Usage (from project root directory):

```
./bin/deploy.sh dev manual-1 12345678 nyc1 s-1vcpu-1gb 2
```

Behavior:

1. Check for load balancer with name `load-balancer-$build_branch`, skip deployment if it does not exist. Only port 80 needs to be forwarded for this simple test application.
2. Old droplets are identified if their name matches `nginx-$build_branch`.
3. Create droplet(s) with given parameters, upload files in `public` directory, add to load balancer.
4. Delete old droplet(s).

## CircleCI Environment Variables

All of the following are required for deployments to run on CircleCI:

Name | Description
--- | ---
`DO_ACCESS_TOKEN` | DigitalOcean security access token.
`DO_COUNT` | Number of DigitalOcean droplets to create. Max of 8.
`DO_IMAGE` | ID of a DigitalOcean droplet image. May be a snapshot.
`DO_REGION` | Slug of DigitalOcean region.
`DO_SIZE` | Slug of DigitalOcean droplet size.
