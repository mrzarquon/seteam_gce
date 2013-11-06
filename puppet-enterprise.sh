#!/bin/bash
# this script can be used in combination with the gce types to install
# puppet and classify the provisioned instances

RESULTS_FILE='/tmp/puppet_bootstrap_output'
S3_BASE='https://s3.amazonaws.com/pe-builds/released/'

function check_exit_status() {
  if [ ! -f $RESULTS_FILE ]; then
    echo '1' > $RESULTS_FILE
  fi
}

trap check_exit_status INT TERM EXIT

function write_masteranswers() {
  cat > /opt/masteranswers.txt << ANSWERS
q_all_in_one_install=y
q_backup_and_purge_old_configuration=n
q_backup_and_purge_old_database_directory=n
q_database_host=localhost
q_database_install=y
q_install=y
q_pe_database=y
q_puppet_cloud_install=y
q_puppet_enterpriseconsole_auth_password=$PUPPET_PE_CONSOLEPWD
q_puppet_enterpriseconsole_auth_user_email=$PUPPET_PE_CONSOLEADMIN
q_puppet_enterpriseconsole_httpd_port=443
q_puppet_enterpriseconsole_install=y
q_puppet_enterpriseconsole_master_hostname=$PUPPET_HOSTNAME
q_puppet_enterpriseconsole_smtp_host=localhost
q_puppet_enterpriseconsole_smtp_password=
q_puppet_enterpriseconsole_smtp_port=25
q_puppet_enterpriseconsole_smtp_use_tls=n
q_puppet_enterpriseconsole_smtp_user_auth=n
q_puppet_enterpriseconsole_smtp_username=
q_puppet_symlinks_install=y
q_puppetagent_certname=$PUPPET_HOSTNAME
q_puppetagent_install=y
q_puppetagent_server=$PUPPET_HOSTNAME
q_puppetdb_hostname=$PUPPET_HOSTNAME
q_puppetdb_install=y
q_puppetdb_port=8081
q_puppetmaster_certname=$PUPPET_HOSTNAME
q_puppetmaster_dnsaltnames=$PUPPET_HOSTNAME,puppet
q_puppetmaster_enterpriseconsole_hostname=localhost
q_puppetmaster_enterpriseconsole_port=443
q_puppetmaster_install=y
q_run_updtvpkg=n
q_vendor_packages_install=y
ANSWERS
}

function install_puppetmaster() {
  if [ ! -d /opt/puppet-enterprise ]; then
    mkdir -p /opt/puppet-enterprise
  fi
  if [ ! -f /opt/puppet-enterprise/puppet-enterprise-installer ]; then
    case ${breed} in
      "redhat")
        curl -s -o /opt/pe-installer.tar.gz "https://s3.amazonaws.com/pe-builds/released/$PUPPET_PE_VERSION/puppet-enterprise-$PUPPET_PE_VERSION-el-6-x86_64.tar.gz" ;;
      "debian")
        curl -s -o /opt/pe-installer.tar.gz "https://s3.amazonaws.com/pe-builds/released/$PUPPET_PE_VERSION/puppet-enterprise-$PUPPET_PE_VERSION-debian-7-amd64.tar.gz" ;;
    esac
    #Drop installer in predictable location
    tar --extract --file=/opt/pe-installer.tar.gz --strip-components=1 --directory=/opt/puppet-enterprise
  fi
  write_masteranswers
  /opt/puppet-enterprise/puppet-enterprise-installer -a /opt/masteranswers.txt
}

function download_modules() {
  if [ -n $1 ]; then
    MODULE_LIST=`echo "$1" | sed 's/,/ /g'`
    for i in $MODULE_LIST; do puppet module install --force $i ; done;
  fi
}

function install_puppetagent () {
  case ${breed} in
    "redhat")
      curl -s http://$PUPPET_PE_MASTER/el.bash | /bin/bash ;;
    "debian")
      curl -s http://$PUPPET_PE_MASTER/deb.bash | /bin/bash ;;
  esac
}

function clone_modules() {
  if [ -n "$1" ]; then
    pushd /etc/puppet/modules
    MODULE_LIST=`echo "$1" | sed 's/,/ /g'`
    for i in $MODULE_LIST; do
      MODULE=`echo "$i" | sed 's/#/ /'`
      if [ ! -d `echo $MODULE | cut -d' ' -f2` ]; then
        git clone $MODULE ;
      fi
    done;
    popd
  fi
}

#delete me, testing provisioing
function prep_master () {
  yum install -y git
  git clone https://github.com/mrzarquon/mrzarquon-pe_repo /etc/puppetlabs/puppet/modules/pe_repo
  echo "*" > /etc/puppetlabs/puppet/autosign.conf
  /opt/puppet/bin/puppet module install nanliu-staging
  /opt/puppet/bin/rake -f /opt/puppet/share/puppet-dashboard/Rakefile RAILS_ENV=production nodeclass:add['pe_repo','skip']
  /opt/puppet/bin/rake -f /opt/puppet/share/puppet-dashboard/Rakefile RAILS_ENV=production node:addclass[`hostname -f`,'pe_repo']
  /opt/puppet/bin/puppet agent -t
}


function run_manifest_apply() {
  if [ -n "$1" ]; then
    mkdir -p /etc/puppet/manifests
    echo "$1" > /etc/puppet/manifests/"$2".pp
    puppet apply --trace --debug /etc/puppet/manifests/"$2".pp
  fi
}

function provision_puppet() {
  if [ -f /etc/redhat-release ]; then
    export breed='redhat'
  elif [ -f /etc/debian_version ]; then
    export breed='debian'
  else
    echo "This OS is not supported by Puppet Cloud Provisioner"
    exit 1
  fi
  
  # For more on metadata, see https://developers.google.com/compute/docs/metadata
  MD="http://metadata/computeMetadata/v1beta1/instance"
  PUPPET_CLASSES=$(curl -fs $MD/attributes/puppet_classes)
  PUPPET_MANIFEST=$(curl -fs $MD/attributes/puppet_manifest)
  PUPPET_MODULES=$(curl -fs $MD/attributes/puppet_modules)
  PUPPET_REPOS=$(curl -fs $MD/attributes/puppet_repos)
  PUPPET_HOSTNAME=$(curl -fs $MD/hostname)
  PUPPET_PE_ROLE=$(curl -fs $MD/attributes/pe_role)
  PUPPET_PE_VERSION=$(curl -fs $MD/attributes/pe_version)
  PUPPET_PE_CONSOLEADMIN=$(curl -fs $MD/attributes/pe_consoleadmin)
  PUPPET_PE_CONSOLEPWD=$(curl -fs $MD/attributes/pe_consolepwd)
  PUPPET_PE_MASTER=$(curl -fs $MD/attributes/pe_master)
  # BEGIN HACK
  #
  # This is a pretty awful hack, but I did not really understand a better way to do it.
  # The problem is that applications may need to specify facts or other system specific information
  # as a part of the classifaction process. I this case, I need to be able to figure out my own internal
  # and external ip addresses.
  # I am going to just pass in these specific things as variables in the puppetcode and parse them out here.
  # Eventually, I may want to do some kind of a fact lookup
  GCE_EXTERNAL_IP=$(curl -fs $MD/network-interfaces/0/access-configs/0/external-ip)
  #GCE_EXTERNAL_IP=$(curl -fs http://bot.whatismyipaddress.com)
  GCE_INTERNAL_IP=$(curl -fs $MD/network-interfaces/0/ip)
  #GCE_INTERNAL_IP=$(ifconfig eth0 |grep "inet addr:" | cut -c21-34)
  PUPPET_CLASSES=$(echo "$PUPPET_CLASSES" | sed -e "s/\$gce_external_ip/$GCE_EXTERNAL_IP/" -e "s/\$gce_internal_ip/$GCE_INTERNAL_IP/")
  PUPPET_MANIFEST=$(echo "$PUPPET_MANIFEST" | sed -e "s/\$gce_external_ip/$GCE_EXTERNAL_IP/" -e "s/\$gce_internal_ip/$GCE_INTERNAL_IP/")
  # END HACK
  
  #set time before everything
  ntpdate -u metadata.google.internal

  if [ $PUPPET_PE_ROLE = 'master' ]; then
    install_puppetmaster
    sleep 15
    /opt/puppet/bin/puppet agent -t
    prep_master
  else
    install_puppetagent
    sleep 135 
    /opt/puppet/bin/puppet agent -t
  fi

  #configure_puppet "$PUPPET_HOSTNAME"
  #download_modules "$PUPPET_MODULES"
  #clone_modules    "$PUPPET_REPOS"
  #run_enc_apply "$PUPPET_CLASSES" "$PUPPET_HOSTNAME"
  #run_manifest_apply "$PUPPET_MANIFEST" "$PUPPET_HOSTNAME"
  echo $? > $RESULTS_FILE
  echo "Puppet installation finished!"
  exit 0
}

provision_puppet
