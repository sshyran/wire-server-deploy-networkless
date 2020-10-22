Offline VPC:

This directory contains components and definitins for performing an offline deployment in an AWS VPC.

In the crash 'trust zone'.

Deployment Process:

From your priviledged laptop:
* Create an SSH key for deployment.
* Start an SSH agent.
* Load your new SSH key into your agent.
* Add this key's fingerprint to wire-server-deploy-networkless/vpc/terraform/boonstrap.tf .

If this VPC has not been deployed via terraform before:
* As a user in the 'Backend-NonProd' IAM group:
  * check out cailleach.
  * run terraform in spray/one-time-setup/setup-terraform-state to create the locks.
    * NOTE: terraform says it is creating all of the things in this file, because there is no root state file for these. don't worry when it fails to create the stuff that already exists!

Use the bootstrap terraform definition in wire-server-deploy-networkless/vpc/terraform/ to deploy the offline VPC. This should result in a bastion host, an admin host, an assethost host, a VPN host, three ansible hosts, and three kubernetes hosts.
  * terraform apply

* log into AWS and look up the IPs for your bastion host, your assethost, and your adminhost.

* add these IPs to the shell environment you are going to run ansible in, so that the following commands work. for instance:
  * export bastion=3.127.42.133 # the bastion host's EXTERNAL IP.
  * export assethost=172.17.1.165 # the assethost's internal IP.
  * export adminhost=172.17.1.192 # the adminhost's internal IP.

From wire-server-deploy-networkless's /vpc/ansible/
* run golden_image.yml on the bastion host.
  * ansible-playbook golden_image.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_debian_repo.yml on the bastion host to download a debian repository.
  * ansible-playbook populate_debian_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_docker_repo.yml on the bastion host to download our docker images.
  * ansible-playbook populate_docker_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_helm_repo.yml on the bastion host to download our helm 3 charts and helm3 binary.
  * ansible-playbook populate_helm_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_helm2_repo.yml on the bastion host to download our helm2 binary and index.
  * ansible-playbook populate_helm2_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_github_repos.yml on the bastion host to download all of the git repos we need.
  * ansible-playbook populate_github_repos.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_ansible_galaxy_repo.yml on the bastion host to download the one package from ansible galaxy that we need.
  * ansible-playbook populate_ansible_galaxy_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_kubernetes_static_content.yml on the bastion host to download kubernetes binaries.
  * ansible-playbook populate_kubernetes_static_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_cassandra_static_content.yml to download cassandra, and the jmx prometheus exporter.
  * ansible-playbook populate_cassandra_static_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* run populate_minio_static_content.yml to download minio, and the minio client.
  * ansible-playbook populate_minio_static_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e first_target_ip=$bastion
* set up your ssh agent in the terminal you're using, and import the key you are using into the agent.
* run deploy_offline_content.yml to copy the debian repo and the docker repo to the assethost. yes, this step uses ssh proxying stuff a bit extra manually, so ensure your ssh agent is working.
  * ansible-playbook deploy_offline_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e bastion_eip=$bastion -e first_target_ip=$assethost
* run golden_image-assethost.yml to golden image the assethost using the local repository.
  * ansible-playbook golden_image-assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_https.yml to set up apache, and serve up the CA certificate for a fake apt.wire.com.
  * ansible-playbook serve_https.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_dns.yml to configure DNS on the assethost.
  * ansible-playbook serve_dns.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_ntp.yml to configure NTP on the assethost.
  * ansible-playbook serve_ntp.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_debian_repo.yml to serve the debian mirror via a fake apt.wire.com.
  * ansible-playbook serve_debian_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_docker_repo.yml to set up docker, and serve docker content through apache.
  * ansible-playbook serve_docker_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_kubernetes_static_content.yml to serve binaries to kubernetes.
  * ansible-playbook serve_kubernetes_static_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_helm2_repo.yml to serve the helm2 binary and index.
  * ansible-playbook serve_helm2_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_ansible_galaxy_repo.yml to serve the ansible galaxy repository.
  * ansible-playbook serve_ansible_galaxy_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_helm3_repo.yml to serve the helm3 binary.
  * ansible-playbook serve_helm3_repo.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_cassandra_static_content.yml to serve cassandra, and the jmx prometheus exporter.
  * ansible-playbook serve_cassandra_static_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run serve_minio_static_content.yml to serve minio, and the minio client.
  * ansible-playbook serve_minio_static_content.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$assethost
* run trust_assethost.yml to load our fake CA's certificate into a target machine, and to use the assethost for DNS resolution.
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$adminhost
* run add_admin.yml to add DNS entries for our admin host to our asset host, so that sudo does not time out.
  * ansible-playbook add_admin.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$adminhost
* run golden_image-from_assethost.yml to golden image the adminhost using the repository on the assethost.
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$adminhost

* Add IPs to your shell environment for the new hosts:
  * export ansnode1=172.17.1.249
  * export ansnode2=172.17.2.14
  * export ansnode3=172.17.3.68
  * export kubepod1=172.17.3.237
  * export kubepod2=172.17.0.27
  * export kubepod3=172.17.3.220
* add DNS entries for these hosts, so that ansible is reliable, and sudo doesn't time out.
  * ansible-playbook add_ansnode.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$ansnode1 -e node_number=1
  * ansible-playbook add_ansnode.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$ansnode2 -e node_number=2
  * ansible-playbook add_ansnode.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$ansnode3 -e node_number=3
  * ansible-playbook add_kubenode.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$kubepod1 -e node_number=1
  * ansible-playbook add_kubenode.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$kubepod2 -e node_number=2
  * ansible-playbook add_kubenode.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=offline.zinfra.io -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$kubepod3 -e node_number=3
* run trust_assethost.yml and golden_image-from_assethost.yml to golden image each of these VMs using the repository on the assethost.
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$ansnode1
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$ansnode1
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$ansnode2
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$ansnode2
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$ansnode3
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$ansnode3
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$kubepod1
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$kubepod1
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$kubepod2
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$kubepod2
  * ansible-playbook trust_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e second_target_ip=$assethost -e first_target_ip=$kubepod3
  * ansible-playbook golden_image-from_assethost.yml -e wdt_infra=vpc -e wdt_region=eu-central-1 -e wdt_env=offline -e fake_domain=wire.com -e bastion_eip=$bastion -e first_target_ip=$kubepod3

* SSH into the admin host, and use it as the "Operator's machine" when following the instructions in https://docs.wire.com/how-to/install/ansible-VMs.html. Continue with these instructions until you get to 'Provisioning virtual machines'.
* At the 'Provisioning virtual machines' section, Skip provisioning (as we have already done that with terraform), and continue with 'Preparing to run ansible'.
* In the 'Authentication' section, perform the steps in 'Configuring SSH keys'. Continue until you get to 'Deploy Elasticsearch'.
  * In the 'ELASTICSEARCH' section of hosts.ini, add the following two lines to tell elasticsearch to use our APT mirror.
  ```
  es_apt_key = "https://download.docker.com/linux/ubuntu/gpg"
  es_apt_url = "deb [trusted=yes] https://apt.wire.com/apt bionic stable"
  ```
  * note that if your fake_domain is not wire.com, you will have to modify this.

* Log in to one of the kubernetes hosts, and install helm3
