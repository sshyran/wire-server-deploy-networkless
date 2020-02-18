Offline VPC:

This directory contains components and definitins for performing an offline deployment in an AWS VPC.

In the crash 'trust zone'.

Deployment Process:

From your priviledged laptop:
* Create an SSH key for deployment.
* start an SSH agent.
* load this key into your agent.
* add this key's fingerprint to wire-server-deploy-networkless/vpc/terraform/

If this VPC has not been deployed via terraform before:
* As a user in the 'Backend-NonProd' IAM group:
  * check out cailleach.
  * run terraform in spray/one-time-setup/setup-terraform-state to create the locks.
    * NOTE: terraform says it is creating all of the things in this file, because there is no root state file for these. don't worry when it fails to create the stuff that already exists!

Use the bootstrap terraform definition in wire-server-deploy-networkless's /vpc/terraform/ to deploy the offline VPC. This should result in a bastion host, an admin host, an assethost host, a VPN host, FIXME: three ansible hosts, and thre\
e kubernetes hosts.
  * terraform apply

* log into AWS and look up the IPs for your bastion host, and your assethost.

* add these IPs to your shell environment, so the below commands work. for instance:
  * export bastion=3.126.15.79 # the bastion host's EXTERNAL IP.
  * export assethost=172.17.0.223 # the assethost's internal IP.

From wire-server-deploy-networkless's /vpc/ansible/
* run golden_image.yml on the bastion host.
  * ansible-playbook golden_image.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_debian_repo.yml on the bastion host to download a debian repository.
  * ansible-playbook populate_debian_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_docker_repo.yml on the bastion host to download our docker images.
  * ansible-playbook populate_docker_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_helm_repo.yml on the bastion host to download our helm charts.
  * ansible-playbook populate_helm_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* set up your ssh agent in the terminal you're using, and import the key you are using into the agent.
* run deploy_offline_content.yml to copy the debian repo and the docker repo to the assethost. yes, this step uses ssh proxying stuff a bit extra manually, so ensure your ssh agent is working.
  * ansible-playbook deploy_offline_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e bastion_eip=$bastion -e first_target_ip=$assethost
* run golden_image-assethost.yml to golden image the assethost using the local repository.
  * ansible-playbook golden_image-assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_debian_repo.yml to set up apache, and serve the debian mirror via a fake apt.wire.com.
  * ansible-playbook serve_debian_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_docker_repo.yml to set up docker, and serve docker content through apache.
  * ansible-playbook serve_docker_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
		