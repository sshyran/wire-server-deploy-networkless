
## On a machine A

* with internet
* with make, docker, curl etc

Fetch dependencies from the internet, build a docker image, and create `admin.tar.gz`

```
make warmup
```

(Optional: push image and resulting zip file)

```
# requires quay.io and AWS credentials
make push
```

### download

Everything

```
# ~800 MB
curl -sSL https://s3-eu-west-1.amazonaws.com/public.wire.com/networkless/admin.tar.gz > admin.tar.gz
```

Only the docker image

```
docker pull quay.io/wire/networkless-admin
docker save quay.io/wire/networkless-admin > networkless-admin.tar
```

## On a machine B

* without internet
* with the `tar` command and the `docker` command/daemon installed.

1. Transfer `admin.tar.gz` to this machine
2. `tar -xvf admin.tar.gz`
3. load docker image:

```
# cd /path/to/extracted-contents

docker load < networkless-admin.tar

# cd to a fresh, empty directory
mkdir -p ../admin_work_dir && cd ../admin_work_dir
mkdir -p ../dot_ssh
mkdir -p ../dot_kube
# copy ssh key
cp ~/.ssh/id_rsa ../dot_ssh/

docker run -it --network=host -v $(pwd):/mnt -v $(pwd)/../dot_ssh:/root/.ssh -v $(pwd)/../dot_kube:/root/.kube quay.io/wire/networkless-admin
# inside the container:
cp -a /src/* /mnt
# run ansible from here. If you make any changes, they will be written to your host file system
# (those files will be owned by root as docker runs as root)
cd /mnt/wire-server-deploy/ansible
```

Any changes inside the container under `/mnt` (host system: `admin_work_dir`) and `/root/.ssh` (host system: `~/.ssh/ssh-for-docker`) will persist (albeit as user `root`), everything else will not, so be careful when creating other files.

On subsequent times:

```
cd admin_work_dir
docker run -it --network=host -v $(pwd):/mnt -v $(pwd)/../dot_ssh:/root/.ssh -v $(pwd)/../dot_kube:/root/.kube quay.io/wire/networkless-admin
# do work.
```

To connect to a running container for a second shell:

```
docker exec -it `docker ps -q --filter="ancestor=quay.io/wire/networkless-admin"` /bin/bash
```
