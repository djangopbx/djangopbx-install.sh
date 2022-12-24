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

#  Passwords
database_password=random
system_password=random

# Freeswitch method can be src or pkg
#   if pkg is seclected then you must frovide a signalwire token.
freeswitch_method=src
signalwire_token=None

# Software versions
freeswitch_version=1.10.8
sofia_version=1.13.10

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
chown django-pbx:django-pbx /var/log/django-pbx

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

echo "You are about to create a new user called django-pbx, please use a strong, secure password."
read -p "Press any key to continue " -n 1 -r
echo ""
adduser django-pbx
mkdir -p /home/django-pbx/tmp
chown django-pbx:django-pbx tmp

mkdir -p /home/django-pbx/media/fs/music/default
mkdir -p /home/django-pbx/media/fs/recordings
mkdir -p /home/django-pbx/media/fs/voicemail/default
chown -R django-pbx:django-pbx /home/django-pbx/media


cwd=$(pwd)
cd /tmp
# clone the DjangoPBX application
sudo -u django-pbx bash -c 'cd /home/django-pbx && git clone https://github.com/djangopbx/djangopbx.git pbx'
cd $cwd

#Firewall
#======================
#Since Buster, Debian has nft dy befault, we now use this rather than the legacy iptables.

cp /home/django-pbx/pbx/pbx/resources/etc/nftables.conf /etc/nftables.conf
chmod 755 /etc/nftables.conf
chown root:root /etc/nftables.conf



#Database
#======================

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
sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'

cd $cwd

apt-get install -y curl memcached haveged apt-transport-https


if [[ $freeswitch_method == "pkg" ]]
then

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
fi

if [[ $freeswitch_method == "src" ]]
then
    apt-get install -y autoconf automake devscripts g++ git-core libncurses5-dev libtool make libjpeg-dev
    apt-get install -y pkg-config flac  libgdbm-dev libdb-dev gettext equivs mlocate dpkg-dev libpq-dev
    apt-get install -y liblua5.2-dev libtiff5-dev libperl-dev libcurl4-openssl-dev libsqlite3-dev libpcre3-dev
    apt-get install -y devscripts libspeexdsp-dev libspeex-dev libldns-dev libedit-dev libopus-dev libmemcached-dev
    apt-get install -y libshout3-dev libmpg123-dev libmp3lame-dev yasm nasm libsndfile1-dev libuv1-dev libvpx-dev
    apt-get install -y libavformat-dev libswscale-dev libvlc-dev python3-distutils
    # Bullseye specific
    apt-get install -y libvpx6 swig4.0

    cwd=$(pwd)

    # sofia-sip
    cd /usr/src
    #git clone https://github.com/freeswitch/sofia-sip.git sofia-sip
    wget https://github.com/freeswitch/sofia-sip/archive/refs/tags/v${sofia_version}.tar.gz
    tar -xvf v${sofia_version}.tar.gz
    rm -R sofia-sip
    mv sofia-sip-$sofia_version sofia-sip
    cd sofia-sip
    sh autogen.sh
    ./configure
    make
    make install

    # spandsp
    cd /usr/src
    git clone https://github.com/freeswitch/spandsp.git spandsp
    cd spandsp
    sh autogen.sh
    ./configure
    make
    make install
    ldconfig

    # Freeswitch
    cd /usr/src
    wget https://github.com/signalwire/freeswitch/archive/refs/tags/v${freeswitch_version}.tar.gz
    tar -xvf v${freeswitch_version}.tar.gz
    rm -R freeswitch
    mv freeswitch-$freeswitch_version freeswitch
    cd freeswitch

    # disable mod_signalwire, mod_skinny, mod_verto and mod_lua from building
    sed -i "s/applications\/mod_signalwire/#applications\/mod_signalwire/g" build/modules.conf.in
    sed -i "s/endpoints\/mod_skinny/#endpoints\/mod_skinny/g" build/modules.conf.in
    sed -i "s/endpoints\/mod_verto/#endpoints\/mod_verto/g" build/modules.conf.in
    sed -i "s/languages\/mod_lua/languages\/mod_lua/g" build/modules.conf.in

    # enable some other modules that are disabled by default
    sed -i "s/#applications\/mod_callcenter/applications\/mod_callcenter/g" build/modules.conf.in
    sed -i "s/#applications\/mod_cidlookup/applications\/mod_cidlookup/g" build/modules.conf.in
    sed -i "s/#applications\/mod_memcache/applications\/mod_memcache/g" build/modules.conf.in
    sed -i "s/#applications\/mod_curl/applications\/mod_curl/g" build/modules.conf.in
    sed -i "s/#applications\/mod_nibblebill/applications\/mod_nibblebill/g" build/modules.conf.in

    sed -i "s/#languages\/mod_python3/languages\/mod_python3/g" build/modules.conf.in

    sed -i "s/#xml_int\/mod_xml_curl/xml_int\/mod_xml_curl/g" build/modules.conf.in

    sed -i "s/#formats\/mod_shout/formats\/mod_shout/g" build/modules.conf.in

    sed -i "s/#say\/mod_say_es/say\/mod_say_es/g" build/modules.conf.in
    sed -i "s/#say\/mod_say_fr/say\/mod_say_fr/g" build/modules.conf.in

    # Configure the build
    ./configure -C --enable-portable-binary --disable-dependency-tracking --prefix=/usr \
    --localstatedir=/var --sysconfdir=/etc --with-openssl --enable-core-pgsql-support

    # compile and install
    make
    make install
    make sounds-install moh-install
    make hd-sounds-install hd-moh-install
    make cd-sounds-install cd-moh-install

    #move the music into music/default directory
    mv /usr/share/freeswitch/sounds/music/*000 /home/django-pbx/media/fs/music/default
    chown -R django-pbx:django-pbx /home/django-pbx/media/fs/music/*

    # Bcg_729
    cd /usr/src
    git clone https://github.com/xadhoom/mod_bcg729.git
    #cd mod_bcg729
    #make && make install

    cd $cwd
fi

# move recordings and voicemail
rmdir /var/lib/freeswitch/recordings
ln -s /home/django-pbx/media/fs/recordings /var/lib/freeswitch/recordings
rm -rf /var/lib/freeswitch/storage/voicemail
ln -s /home/django-pbx/media/fs/voicemail /var/lib/freeswitch/storage/voicemail

# setup /etc/freeswitch/directory
cp -r /etc/freeswitch/* /etc/freeswitch.orig
cp /home/django-pbx/pbx/switch/resources/templates/conf/freeswitch.xml /etc/freeswitch
cp -r /home/django-pbx/pbx/switch/resources/templates/conf/* /home/django-pbx/freeswitch
chown -R django-pbx:django-pbx /etc/freeswitch
mkdir -p /home/django-pbx/freeswitch
chown -R django-pbx:django-pbx /home/django-pbx/freeswitch


#Sudoers
#======================

visudo -c -q -f /home/django-pbx/pbx/pbx/resources/etc/sudoers.d/django_pbx_sudo_inc && \
cp /home/django-pbx/pbx/pbx/resources/etc/sudoers.d/django_pbx_sudo_inc /etc/sudoers.d/django_pbx_sudo_inc

if [ -f "/etc/sudoers.d/django_pbx_sudo_inc" ]; then
   chmod 600 /etc/sudoers.d/django_pbx_sudo_inc
   chown root:root /etc/sudoers.d/django_pbx_sudo_inc
   echo "Django PBX sudo installed OK"
fi

#Scripts 
#=====================

cp /home/django-pbx/pbx/pbx/resources/django-pbx/crontab /home/django-pbx
cp /home/django-pbx/pbx/pbx/resources/root/* /root
cp /home/django-pbx/pbx/pbx/resources/usr/local/bin/* /usr/local/bin
cp -r /home/django-pbx/pbx/pbx/resources/usr/share/freeswitch/scripts/* /usr/share/freeswitch/scripts


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


#set up webserver
#================

apt-get install -y nginx
apt-get install -y uwsgi
apt-get install -y uwsgi-plugin-python3

#remove the default site
rm /etc/nginx/sites-enabled/default

#add the static files directory
mkdir -p /var/www/static
chown django-pbx:django-pbx /var/www/static

cat << EOF > /etc/uwsgi/apps-available/djangopbx.ini
[uwsgi]
plugins-dir = /usr/lib/uwsgi/plugins/
plugin = python39
socket = /home/django-pbx/pbx/django-pbx.sock
uid = django-ipx
gid = www-data
chmod-socket = 664
chdir = /home/django-pbx/pbx/
wsgi-file = pbx/wsgi.py
processes = 8
threads = 4
stats = 127.0.0.1:9191
enable-threads = true
harakiri = 120
vacuum = true

EOF

ln -s /etc/uwsgi/apps-available/djangopbx.ini /etc/uwsgi/apps-enabled/djangopbx.ini


# get the IP used to talk to the Internet
my_ip=`ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'`
# enable DjangoPBX nginx config
cat << EOF > /etc/nginx/sites-available/djangopbx
# the upstream component nginx needs to connect to
upstream django {
    server unix:///home/django-pbx/pbx/django-pbx.sock; # for a file socket
    #server 127.0.0.1:8001; # for a web port socket (we will use this first)
}

server {
    listen 127.0.0.1:80;
    server_name _;

    client_max_body_size 80M;
    client_body_buffer_size 128k;

    location / {
        include     uwsgi_params;
        uwsgi_pass  django;
    }

}

server {
    listen ${my_ip}:80;
    server_name _;

    return 301 https://$host$request_uri;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    client_max_body_size 80M;
    client_body_buffer_size 128k;

}

server {
    listen ${my_ip}:443 ssl;
    server_name djangoipx;
    #ssl                     on;
    ssl_certificate         /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key     /etc/ssl/private/ssl-cert-snakeoil.key;
    ssl_protocols           TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers             HIGH:!ADH:!MD5:!aNULL;
    #ssl_dhparam

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    client_max_body_size 80M;
    client_body_buffer_size 128k;

    location /static {
        alias /var/www/static;
    }

    # Finally, send all non media/static requests to the Django server.
    location / {
        include     uwsgi_params;
        uwsgi_pass  django;
    }

}

EOF

ln -s /etc/nginx/sites-available/djangopbx /etc/nginx/sites-enabled/djangopbx

service nginx stop
service uwsgi stop

service uwsgi start
service nginx start


cwd=$(pwd)
cd /tmp

# Perform initial steps on new DjangoPBX Django application
echo "You are about to create a superuser to manage DjangoPBX, please use a strong, secure password."
read -p "Press any key to continue " -n 1 -r
echo ""
sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py migrate'
sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py createsuperuser'
sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py collectstatic'

read -p "Load Default Access controls? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch accesscontrol.json'
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch accesscontrolnode.json'
fi
read -p "Load Default Email Templates? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch emailtemplate.json'
fi
read -p "Load Default Modules data? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch modules.json'
fi
read -p "Load Default SIP profiles? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch sipprofile.json'
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch sipprofiledomain.json'
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch sipprofilesetting.json'
fi
read -p "Load Default Switch Variables? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch switchvariable.json'
fi
read -p "Load Default Musin on Hold data? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app musiconhold musinonhold.json'
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app musiconhold mohfile.json'
fi
read -p "Load Default Settings? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py loaddata --app tenants defaultsetting.json'
fi
read -p "Load Menu Defaults? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 manage.py menudefaults'
fi


cd $cwd

#Set up passwords etc.
#======================

sed -i "s/^SECRET_KEY\s=.*/SECRET_KEY ='${system_password}'/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/postgres-insecure-abcdef9876543210\s=.*/${database_password}/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/^DEBUG\s=.*/DEBUG = False/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/^ALLOWED_HOSTS\s=.*/ALLOWED_HOSTS = ['127.0.0.1', '${my_ip}']/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/postgres-insecure-abcdef9876543210\s=.*/${database_password}/g" /usr/share/freeswitch/scripts/resources/db/pbxdb.py


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
echo " "
echo "Make sure /etc/nftables.conf is correct for you!!"
echo "By default you must put your IP address in the white list to access ssh on port 22."
echo " "
echo "When you are sure that you will NOT LOCK YOURSELF OUT, issue the following command:"
echo "systemctl enable nftables"
echo " "
echo "Thankyou for using DjangoPBX"
echo " "
