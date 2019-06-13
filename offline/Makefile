### (also) run inside docker ###

SHELL=/bin/bash

.PHONY: poetry
poetry:
	curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py > get-poetry.py
	python get-poetry.py --preview -y
	rm -f get-poetry.py
	source $$HOME/.poetry/env

.PHONY: clone
clone:
	rm -rf wire-server
	rm -rf wire-server-deploy
	rm -rf wire-server-deploy-networkless
	git clone https://github.com/wireapp/wire-server-deploy
	git clone https://github.com/wireapp/wire-server-deploy-networkless
	git clone --depth 1 https://github.com/wireapp/wire-server

.PHONY: wire-server-deploy
wire-server-deploy:
	cd wire-server-deploy/ansible && poetry install && make download
	cd wire-server-deploy/ansible && ln -s ../../wire-server-deploy-networkless/admin_vm/setup-mitm-cert.yml setup-mitm-cert.yml
	cd wire-server-deploy/ansible && ln -s ../../wire-server-deploy-networkless/admin_vm/kubernetes_proxy.yml kubernetes_proxy.yml

### run locally - warmup ###

warmup: zauth build zipme

.PHONY: zauth
zauth:
	docker pull quay.io/wire/zauth
	docker save quay.io/wire/zauth > zauth.tar

.PHONY: build
build:
	docker build -t quay.io/wire/networkless-admin .
	docker save quay.io/wire/networkless-admin > networkless-admin.tar

.PHONY: push
push:
	## requires quay.io credentials
	# docker login quay.io
	docker push quay.io/wire/networkless-admin
	# requires AWS credentials
	aws s3 cp ../tmp/admin.tar.gz s3://public.wire.com/networkless/admin.tar.gz

.PHONY: zipme
zipme:
	mkdir -p ../tmp
	rm -f ../tmp/admin.tar.gz
	tar -czvf ../tmp/admin.tar.gz .
	@echo see '../tmp/admin.tar.gz' file
	@echo use the following checksum when downloading it from an untrusted source:
	sha256sum ../tmp/admin.tar.gz

.PHONY: clean
clean:
	rm -f zauth.tar networkless-admin.tar

### run locally - offline ###

install-offline:
	docker load < zauth.tar
	docker load < networkless-admin.tar
