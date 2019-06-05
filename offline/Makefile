
.PHONY: warmup
warmup:
	git clone https://github.com/wireapp/wire-server-deploy -b feature/ansible-configuration-binaries
	cd wire-server-deploy/ansible
	curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py > get-poetry.py
	
	#TODO download poetry from local repo
	python2.7 get-poetry.py --preview
	source $$HOME/.poetry/env
	poetry install
	make download


install-offline:
	echo TODO

