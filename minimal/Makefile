.DEFAULT_GOAL := default
SHELL = bash
MKFILE_DIR = $(abspath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# NOTE: overriding OS-wide environment variables instead of the `HELM_` prefixed ones. Apparently, they don't properly
# work yet. Though, right now it also looks like that the documented HELM_* vars won't cover every asset (e.g. cached
# plugins, which is still be stored under ${XDG_CACHE_HOME}/helm/plugins and symlinked into ${HELM_PLUGINS}).
#
# [1] https://helm.sh/docs/topics/plugins/#environment-variables
# [2] https://github.com/helm/helm/pull/7166
#
HELM_HOME ?= $(MKFILE_DIR)/.helm
export XDG_CACHE_HOME = $(HELM_HOME)/cache
export XDG_CONFIG_HOME = $(HELM_HOME)/config
export XDG_DATA_HOME = $(HELM_HOME)/data


CHARTS_VERSION=0.90.0
WIRE_SERVER_VERSION=2.76.0



$(HELM_HOME):
	helm repo add wire-release https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
	helm repo update


# NOTE: if `--untardir` is a relative path, it gets appended to `--destination`
#
.PHONY: pull-charts
pull-charts: $(HELM_HOME)
	eval $$(helm env) \
	&& mkdir -p $$(dirname "$${HELM_REPOSITORY_CACHE}")/charts \
	&& helm pull \
		--version $(CHARTS_VERSION) \
		--destination $$(dirname "$${HELM_REPOSITORY_CACHE}")/charts \
		--untar \
		--untardir $(MKFILE_DIR)/charts \
		\
		wire-release/cassandra-external \
		wire-release/elasticsearch-external \
		wire-release/minio-external \
		\
		wire-release/databases-ephemeral \
		wire-release/demo-smtp \
		wire-release/fake-aws \
		wire-release/reaper \
		wire-release/wire-server \
		wire-release/nginx-ingress-controller \
		wire-release/nginx-ingress-services \
		\
		wire-release/fluent-bit \
		wire-release/kibana \
		wire-release/wire-server-metrics \
		wire-release/backoffice


# NOTE: for each container image list item: pull --> save --> remove
#       archive file name convention: REGISTRY_FQDN+IMAGE_REPOSITORY_AND_NAME++IMAGE_TAG.tar.bz2
# NOTE: sed - filter empty lines and comments
# NOTE: fqcin - fully qualified container image name
.SILENT: pull-images
pull-images:
	mkdir -p $(MKFILE_DIR)/images
	registryFqcin='docker.io/library/registry:2' \
	&& docker pull "$${registryFqcin}" \
	&& docker image save "$${registryFqcin}" \
	| bzip2 --compress -9 > "$(MKFILE_DIR)/images/docker.io+library+registry++2.tar.bz2" \
	&& docker image remove --force "$${registryFqcin}"

	for fqcin in $$(sed -e '/^[[:space:]]*#.*/d' ./images.manifest); do \
		docker pull "$${fqcin}"; \
		\
		imageRegistryAndName="$${fqcin%:*}" \
		&& sanitizedImageRegistryAndName="$${imageRegistryAndName////+}" \
		&& tagName="$${fqcin##*:}" \
		&& docker image save "$${fqcin}" \
		| bzip2 --compress -9 > "./images/$${sanitizedImageRegistryAndName}++$${tagName}.tar.bz2"; \
		docker image remove --force "$${fqcin}"; \
	done

.PHONY: bundle
bundle:
	tar -cf - \
		./images \
		./charts \
		./images.manifest \
		./load-and-push-images.sh \
		./README.md \
	> ${MKFILE_DIR}/offline-package_wire-server-$(WIRE_SERVER_VERSION)_charts-$(CHARTS_VERSION).tar

extract:
	bzip2 --decompress --stdout ${MKFILE_DIR}/offline-package_wire-server-$(WIRE_SERVER_VERSION)_charts-$(CHARTS_VERSION).tar.bz2 \
	| tar -xv - -C ./offline-package


.PHONY: registry
registry:
	docker run \
		--detach \
		--restart=always \
		--name=registry \
		--network=host \
		-v "$(pwd)/registry:/var/lib/registry" \
		-e REGISTRY_HTTP_ADDR=0.0.0.0:5001 \
		registry:2


.PHONY: clean
clean:
	rm -rf \
		$(HELM_HOME) \
		$(MKFILE_DIR)/charts
