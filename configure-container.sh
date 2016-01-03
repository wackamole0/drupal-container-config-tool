#!/bin/bash

dir=`dirname $0`
curdir=`pwd`

path_to_profile_config_files="$dir/files"

#
# Make sure apt is up-to-date and the distro has all current versions of packages installed
#
#apt-get update
#apt-get upgrade -y

#
# Here we install common tools.
#
apt-get install -y nano git openssh-server openssh-client debconf-utils man

#
# Install MySQL (MariaDB)
#

apt-get install -y software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository 'deb [arch=amd64,i386] http://lon1.mirrors.digitalocean.com/mariadb/repo/10.0/ubuntu trusty main'

echo "mariadb-server-10.0	mysql-server/root_password	password	root" | debconf-set-selections
echo "mariadb-server-10.0	mysql-server/root_password_again	password	root" | debconf-set-selections

apt-get -y update
apt-get install -y mariadb-server mariadb-client
update-rc.d mysql defaults
cat "$path_to_profile_config_files/my.cnf" > /etc/mysql/my.cnf
service mysql start
sleep 5

# Create default Drupal database and user
mysql -u root -proot -e "CREATE DATABASE drupal CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u root -proot -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES ON drupal.* TO 'drupal'@'localhost' IDENTIFIED BY 'drupal';"
mysql -u root -proot -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES ON drupal.* TO 'drupal'@'%' IDENTIFIED BY 'drupal';"

# Install Mysqltuner
wget "https://github.com/major/MySQLTuner-perl/tarball/master" -O /tmp/mysqltuner.tgz
mysqltnerdir=`find /tmp -type d -name major-MySQLTuner-perl-\*`
cp "$mysqltunerdir/mysqltuner.pl" /usr/local/bin/mysqltuner
chmod a+x /usr/local/bin/mysqltuner
cd "$curdir"



#
# Install Apache Httpd
#

apt-get install -y apache2 apache2-utils
update-rc.d apache2 defaults
a2enmod rewrite
cat "$path_to_profile_config_files/apache2.mpm_prefork.conf" > /etc/apache2/mods-available/mpm_prefork.conf

service apache2 start

# Create default Drupal site
mv /var/www/html /var/www/httpdocs
mkdir -p /var/www/html
mv /var/www/httpdocs /var/www/html/httpdocs
chown -R rainmaker:www-data /var/www/html
chmod -R ug+rw /var/www/html
cat "$path_to_profile_config_files/apache2-default.conf" > /etc/apache2/sites-available/000-default.conf

#
# Install PHP + APC
#
apt-get install -y php5 php-apc php5-mysql php5-gd php-pear
cat "$path_to_profile_config_files/php.ini" > /etc/php5/apache2/php.ini
cat "$path_to_profile_config_files/php.drupal.ini" > /etc/php5/mods-available/drupal.ini
php5enmod -s apache2 drupal

#
# Install Java 7 (required by Tomcat and Solr)
#
apt-get install -y openjdk-7-jre

#
# Install Tomcat 7
#
apt-get install -y tomcat7 tomcat7-admin
update-rc.d tomcat7 defaults
cat "$path_to_profile_config_files/tomcat-users.xml" > /etc/tomcat7/tomcat-users.xml

#
# Install Solr
#
wget "http://apache.mirror.anlx.net/lucene/solr/4.10.4/solr-4.10.4.tgz" -O /tmp/solr-4.10.4.tgz
cd /tmp
tar -xzf /tmp/solr-4.10.4.tgz
cp /tmp/solr-4.10.4/dist/solrj-lib/* /usr/share/tomcat7/lib/
cp /tmp/solr-4.10.4/example/lib/ext/* /usr/share/tomcat7/lib/
cp /tmp/solr-4.10.4/example/resources/log4j.properties /var/lib/tomcat7/conf/
chgrp tomcat7 /var/lib/tomcat7/conf/log4j.properties
cp /tmp/solr-4.10.4/dist/solr-4.10.4.war /var/lib/tomcat7/webapps/solr.war
chown tomcat7:tomcat7 /var/lib/tomcat7/webapps/solr.war

cp "$path_to_profile_config_files/tomcat-solr.xml" /etc/tomcat7/Catalina/localhost/solr.xml
mkdir /var/lib/solr
rsync -av /tmp/solr-4.10.4/example/solr/ /var/lib/solr/
chown -R tomcat7:tomcat7 /var/lib/solr
chmod -R u+rw /var/lib/solr
chmod go-rwx /var/lib/solr

rm -Rf /tmp/solr-4.10.4
unlink /tmp/solr-4.10.4.tgz
cd "$curdir"

# Setup a Solr core for Drupal
mkdir /var/lib/solr/drupal
rsync -av /var/lib/solr/collection1/ /var/lib/solr/drupal/
echo 'name=drupal' > /var/lib/solr/drupal/core.properties
wget "http://ftp.drupal.org/files/projects/apachesolr-7.x-1.7.tar.gz" -O /tmp/apachesolr-7.x-1.7.tar.gz
cd /tmp
tar -xzf /tmp/apachesolr-7.x-1.7.tar.gz
rsync -av /tmp/apachesolr/solr-conf/solr-4.x/ /var/lib/solr/drupal/conf/
chown -R tomcat7:tomcat7 /var/lib/solr/drupal
rm -Rf /tmp/apachesolr
unlink /tmp/apachesolr-7.x-1.7.tar.gz
cd "$curdir"

# Make rainmaker user a member of www-data
usermod -a -G www-data rainmaker

# Install Drush
apt-get install -y zip unzip php-console-table
mkdir /opt/drush
cd /opt/drush
git clone https://github.com/drush-ops/drush.git .
git checkout 6.5.0
chmod a+x /opt/drush/drush
ln -s /opt/drush/drush /usr/local/bin/drush
cd "$curdir"

# Install Composer
apt-get install -y php5-curl # Composer requires PHP's cURL extensions
cd /tmp
curl -sS https://getcomposer.org/installer | php
mkdir -p /opt/composer
mv composer.phar /opt/composer/composer
ln -s /opt/composer/composer /usr/local/bin/composer
cd "$curdir"

# Install the Deeson frontend tool chain
apt-get install -y ruby ruby-dev nodejs npm
npm install -g grunt-cli
gem install sass compass
#npm install -save-dev grunt-contrib-watch grunt-contrib-compass grunt-contrib-sass
