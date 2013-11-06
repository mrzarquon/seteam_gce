#!/bin/bash

gcutil --service_version="v1beta16" \
  --project="flowing-flame-390" \
  addinstance "puppetagent-1a" \
  --description="test vm agent1" \
  --tags="peagent" \
  --zone="us-central1-a" \
  --machine_type="f1-micro" \
  --network="default" \
  --external_ip_address="ephemeral" \
  --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control" \
  --image="https://www.googleapis.com/compute/v1beta16/projects/centos-cloud/global/images/centos-6-v20130926" \
  --persistent_boot_disk="true" \
  --metadata="pe_role:agent" \
  --metadata="pe_master:puppetmaster-1a.c.flowing-flame-390.internal" \
  --metadata_from_file=startup-script:./puppet-enterprise.sh

gcutil --service_version="v1beta16" \
  --project="flowing-flame-390" \
  addinstance "puppetagent-2a" \
  --description="test vm agent2" \
  --tags="peagent" \
  --zone="us-central1-a" \
  --machine_type="f1-micro" \
  --network="default" \
  --external_ip_address="ephemeral" \
  --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control" \
  --image="https://www.googleapis.com/compute/v1beta16/projects/debian-cloud/global/images/debian-7-wheezy-v20131014" \
  --persistent_boot_disk="true" \
  --metadata="pe_role:agent" \
  --metadata="pe_master:puppetmaster-1a.c.flowing-flame-390.internal" \
  --metadata_from_file=startup-script:./puppet-enterprise.sh
