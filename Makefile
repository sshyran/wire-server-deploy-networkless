SHELL	          := /bin/bash
PLATFORM	  := $(shell if [[ $$OSTYPE =~ darwin* ]]; then echo darwin; else echo linux; fi)
BIN_DIR	          := $(shell echo $${HOME}/.local/bin)
TMPDIR	          := /tmp

HELM_VERSION	  ?= v2.11.0

KUBECTL_VERSION   ?= v1.12.1
KUBECTL	           = kubectl-$(KUBECTL_VERSION)
KUBECTL_URL	   = https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VERSION)/bin/$(PLATFORM)/amd64/kubectl

default: all

all: $(BIN_DIR) helm kubectl

kubectl: $(BIN_DIR) $(TMPDIR)/$(KUBECTL)
	# TODO: how to verify this binary is A) not a text file and B) not malicious?
	cp $(TMPDIR)/$(KUBECTL) $(BIN_DIR)/$(KUBECTL)
	chmod +x $(BIN_DIR)/$(KUBECTL)
	ln -fs $(BIN_DIR)/$(KUBECTL) $(BIN_DIR)/kubectl

$(TMPDIR)/$(KUBECTL):
	curl -sL $(KUBECTL_URL) > $(TMPDIR)/$(KUBECTL)

helm: $(BIN_DIR)
	curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > $(TMPDIR)/get_helm.sh
	# TODO: how to verify this binary is not malicious?
	chmod +x $(TMPDIR)/get_helm.sh
	export HELM_INSTALL_DIR=$(BIN_DIR); $(TMPDIR)/get_helm.sh --no-sudo -v $(HELM_VERSION)
	helm init -c
	helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
	helm repo add cos https://centerforopenscience.github.io/helm-charts/
	helm repo remove local || true

