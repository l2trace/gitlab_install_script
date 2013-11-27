#!/bin/sh
SOURCE_HOME=/vendor

#DO A GLOBAL FIND AND REPLACE ON THE STRINGS BELOW WITH THEIR APPROPRIATE VALUES 
#email address
#GIT_EMAIL

#server dns name 
#SERVER_FQDN

#sysadmin email 
#ADMIN_EMAIL

#mysql root password 
#MYSQL_ROOT_PASSWORD

#gitlab mysql password
#GITLAB_MYSQL_PASSWORD


#SSL COUNTRY CODE
#SSL_CC

#SSL STATE (FULL)
#SSL_STATE

#SSL CITY
#SSL_CITY

#SSL ORGINIZATION
#SSL_ORG 

#SSL OU 
#SSL_OU





echo > /etc/motd  

rpm --import https://www.fedoraproject.org/static/0608B895.txt
rpm --import http://springdale.math.ias.edu/data/puias/6/x86_64/os/RPM-GPG-KEY-puias
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm



#

cat << 'EOF' >   /etc/yum.repos.d/PUIAS_6_computational.repo 
[PUIAS_6_computational]
name=PUIAS computational Base $releasever - $basearch
mirrorlist=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch/mirrorlist
#baseurl=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puias

EOF

yum-config-manager --enable epel --enable PUIAS_6_computational --enable rhel-6-server-optional-rpms

yum -y update
yum -y groupinstall 'Development Tools'
yum -y install vim-enhanced readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel gcc-c++ \
libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui python-devel redis sudo wget crontabs \
logwatch logrotate perl-Time-HiRes git sendmail-cf redis redis-devel nginx


cd /tmp


#configure redis
chkconfig redis on
service redis start

# configure sendmail 

sed -i 's/EXPOSED_USER/dnl EXPOSED_USER/' /etc/mail/sendmail.mc
cd /etc/mail 
make 
service sendmail restart 

#install ruby
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
cd /tmp/ruby/ruby-2.0.0-p247
./configure --prefix=/usr/local/
make && make install


#install bundler gem 
gem install bundler --no-ri --no-rdoc


#create user for git 
adduser --system --shell /bin/bash --comment 'GitLab' --create-home --home-dir /home/git/ git

#forward emails 
echo ADMIN_EMAIL > /root/.forward
chown root /root/.forward
chmod 600 /root/.forward
restorecon /root/.forward

echo ADMIN_EMAIL> /home/git/.forward
chown git /home/git/.forward
chmod 600 /home/git/.forward
restorecon /home/git/.forward



## gitlab shell 
# execute as git 
cd /home/git

## Clone gitlab shell
git clone https://github.com/gitlabhq/gitlab-shell.git 
chown -R git:git  /home/git/gitlab-shell 
chmod -R u+rwx  /home/git/gitlab-shell 
cd gitlab-shell

## Switch to right version

# Edit config and replace gitlab_url with something like 'http://domain.com/'
#
# Note, 'gitlab_url' is used by gitlab-shell to access GitLab API. Since 
#     1. the whole communication is locally
#     2. next steps will explain how to expose GitLab over HTTPS with custom cert
# it's a good solution is to set gitlab_url as "http://localhost:8080/"
su  git -c 'git checkout -b v1.7.4'
su  git -c 'cp config.yml.example config.yml'
sed -i 's/\(gitlab_url: "http:\/\/\)\(localhost\)\(.*$\)/gitlab_url: "https:\/\/SERVER_FQDN"/' config.yml 





# Do setup
bundle install
su git -c './bin/install'




## mysql 
chkconfig mysqld on
service mysqld start

mysqladmin -u root password MYSQL_ROOT_PASSWORD

cat << 'EOF' | mysql -u root -pMYSQL_ROOT_PASSWORD
CREATE USER 'gitlab'@'localhost' IDENTIFIED BY 'GITLAB_MYSQL_PASSWORD';

CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET 'utf8' COLLATE 'utf8_unicode_ci';

GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO 'gitlab'@'localhost';

EOF


##git lab
cd /home/git 
git clone https://github.com/gitlabhq/gitlabhq.git gitlab
chown -R git:git gitlab
chmod -R u+rwx  gitlab
cd gitlab
su  git -c 'git checkout -b 6-2-stable'


## configure gitlab
# Copy the example GitLab config
su  git -c 'cp config/gitlab.yml.example config/gitlab.yml'

# Replace your_domain_name with the fully-qualified domain name of your host serving GitLab
sed -i 's|localhost|SERVER_FQDN|g' config/gitlab.yml

# Change git's path to point to /usr/local/bin/git
#sed -i 's|/usr/bin/git|/usr/local/bin/git|' config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
chown -R git log/
chown -R git tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/

# Create directory for satellites
mkdir /home/git/gitlab-satellites

# Create directories for sockets/pids and make sure GitLab can write to them
mkdir tmp/pids/
mkdir tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

# Create public/uploads directory otherwise backup will fail
mkdir public/uploads
chmod -R u+rwX  public/uploads


# Copy the example Unicorn config
cp config/unicorn.rb.example config/unicorn.rb


# Enable cluster mode if you expect to have a high load instance
# E.g. change amount of workers to 3 for 2GB RAM server
sed -i 's/worker_processes 2/worker_processes 3/' config/unicorn.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
su - git -c 'git config --global user.name "GitLab"'
su - git -c 'git config --global user.email "GIT_EMAIL"'
su - git -c 'git config --global core.autocrlf input'


##config database 
cat << 'EOF' > config/database.yml
#
# PRODUCTION
#
production:
  adapter: mysql2
  encoding: utf8
  reconnect: false
  database: gitlabhq_production
  pool: 10
  username: gitlab
  password: GITLAB_MYSQL_PASSWORD
  host: localhost
  # socket: /tmp/mysql.sock

#
# Development specific
#
development:
  adapter: mysql2
  encoding: utf8
  reconnect: false
  database: gitlabhq_development
  pool: 5
  username: gitlab
  password: GITLAB_MYSQL_PASSWORD
  # socket: /tmp/mysql.sock

# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test: &test
  adapter: mysql2
  encoding: utf8
  reconnect: false
  database: gitlabhq_test
  pool: 5
  username: gitlab
  password: GITLAB_MYSQL_PASSWORD
  # socket: /tmp/mysql.sock

EOF


gem install charlock_holmes --version '0.6.9.4'

mkdir -p /home/git/repositories/root

chown -R git:git /home/git

chmod -R ug+rwX,o-rwx /home/git/repositories/
chmod -R ug-s /home/git/repositories/
find /home/git/repositories/ -type d -print0 | sudo xargs -0 chmod g+s



cd /home/git/gitlab
su  git -c 'bundle install --deployment --without development test postgres puma aws'
su  git -c 'bundle exec rake gitlab:setup RAILS_ENV=production' 

## install init script 
wget -O /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/init/sysvinit/centos/gitlab-unicorn
chmod +x /etc/init.d/gitlab
chkconfig --add gitlab

service gitlab start


chkconfig nginx on
mkdir /etc/nginx/sites-{available,enabled}
cp $SOURCE_HOME/gitlab-ssl /etc/nginx/sites-available/gitlab
ln -sf /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sed -i 's/include \/etc\/nginx\/conf.d\/\*.conf;.*/include \/etc\/nginx\/sites-enabled\/*;/' /etc/nginx/nginx.conf

groupmems -g git -a nginx 
chmod -R g+rx /home/git/
service nginx start
cd /etc/nginx

CC=SSL_CC
STATE=SSL_STATE
CITY=SSL_CITY
ORGNAME="SSL_ORG" 
OU="SSL_OU"
MACHNAME=SERVER_FQDN
EMAIL=ADMIN_EMAIL
umask 77;echo "$CC 
$STATE
$CITY
$ORGNAME
$OU
$MACHINE
$EMAIL"| openssl req -new -x509 -nodes -days 3560 -out gitlab.crt -keyout gitlab.key 


service nginx restart