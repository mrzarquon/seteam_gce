#!/bin/bash

gcutil --service_version="v1beta16" \
  --project="flowing-flame-390" \
  addinstance "puppetmaster-1a" \
  --description="test vm master" \
  --tags="pemaster" \
  --zone="us-central1-a" \
  --machine_type="n1-standard-1" \
  --network="default" \
  --external_ip_address="ephemeral" \
  --service_account_scopes="https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.full_control" \
  --image="https://www.googleapis.com/compute/v1beta16/projects/centos-cloud/global/images/centos-6-v20130926" \
  --persistent_boot_disk="true" \
  --metadata="pe_role:master" \
  --metadata="pe_version:3.1.0" \
  --metadata="pe_consoleadmin:admin@puppetlabs.com" \
  --metadata="pe_consolepwd:puppetlabs" \
  --metadata_from_file=startup-script:./puppet-enterprise.sh
