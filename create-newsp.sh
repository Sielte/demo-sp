#!/bin/sh
echo "=== SISTEMO HOST ==="
sudo sed -i "1s/$/ $(hostname | tr '\n' ' ')/" /etc/hosts

echo "=== UPDATE & UPGRADE ==="
#sudo apt-get update && sudo apt-get --yes upgrade  
sudo apt-get update

echo "=== INSTALLO PACCHETTI"
sudo apt-get --yes install git wget

echo "=== INSTALLO PUPPET"
codename=`lsb_release --codename | cut -f2`
sudo wget https://apt.puppetlabs.com/puppetlabs-release-$codename.deb -O /opt/puppetlabs-release-$codename.deb
sudo dpkg -i /opt/puppetlabs-release-$codename.deb
sudo apt-get update
sudo apt-get --yes install puppet


echo "=== PUPPET INSTALLO MODULI ==="
#sudo puppet module install mayflower-php --version 4.0.0-beta1
sudo puppet module install puppet-php
sudo puppet module install puppetlabs-apache

sudo mkdir -p /opt/spid-simplesamlphp
sudo chown www-data:www-data /opt/spid-simplesamlphp
echo "=== CLONE REPOSITORY ==="
sudo -u www-data git clone https://github.com/italia/spid-simplesamlphp.git /opt/spid-simplesamlphp

echo "=== CHIAVI ==="
sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com 4F4EA0AAE5267A6C

sudo tee /opt/makecert.sh << EOF
#!/bin/sh
PEM="/opt/spid-simplesamlphp/cert/spid-sp.pem"
CRT="/opt/spid-simplesamlphp/cert/spid-sp.crt"
if [ ! -f "\$PEM" ]; then
  openssl req -x509 -newkey rsa:2048 -keyout \$PEM -out \$CRT -days 365 -nodes -subj "/C=IT/ST=Rome/L=Forum PA/O=Forum PA/OU=Forum PA/CN=*.spdemo.it"
  echo "Certificati generati con successo."
else
  echo "Attenzione! Certificati presenti"
fi
EOF

sudo tee /etc/puppet/manifests/spid.pp << EOF
include apt
package { 'memcached':
    ensure => 'installed',
}



class { '::php':  
  composer => true, 
  extensions => {
	curl => { },
	sqlite => { },
	memcache => { },
	memcached => { },
	mcrypt => { },
	ldap => { },
	xml => { },	
  } 
}
  
file { '/opt/spid-simplesamlphp/log':
	ensure => 'directory',
	owner  => 'www-data',
    group  => 'www-data',
	mode   => '0660',
}
file { '/opt/spid-simplesamlphp/vendor':
	ensure => 'directory',
	owner  => 'www-data',
    group  => 'www-data',
	mode   => '0660',
}

file { '/opt/spid-simplesamlphp/cert':
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0770',
}

file {
        '/opt/makecert.sh':
        ensure => present,
		mode   => '0771',
}


file {
	'/opt/spid-simplesamlphp/config/config.php':
	ensure => present,
	source => "/opt/spid-simplesamlphp/config-templates/config-spid.php",
}

file {
	'/opt/spid-simplesamlphp/config/authsources.php':
	ensure => present,
	source => "/opt/spid-simplesamlphp/config-templates/authsources-spid.php",
}

  
class { 'apache':
  default_vhost => false,
  mpm_module => 'prefork'
}
include apache::mod::php
include apache::mod::alias

apache::vhost { 'subdomain.loc':
  vhost_name      => '*',
  port            => '443',
  ssl             => true,
  docroot         => '/opt/spid-simplesamlphp/www',
  aliases         => [ {
                alias => '/simplesaml',
                path  => '/opt/spid-simplesamlphp/www'
  } ],
}

apache::vhost { 'site.name.fdqn':
  port => 80,
  docroot    => '/opt/spid-simplesamlphp',
  rewrites => [
    {
      comment      => 'redirect ssl',
      rewrite_cond => ['%{HTTPS} off'],
      rewrite_rule => ['(.*) https://%{HTTP_HOST}%{REQUEST_URI} [R]'],
    },
  ],
}

exec { 'sudo -u www-data composer install -d /opt/spid-simplesamlphp/':
        path    => '/usr/local/bin/:/usr/bin/',
        require => Class['apache']
}


exec { 'sudo bash /opt/makecert.sh':
        path    => '/usr/local/bin/:/usr/bin/',
        require => Class['apache']
}


EOF

echo "=== APPLICO PUPPET ==="
sudo puppet apply /etc/puppet/manifests/spid.pp
sudo chown -R www-data:www-data /opt/spid-simplesamlphp/cert/
sudo chmod 640 /opt/spid-simplesamlphp/cert/*


echo "Ready. The system is finally up, after $(uptime -p)"
