### (also) run inside docker ###

.PHONY: poetry
poetry:
	curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py > get-poetry.py
	python get-poetry.py --preview -y
	source $$HOME/.poetry/env

.PHONY: wire-server-deploy
wire-server-deploy:
	git clone https://github.com/wireapp/wire-server-deploy -b feature/ansible-configuration-binaries
	cd wire-server-deploy/ansible && poetry install && make download

### run locally - warmup ###

warmup: zauth build instructions

.PHONY: zauth
zauth:
	docker save quay.io/wire/zauth > zauth.tar

.PHONY: build
build:
	docker build -t quay.io/wire/networkless-admin .
	docker save quay.io/wire/networkless-admin > networkless-admin.tar
	## requires quay.io credentials
	# docker login quay.io
	# docker push quay.io/wire/networkless-admin

instructions:
	@echo hello

### run locally - offline ###

install-offline:
	docker load < zauth.tar
	docker load < networkless-admin.tar

