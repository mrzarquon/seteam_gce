gce_disk { 'master-disk':
  ensure      => present,
  description => 'master disk',
  size_gb     => '10',
  zone        => 'us-central-1a',
}
gce_instance { 'puppet-master':
  ensure       => present,
  description  => 'puppet master',
  disk         => 'master-disk',
  machine_type => 'n1-standard-1',
  zone         => 'us-central-1a',
  network      => 'default',
  image        => 'projects/centos-cloud/global/images/centos-6-v20130926',
  tags         => ['puppetmaster','sedemo'],

