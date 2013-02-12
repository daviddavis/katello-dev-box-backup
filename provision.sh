#!/bin/bash
KATELLO_DIR=/vagrant
FEDORA_RELEASE=`rpm -q --queryformat '%{VERSION}' fedora-release`

## disable iptables
systemctl stop iptables.service && systemctl disable iptables.service

# setup sudoers
sed -i 's/Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

# install the development tools
yum groupinstall -y development-tools
yum install -y ruby-devel postgresql-devel sqlite-devel libxml2 libxml2-devel libxslt libxslt-devel vim

# install the katello-repos
yum install -y http://fedorapeople.org/groups/katello/releases/yum/nightly/Fedora/$FEDORA_RELEASE/x86_64/katello-repos-latest.rpm

# install katello
yum install -y katello-all

# configure katello
katello-configure --no-bars

# create our katello user
su - postgres -c 'createuser -dls katello --no-password'

# relax postgres requirements
sed -i '/^local*/ s/^/#/' /var/lib/pgsql/data/pg_hba.conf
sed -i '/^host*/ s/^/#/' /var/lib/pgsql/data/pg_hba.conf
echo "local all all              trust" >> /var/lib/pgsql/data/pg_hba.conf
echo "host  all all 127.0.0.1/32 trust" >> /var/lib/pgsql/data/pg_hba.conf
echo "host  all all ::1/128      trust" >> /var/lib/pgsql/data/pg_hba.conf
service postgresql restart

# stop and disable katello services
service katello-jobs stop && service katello stop
systemctl disable katello-jobs.service && systemctl disable katello.service

# link katello.yml
mv /etc/katello/katello.yml /etc/katello/katello.yml.rpm_based
ln -s $KATELLO_DIR/src/config/katello.yml /etc/katello/katello.yml

# setup our project
cd $KATELLO_DIR/src && bundle install --quiet > /dev/null
cd $KATELLO_DIR/src && script/reset-oauth shhhh
$KATELLO_DIR/src/script/katello-reset-dbs -f development .

# start it up
$KATELLO_DIR/src/script/delayed_job start
cd $KATELLO_DIR/src && bundle exec 'rails server -d webrick'
