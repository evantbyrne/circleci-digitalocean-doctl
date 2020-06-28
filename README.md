# CircleCI and DigitalOcean: Automated Deployments

An example of using CircleCI to automate server deployments to DigitalOcean.

## Deploy Script

Positional arguments:

Name | Default | Description
--- | --- | ---
build_branch | _required_ | Deployment branch. Supplied by `$CIRCLE_BRANCH` on CircleCI.
build_number | _required_ | Droplet tag. Supplied by `$CIRCLE_BUILD_NUM` on CircleCI.
do_image | _required_ | Droplet image. Supplied by `$DO_IMAGE` on CircleCI.
do_region | nyc1 | Droplet region. Supplied by `$DO_REGION` on CircleCI.
do_size | s-1vcpu-1gb | Droplet size. Supplied by `$DO_SIZE` on CircleCI.
do_count | 1 | Number of droplets to create. Supplied by `$DO_COUNT` on CircleCI.

Usage:

```
./bin/deploy.sh dev manual-1 12345678 nyc1 s-1vcpu-1gb 2
```

Behavior:

1. Check for load balancer with name `load-balancer-$build_branch`, skip deployment if it does not exist.
2. Old droplets are identified if their name matches `nginx-$build_branch`.
3. Create droplet(s) with given parameters, upload files in `public` directory, add to load balancer.
4. Delete old droplet(s).

## CircleCI Environment Variables

All of the following are required for deployments to run on CircleCI:

Name | Description
--- | ---
`DO_ACCESS_TOKEN` | DigitalOcean security access token.
`DO_COUNT` | Number of DigitalOcean droplets to create.
`DO_IMAGE` | ID of a DigitalOcean droplet image.
`DO_REGION` | Slug of DigitalOcean region.
`DO_SIZE` | Slug of DigitalOcean droplet size.
