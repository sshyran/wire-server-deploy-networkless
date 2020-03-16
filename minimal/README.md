Minimal offline deployment package
==================================


This folder contains logic to build a package for an opinionated air-gapped (or offline) installation
of the [wire-server](https://github.com/wireapp/wire-server). 


The package contains ...

* helm charts
* container images
* image import logic
* docs

.. and assumes

* a Kubernetes cluster up and running
* container image registry accessible from the cluster
* the registry is configured as
  [registry-mirror](https://docs.docker.com/registry/recipes/mirror/#configure-the-docker-daemon)
  for the container engine on all Kubernetes nodes

In case there is no image registry available, please refer to the description on how to start one,
provided down below.

Furthermore, depending on the type of installation the *wire-server* deployment may or may not assume
a couple of backing services. See the [installation docs](https://docs.wire.com/how-to/install/planning.html)
for more information.


## Prerequisites 

* Docker >= 18.03
* `kubectl` >= 1.14.0
* `helm` >= 3.0.0
* `bzip2`

## Using the package

0. make sure all prerequisites are met
1. unpack the whole package
2. run a script to propagate the bundled images to the hosted registry
3. run helm install/upgrade


### [optional] Start a self-hosted container image registry

The image to run the registry is bundled into this package. Run the following command to load the image into the
local image cache.

```
bzip2 --decompress --stdout ./images/docker.io+library+registry++2.tar.bz2 | docker image load
```

With that, you can start the registry container *(please refer to the [docs](https://docs.docker.com/registry/deploying/) 
for more information)*, e.g.


```
docker run \
  --detach \
  --restart=always \
  --name registry \
  --publish 5001:5001 \
  -v "$(pwd)/registry:/var/lib/registry" \
  -v "$(pwd)/certs:/certs" \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5001 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/client.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/client.key \
  registry:2
```

*NOTE: the example also sets some TLS configuration. Per default, the docker daemon doesn't allow pulling image over
plain HTTP. So, either you can
[configure the daemon to accept an "insecure" registry](https://docs.docker.com/registry/insecure/#deploy-a-plain-http-registry) 
or you
[generate a TLS key-pair and make the docker daemon on the nodes aware of that certificate](https://docs.docker.com/registry/insecure/#use-self-signed-certificates).
Either way, all Kubernetes need to be adjusted.*  


### Propagate images into the registry

```
./load-and-push-images.sh [REGISTRY_HOST]
```

Where `REGISTRY_HOST` must be a fully qualified registry name (IP, hostname, FQDN, and optionally port) in the format 
of *name[:port]*

The script, then, basically executes 4 steps on every archived image in `./images`:

1. unpack (bzip2)
2. load it into the local image cache
3. tag the image
4. push the image to the registry

When being propagated, all image names are consolidated and *normalized*, in a sense that, even if they originate from
different registries - not only from the default one `[registry-1.]docker.io]` - their references don't contain the
registry name anymore. All image reference across the entire set of included helm charts have been adjusted accordingly.
But this also means, that every Helm release applied to the cluster, requires the registry, where those images were
pushed to, to be configured as a *[mirror](https://docs.docker.com/registry/recipes/mirror/#configure-the-docker-daemon)*
on each node. 


### Deploy with Helm

Depending on the installation path that has been chosen, various values or secrets would need to be configured, and
possibly multiple Helm charts have to be installed. For more details, please refer to
[documentation](https://docs.wire.com/how-to/install/helm.html). 

```
helm install --wait \
    --values ./values.yaml \
    --values ./secrets.yaml
    $RELEASE_NAME ./charts/wire-server
``` 


## Building the package

### Build logic

__Assumptions:__

* docker client CLI has configured `registry-1.docker.io` as default registry (which is always true, since it's 
hard-coded)

*Please note, the access to certain components (e.g. team-settings) might be restricted on the corresponding image
registry. In that case, to successfully build the package, either exclude those components by curating the list of helm
charts that are being bundled, or configure the container engine with the necessary credentials before starting to 
build the package.*

1. pull the whole helm chart dependency tree (e.g. `helm pull`)
2. go through the tree and find out which images are required (TODO: automate this)
3. fetch and export all images on the list (e.g. `docker image pull` and `docker image save`)
4. again, go through the tree and *normalize* all image references, since they will all be fetched later from the local
   ('offline') registry
5. if required, bundle everything together into a package and publish it to S3 under `w-wire-server-offline`
