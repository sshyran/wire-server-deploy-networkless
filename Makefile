SHELL	          := /bin/bash
PLATFORM	  := $(shell if [[ $$OSTYPE =~ darwin* ]]; then echo darwin; else echo linux; fi)
BIN_DIR	          := $(shell echo $${HOME}/.local/bin)
TMPDIR	          := /tmp

HELM_VERSION	  ?= v2.11.0
# note, technically this is the SHA512SUM of the installer script, which verifies downloads to an (also downloaded) sha256sum.
HELM_SHA512SUM    ?= ef384d99b38d6da4fd6351040ea94d7574df218449d52917a8eeee6845dd8bfa8fd8fffcf2ab88b4bd594d05b9422bf27d0a58857c8894f79684ab11d343ef03

KUBECTL_VERSION   ?= v1.12.1
KUBECTL	           = kubectl-$(KUBECTL_VERSION)
KUBECTL_URL	   = https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VERSION)/bin/$(PLATFORM)/amd64/kubectl
KUBECTL_SHA512SUM ?= 493cefcae9536bfcf071684f82f2b30ef29b55d15f8d5cc045f22c24f17b9329056be0be7805faff9e8f19756c0a84e30e6cb4aeb3f719895d6ca1f1612c592b

default: all

all: $(BIN_DIR) helm kubectl

check_bindir:
	@ [ -d "$(BIN_DIR)" ] || echo "ERROR: $(BIN_DIR) does not exist"

check_path:
	@ [ -n "$$(echo \"$$PATH\" | grep -F ${BIN_DIR})" ] || echo "ERROR: $(BIN_DIR) not in the path"

kubectl: $(BIN_DIR) $(TMPDIR)/$(KUBECTL) check_bindir
	cp $(TMPDIR)/$(KUBECTL) $(BIN_DIR)/$(KUBECTL) && ( sha512sum $(BIN_DIR)/$(KUBECTL) | grep -q $(KUBECTL_SHA512SUM) )
	chmod +x $(BIN_DIR)/$(KUBECTL)
	ln -fs $(BIN_DIR)/$(KUBECTL) $(BIN_DIR)/kubectl

$(TMPDIR)/$(KUBECTL):
	curl -sL $(KUBECTL_URL) > $(TMPDIR)/$(KUBECTL)

helm: $(BIN_DIR) check_bindir check_path
	curl -sL https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > $(TMPDIR)/get_helm.sh
	chmod +x $(TMPDIR)/get_helm.sh && ( sha512sum $(TMPDIR)/get_helm.sh | grep -q $(HELM_SHA512SUM) )
	export HELM_INSTALL_DIR=$(BIN_DIR); $(TMPDIR)/get_helm.sh --no-sudo -v $(HELM_VERSION)
	helm init -c
	helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
	helm repo add cos https://centerforopenscience.github.io/helm-charts/
	helm repo remove local || true
