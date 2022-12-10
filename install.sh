#!/bin/bash
#
#    DjangoPBX
#
#    MIT License
#
#    Copyright (c) 2016 - 2022 Adrian Fretwell <adrian@djangopbx.com>
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
#
#    Contributor(s):
#    Adrian Fretwell <adrian@djangopbx.com>
#

##############################################################################
#                         Configuration Section                              #
##############################################################################

database_password=random
system_password=random
signalwire_token=

install_nagios_nrpe=no

########################### Configuration End ################################

read -p "Install DjangoPBX Are you sure? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

apt-get update
apt-get install -y lsb-release

os_name=$(lsb_release -is)
os_codename=$(lsb_release -cs)

if [[ $os_name != "Debian" ]]
then
    echo "This installer is for use on Debian systems only."
    exit 1
fi

if [[ $os_codename != "bullseye" ]]
then
    echo "WARNING: This installer is only designed and tested with Bulleye."
    read -p "Do you want to continue? " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 1
    fi
fi

if [[ $database_password == "random" ]]
then
    echo "Generating random database pasword... "
    database_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64)
fi

if [[ $system_password == "random" ]]
then
    echo "Generating random system pasword... "
    system_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64)
fi

cd /root
echo $database_password
exit 0



cat << EOF > /etc/motd

**************************************************************************
*                                                                        *
*                            djangopbx.com                               *
*                                                                        *
*                               WARNING:                                 *
*                                                                        *
* You have accessed the host djangopbx system operated by:               *
* My Company. You are required  to have personal authorisation           *
* from the system administrator before you use this computer and you are *
* strictly limited to  the  use set  out  in that written authorisation. *
* Unauthorised access or use of this system is prohibited and            *
* constitutes an offence under the Computer Misuse Act 1990.             *
*                                                                        *
* If you are NOT authorised to use this computer DISCONNECT NOW!         *
*                                                                        *
**************************************************************************

EOF

mkdir -p /var/log/django-pbx

apt-get install -y git
apt-get install -y ngrep sngrep tcpdump rsync

if [[ $install_nagios_nrpe == "yes" ]]
then
    apt-get install -y nagios-nrpe-server
fi

apt-get install -y vnstat
apt-get install -y net-tools
apt-get install -y nmap
apt-get install -y dnsutils
apt-get install -y sudo
apt-get install -y gunpg
apt-get install -y gnupg2
apt-get install -y m4
apt-get install -y python3-nftables
apt-get install -y wget

adduser django-pbx
mkdir -p /home/django-pbx/tmp
chown django-pbx:django-pbx tmp

mkdir -p /home/django-pbx/media/fs/music/default
mkdir -p /home/django-pbx/media/fs/recordings
mkdir -p /home/django-pbx/media/fs/voicemail
chown -R django-pbx:django-pbx /home/django-pbx/media

rmdir /var/lib/freeswitch/recordings
ln -s /home/django-pbx/media/fs/recordings /var/lib/freeswitch/recordings


cwd=$(pwd)
cd /tmp

# clone the IPX Django application
sudo -u django-pbx bash -c 'cd /home/django-pbx && git clone https://github.com/djangopbx/djangopbx.git pbx'

cd $cwd

apt-get install -y postgresql
apt-get install -y libpq-dev

apt-get install -y python3-pip
apt-get install -y python3-dev
pip3 install psycopg2

cwd=$(pwd)
cd /tmp

#add the databases, users and grant permissions to them
sudo -u postgres psql -c "CREATE DATABASE djangopbx;";
sudo -u postgres psql -c "CREATE DATABASE freeswitch;";
sudo -u postgres psql -c "CREATE ROLE djangopbx WITH SUPERUSER LOGIN PASSWORD '$database_password';"
sudo -u postgres psql -c "CREATE ROLE freeswitch WITH SUPERUSER LOGIN PASSWORD '$database_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE djangopbx to djangopbx;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to freeswitch;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to djangopbx;"
sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"


apt-get install -y curl memcached haveged apt-transport-https

wget --http-user=signalwire --http-password=$signalwire_token -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg
echo "machine freeswitch.signalwire.com login signalwire password $signalwire_token" > /etc/apt/auth.conf
echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list
echo "deb-src [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list

apt-get update
apt-get install -y gdb ntp
apt-get install -y freeswitch-meta-bare freeswitch-conf-vanilla freeswitch-mod-commands freeswitch-mod-console freeswitch-mod-logfile
apt-get install -y freeswitch-lang-en freeswitch-mod-say-en freeswitch-sounds-en-us-callie
apt-get install -y freeswitch-sounds-es-ar-mario freeswitch-mod-say-es freeswitch-mod-say-es-ar
apt-get install -y freeswitch-sounds-fr-ca-june freeswitch-mod-say-fr
apt-get install -y freeswitch-mod-enum freeswitch-mod-cdr-csv freeswitch-mod-event-socket freeswitch-mod-sofia freeswitch-mod-sofia-dbg freeswitch-mod-loopback
apt-get install -y freeswitch-mod-conference freeswitch-mod-db freeswitch-mod-dptools freeswitch-mod-expr freeswitch-mod-fifo freeswitch-mod-httapi
apt-get install -y freeswitch-mod-hash freeswitch-mod-esl freeswitch-mod-esf freeswitch-mod-fsv freeswitch-mod-valet-parking freeswitch-mod-dialplan-xml freeswitch-dbg
apt-get install -y freeswitch-mod-sndfile freeswitch-mod-native-file freeswitch-mod-local-stream freeswitch-mod-tone-stream freeswitch-meta-mod-say
apt-get install -y freeswitch-mod-python3
apt-get install -y freeswitch-mod-xml-cdr freeswitch-mod-verto freeswitch-mod-callcenter freeswitch-mod-rtc freeswitch-mod-png freeswitch-mod-json-cdr freeswitch-mod-shout
apt-get install -y freeswitch-mod-sms freeswitch-mod-sms-dbg freeswitch-mod-cidlookup freeswitch-mod-memcache
apt-get install -y freeswitch-mod-imagick freeswitch-mod-tts-commandline freeswitch-mod-directory
apt-get install -y freeswitch-mod-av freeswitch-mod-flite freeswitch-mod-distributor freeswitch-meta-codecs
apt-get install -y freeswitch-mod-pgsql
apt-get install -y freeswitch-mod-xml-curl
apt-get install -y freeswitch-music-default
apt-get install -y libyuv-dev

# make sure that postgresql is started before starting freeswitch
sed -i /lib/systemd/system/freeswitch.service -e s:'local-fs.target:local-fs.target postgresql.service:'

# remove the music package to protect music on hold from package updates
mv /usr/share/freeswitch/sounds/music/*000 /home/django-pbx/media/fs/music
mv /usr/share/freeswitch/sounds/music/default/*000 /home/django-pbx/media/fs/music/default
apt-get remove -y freeswitch-music-default
chown -R django-pbx:django-pbx /home/django-pbx/media/fs/music/*

# setup /etc/freeswitch/directory
mv /etc/freeswitch /etc/freeswitch.orig
mkdir -p /etc/freeswitch
cp -r /home/django-pbx/pbx/switch/resources/templates/conf/* /etc/freeswitch
chown -R django-pbx:django-pbx /etc/freeswitch

#Sudoers
#======================

visudo -c -q -f /home/django-pbx/pbx/pbx/resources/etc/sudoers.d/django_pbx_sudo_inc && \
cp /home/django-pbx/pbx/pbx/resources/etc/sudoers.d/django_pbx_sudo_inc /etc/sudoers.d/django_pbx_sudo_inc

if [ -f "/etc/sudoers.d/django_pbx_sudo_inc" ]; then
   chmod 600 /etc/sudoers.d/django_pbx_sudo_inc
   chown root:root /etc/sudoers.d/django_pbx_sudo_inc
   echo "Django PBX sudo installed OK"
fi

#Set up Django
#==================

pip3 install Django
pip3 install django-static-fontawesome
pip3 install django-bootstrap-static
pip3 install djangorestframework

# Markdown support for the browsable API.
pip3 install markdown

# Filtering support
pip3 install django-filter

pip3 install django-tables2

# import export data in Admin
pip3 install django-import-export

pip3 install django-ace

pip3 install distro
pip3 install psutil
pip3 install lxml
pip3 install pymemcache
pip3 install xmltodict

mkdir -p /var/www/static
chown django-pbx:django-pbx /var/www/static



#cwd=$(pwd)
#cd /tmp

# Perform initial steps on new DjangoPBX Django application
#sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py migrate'
#sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py createsuperuser'
#sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py makemigrations'
#sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py migrate'
#sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py collectstatic'

#cd $cwd



read -p "Show database password? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo $database_password
fi

read -p "Show system password? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo $system_password
fi

echo " "
echo "Installation Complete."
