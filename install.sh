#!/bin/bash
#
#    DjangoPBX
#
#    MIT License
#
#    Copyright (c) 2016 - 2024 Adrian Fretwell <adrian@djangopbx.com>
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
rabbitmq_password=random

# Domain name, use leading dot for wildcard
domain_name=.mydomain.com

# Default domain name, this domain will be automaticall created for you
# and the superuser will be assigned to it.
default_domain_name=admin.mydomain.com

# FreeSWITCH method can be src or pkg
#   if pkg is seclected then you must frovide a signalwire token.
freeswitch_method=src
signalwire_token=None
# FreeSWITCH building options
use_no_of_cpus="no"
mod_signalwire="no"
mod_skinny="no"
mod_verto="no"

# Software versions
freeswitch_version=1.10.11
sofia_version=1.13.17

# Loading Default Data
#  if set to "yes", default data sets will be loaded without prompting.
skip_prompts="no"

# Monitoring Options
install_nagios_nrpe="no"

# Scaling and Clustering Options
freeswitch_core_in_postgres="no"
use_rabbitmq_broker="no"
install_rabbitmq_local="no"
install_postgresql_local="yes"
install_freeswitch_local="yes"
install_djangopbx_local="yes"
install_remote_event_receiver="no"
core_sequence_increment=10
core_sequence_start=1001

########################### Configuration End ################################
##############################################################################

###################### Define Installer Functions ############################
pbx_prompt() {
    if [[ $1 == "yes" ]]
    then
        REPLY=Y
    else
        echo -e $c_yellow
        read -p "$2" -n 1 -r
        echo -e $c_clear
    fi
}

######################## Define Color variables ##############################
c_red='\033[1;31m'
c_green='\033[1;32m'
c_yellow='\033[1;33m'
c_blue='\033[1;34m'
c_cyan='\033[1;36m'
c_white='\033[1;37m'
c_clear='\033[0m'

########################## Start of Installers ###############################
echo -e $c_cyan
cat << 'EOF'

 ____  _                         ____  ______  __
|  _ \(_) __ _ _ __   __ _  ___ |  _ \| __ ) \/ /
| | | | |/ _` | '_ \ / _` |/ _ \| |_) |  _ \\  /
| |_| | | (_| | | | | (_| | (_) |  __/| |_) /  \
|____// |\__,_|_| |_|\__, |\___/|_|   |____/_/\_\
    |__/             |___/

EOF
if [ "`id -u`" -gt 0 ]; then
    echo -e "${c_red}You must be logged in as root or su - root to run this installer.${c_clear}"
    exit 1
fi
term_user=$(logname)

if [[ $term_user != "root" ]]
then
echo -e $c_green
cat << EOF
If you have used su to aquire root privileges, please make sure you
have also aquired the correct PATH environment for root.
It is strongly recommended that you use su - root rather than plain su.

If you are unsure, quit the installer and check your PATH variable, we
would expect to see at least one reference to /sbin or /usr/sbin in your PATH.
Your PATH is shown below:

EOF
echo -en $c_white 
echo $PATH
echo
fi
pbx_prompt n "Install DjangoPBX - Are you sure (y/n)? "
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
    echo -e "${c_red}This installer is for use on Debian systems only.${c_clear}"
    exit 1
fi

if [[ $os_codename != "bookworm" ]]
then
    echo -e "${c_red}WARNING: This installer is only designed and tested with Bookworm.${c_yellow}"
    read -p "Do you want to continue? " -n 1 -r
    echo -e $c_clear
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 1
    fi
fi

if [[ $database_password == "random" ]]
then
    echo "Generating random database pasword... "
    database_password=$(cat /proc/sys/kernel/random/uuid | md5sum | head -c 20)
fi

if [[ $system_password == "random" ]]
then
    echo "Generating random system pasword... "
    system_password=$(cat /proc/sys/kernel/random/uuid)
fi

echo "Database Password" >> /root/djangopbx-passwords.txt
echo $database_password >> /root/djangopbx-passwords.txt
echo "System Password" >> /root/djangopbx-passwords.txt
echo $system_password >> /root/djangopbx-passwords.txt


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
apt-get install -y unzip
apt-get install -y m4
apt-get install -y ntp
apt-get install -y sox
apt-get install -y lame
apt-get install -y wget
apt-get install -y htop
apt-get install -y curl memcached haveged apt-transport-https
apt-get install -y libpq-dev
apt-get install -y python3-pip
apt-get install -y python3-dev
apt-get install -y python3-daemon
apt-get install -y sqlite3


echo -e "${c_green}You are about to create a new user called django-pbx, please use a strong, secure password."
echo -e $c_yellow
read -p "Press any key to continue " -n 1 -r
echo -e $c_clear
adduser django-pbx
mkdir -p /home/django-pbx/tmp
chmod 755 /home/django-pbx
chown django-pbx:django-pbx /home/django-pbx/tmp

mkdir -p /home/django-pbx/media/fs/music/default
mkdir -p /home/django-pbx/media/fs/recordings
mkdir -p /home/django-pbx/media/fs/voicemail
chown -R django-pbx:django-pbx /home/django-pbx/media
mkdir -p /home/django-pbx/cache
chown django-pbx:django-pbx /home/django-pbx/cache
mkdir -p /home/django-pbx/freeswitch
chown django-pbx:django-pbx /home/django-pbx/freeswitch
chmod 775 /home/django-pbx/freeswitch
mkdir -p /home/django-pbx/.ssh
chown django-pbx:django-pbx /home/django-pbx/.ssh
touch /home/django-pbx/.ssh/authorized_keys
chmod 600 /home/django-pbx/.ssh/authorized_keys
chown django-pbx:django-pbx /home/django-pbx/.ssh/authorized_keys

cwd=$(pwd)
cd /tmp
# clone the DjangoPBX application
sudo -u django-pbx bash -c 'cd /home/django-pbx && git clone https://github.com/djangopbx/djangopbx.git pbx'
sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && git config pull.rebase false'
cd $cwd


###############################################
# Firewall
###############################################
#Since Buster, Debian has nft dy befault, we now use this rather than the legacy iptables.

echo " "
echo "Removing UFW is it exists..."
apt purge ufw
echo " "
echo "Installing nftables..."
apt-get install -y nftables
apt-get install -y python3-nftables

cp /home/django-pbx/pbx/pbx/resources/etc/nftables.conf /etc/nftables.conf
chmod 755 /etc/nftables.conf
chown root:root /etc/nftables.conf
echo -e $c_green
cat << EOF
A default firewall configuration has been installed.
It is strongly recommended that you add your public IP address to one of
the white-list sets.  They currently contain place holder RFC1918 addresses.

If you are connected via ssh or similar your IP address should be shown in
the output of the who am i command shown below:

EOF
echo -en $c_white
who am i
echo -e $c_green
cat << EOF
For example, if you are connecting from an IPv4 address, then you would edit
the following line: define ipv4_white_list = {}
and add your IP address between the curly braces.
EOF
net_interface=$(ip r | grep default | awk '/default/ {print $5}')
if [[ $net_interface != "eth0" ]]
then
    sed -i "s/eth0/${net_interface}/g" /etc/nftables.conf
fi

pbx_prompt n "Edit nftables.conf now? "
if [[ $REPLY =~ ^[Yy]$ ]]
then
nano /etc/nftables.conf
fi
cp /etc/nftables.conf /etc/nftables.conf.orig

###############################################
# PostgreSQL
###############################################
if [[ $install_postgresql_local == "yes" ]]
then
    apt-get install -y postgresql

    cwd=$(pwd)
    cd /tmp

    # add the databases, users and grant permissions to them
    sudo -u postgres psql -c "CREATE DATABASE djangopbx;";
    sudo -u postgres psql -c "CREATE DATABASE freeswitch;";
    sudo -u postgres psql -c "CREATE ROLE djangopbx WITH SUPERUSER LOGIN PASSWORD '$database_password';"
    sudo -u postgres psql -c "CREATE ROLE freeswitch WITH SUPERUSER LOGIN PASSWORD '$database_password';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE djangopbx to djangopbx;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to freeswitch;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE freeswitch to djangopbx;"
    sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'
    # create the freeswitch schema
    sudo -u postgres psql -d freeswitch -1 -f /home/django-pbx/pbx/switch/resources/templates/sql/switch.sql
    cd $cwd
fi

###############################################
# FreeSWITCH
###############################################
if [[ $install_freeswitch_local == "yes" ]]
then
 if [[ $freeswitch_method == "pkg" ]]
 then
    wget --http-user=signalwire --http-password=$signalwire_token -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg
    echo "machine freeswitch.signalwire.com login signalwire password $signalwire_token" > /etc/apt/auth.conf
    echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list
    echo "deb-src [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list

    apt-get update
    apt-get install -y freeswitch-meta-bare freeswitch-conf-vanilla freeswitch-mod-commands freeswitch-mod-console freeswitch-mod-logfile
    apt-get install -y freeswitch-lang-en freeswitch-mod-say-en freeswitch-sounds-en-us-callie
 #   apt-get install -y freeswitch-sounds-es-ar-mario freeswitch-mod-say-es freeswitch-mod-say-es-ar
 #   apt-get install -y freeswitch-sounds-fr-ca-june freeswitch-mod-say-fr
    apt-get install -y freeswitch-mod-enum freeswitch-mod-cdr-csv freeswitch-mod-event-socket freeswitch-mod-sofia freeswitch-mod-sofia-dbg freeswitch-mod-loopback
    apt-get install -y freeswitch-mod-conference freeswitch-mod-db freeswitch-mod-dptools freeswitch-mod-expr freeswitch-mod-fifo freeswitch-mod-httapi
    apt-get install -y freeswitch-mod-hash freeswitch-mod-esl freeswitch-mod-esf freeswitch-mod-fsv freeswitch-mod-valet-parking freeswitch-mod-dialplan-xml freeswitch-dbg
    apt-get install -y freeswitch-mod-sndfile freeswitch-mod-native-file freeswitch-mod-local-stream freeswitch-mod-tone-stream freeswitch-meta-mod-say
    apt-get install -y freeswitch-mod-lua
    apt-get install -y freeswitch-mod-python3
    apt-get install -y freeswitch-mod-xml-cdr freeswitch-mod-verto freeswitch-mod-callcenter freeswitch-mod-rtc freeswitch-mod-png freeswitch-mod-json-cdr freeswitch-mod-shout
    apt-get install -y freeswitch-mod-sms freeswitch-mod-sms-dbg freeswitch-mod-cidlookup freeswitch-mod-memcache
    apt-get install -y freeswitch-mod-imagick freeswitch-mod-tts-commandline freeswitch-mod-directory
    apt-get install -y freeswitch-mod-av freeswitch-mod-flite freeswitch-mod-distributor freeswitch-meta-codecs
    apt-get install -y freeswitch-mod-pgsql
    apt-get install -y freeswitch-mod-curl
    apt-get install -y freeswitch-mod-xml-curl
    apt-get install -y freeswitch-music-default
    apt-get install -y freeswitch-mod-voicemail
    apt-get install -y freeswitch-mod-http-cache
    apt-get install -y freeswitch-mod-amqp
    apt-get install -y libyuv-dev

    # remove the music package to protect music on hold from package updates
    mv /usr/share/freeswitch/sounds/music/* /home/django-pbx/media/fs/music/default
    apt-get remove -y freeswitch-music-default
    ln -s /home/django-pbx/media/fs/music /usr/share/freeswitch/sounds/music

    chown -R django-pbx:django-pbx /home/django-pbx/media/fs/music/*

    # Get mod_bcg729.so

    wget -O /usr/lib/freeswitch/mod/mod_bcg729.so https://raw.githubusercontent.com/djangopbx/djangopbx-install.sh/master/binaries/mod_bcg729.so
 fi

 if [[ $freeswitch_method == "src" ]]
 then
    apt-get install -y gdb
    apt-get install -y autoconf automake devscripts g++ git-core libncurses5-dev libtool make libjpeg-dev
    apt-get install -y pkg-config flac  libgdbm-dev libdb-dev gettext equivs mlocate dpkg-dev libpq-dev
    apt-get install -y liblua5.2-dev libtiff5-dev libperl-dev libcurl4-openssl-dev libsqlite3-dev libpcre3-dev
    apt-get install -y devscripts libspeexdsp-dev libspeex-dev libldns-dev libedit-dev libopus-dev libmemcached-dev
    apt-get install -y libshout3-dev libmpg123-dev libmp3lame-dev yasm nasm libsndfile1-dev libuv1-dev libvpx-dev
    apt-get install -y libavformat-dev libswscale-dev libvlc-dev python3-distutils
    apt-get install -y cmake
    apt-get install -y uuid-dev
    # Bookworm specific
    apt-get install -y libvpx7 swig4.0
    apt-get install -y librabbitmq4
    apt-get install -y librabbitmq-dev

    cwd=$(pwd)

    # libks
    if [[ $mod_signalwire == "yes" ]]
    then
        cd /usr/src
        git clone https://github.com/signalwire/libks.git libks
        cd libks
        cmake .
        if [[ $use_no_of_cpus == "yes" ]]
        then
            make -j $(getconf _NPROCESSORS_ONLN)
        else
            make
        fi
        make install
        export C_INCLUDE_PATH=/usr/include/libks
    fi

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
    if [[ $use_no_of_cpus == "yes" ]]
    then
        make -j $(getconf _NPROCESSORS_ONLN)
    else
        make
    fi
    make install

    # spandsp
    cd /usr/src
    git clone https://github.com/freeswitch/spandsp.git spandsp
    cd spandsp
    git reset --hard 0d2e6ac65e0e8f53d652665a743015a88bf048d4
    sh autogen.sh
    ./configure
    if [[ $use_no_of_cpus == "yes" ]]
    then
        make -j $(getconf _NPROCESSORS_ONLN)
    else
        make
    fi
    make install
    ldconfig

    # Freeswitch
    cd /usr/src
    wget https://github.com/signalwire/freeswitch/archive/refs/tags/v${freeswitch_version}.tar.gz
    tar -xvf v${freeswitch_version}.tar.gz
    rm -R freeswitch
    mv freeswitch-$freeswitch_version freeswitch
    cd freeswitch

    # disable or enable mod_signalwire, mod_skinny, and mod_verto from building
    if [[ $mod_signalwire == "yes" ]]
    then
        sed -i "s/#applications\/mod_signalwire/applications\/mod_signalwire/g" build/modules.conf.in
    else
        sed -i "s/applications\/mod_signalwire/#applications\/mod_signalwire/g" build/modules.conf.in
    fi
    if [[ $mod_skinny == "yes" ]]
    then
        sed -i "s/#endpoints\/mod_skinny/endpoints\/mod_skinny/g" build/modules.conf.in
    else
        sed -i "s/endpoints\/mod_skinny/#endpoints\/mod_skinny/g" build/modules.conf.in
    fi
    if [[ $mod_verto == "yes" ]]
    then
        sed -i "s/#endpoints\/mod_verto/endpoints\/mod_verto/g" build/modules.conf.in
    else
        sed -i "s/endpoints\/mod_verto/#endpoints\/mod_verto/g" build/modules.conf.in
    fi

    # enable some other modules that are disabled by default
    sed -i "s/#applications\/mod_callcenter/applications\/mod_callcenter/g" build/modules.conf.in
    sed -i "s/#applications\/mod_cidlookup/applications\/mod_cidlookup/g" build/modules.conf.in
    sed -i "s/#applications\/mod_memcache/applications\/mod_memcache/g" build/modules.conf.in
    sed -i "s/#applications\/mod_curl/applications\/mod_curl/g" build/modules.conf.in
    sed -i "s/#applications\/mod_nibblebill/applications\/mod_nibblebill/g" build/modules.conf.in
    sed -i "s/#applications\/mod_http_cache/applications\/mod_http_cache/g" build/modules.conf.in

    sed -i "s/#languages\/mod_python3/languages\/mod_python3/g" build/modules.conf.in

    sed -i "s/#xml_int\/mod_xml_curl/xml_int\/mod_xml_curl/g" build/modules.conf.in
    sed -i "s/#event_handlers\/mod_amqp/event_handlers\/mod_amqp/g" build/modules.conf.in

    sed -i "s/#formats\/mod_shout/formats\/mod_shout/g" build/modules.conf.in

    sed -i "s/#say\/mod_say_es/say\/mod_say_es/g" build/modules.conf.in
    sed -i "s/#say\/mod_say_fr/say\/mod_say_fr/g" build/modules.conf.in

    # Configure the build
    ./bootstrap.sh -j
    ./configure -C --enable-portable-binary --disable-dependency-tracking --prefix=/usr \
    --localstatedir=/var --sysconfdir=/etc --with-openssl --enable-core-pgsql-support

    # compile and install
    if [[ $use_no_of_cpus == "yes" ]]
    then
        make -j $(getconf _NPROCESSORS_ONLN)
    else
        make
    fi
    make install
    make sounds-install moh-install
    make hd-sounds-install hd-moh-install
    make cd-sounds-install cd-moh-install

    #move the music into music/default directory
    mv /usr/share/freeswitch/sounds/music/*000 /home/django-pbx/media/fs/music/default
    rm -rf /usr/share/freeswitch/sounds/music
    chown -R django-pbx:django-pbx /home/django-pbx/media/fs/music/*
    ln -s /home/django-pbx/media/fs/music /usr/share/freeswitch/sounds/music

    # Bcg_729
    pbx_prompt n "Build and install mod_bcg729? "
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        apt-get install -y cmake
        cd /usr/src
        git clone https://github.com/xadhoom/mod_bcg729.git
        cd mod_bcg729
        if [[ $use_no_of_cpus == "yes" ]]
        then
            make -j $(getconf _NPROCESSORS_ONLN)
        else
            make
        fi
        make install
    fi

    cd $cwd
 fi

 # move recordings and voicemail
 rmdir /var/lib/freeswitch/recordings
 ln -s /home/django-pbx/media/fs/recordings /var/lib/freeswitch/recordings
 mkdir -p /var/lib/freeswitch/storage
 rm -rf /var/lib/freeswitch/storage/voicemail
 ln -s /home/django-pbx/media/fs/voicemail /var/lib/freeswitch/storage/voicemail
 mkdir -p /var/lib/freeswitch/storage/voicemail/default
 chown django-pbx:django-pbx /var/lib/freeswitch/storage/voicemail/default

 # setup /etc/freeswitch/directory
 # just incase it does not exist for any reason
 mkdir -p /etc/freeswitch
 cp -r /etc/freeswitch/ /home/django-pbx/freeswitch/
 mv /etc/freeswitch /etc/freeswitch.orig
 rm -r /home/django-pbx/freeswitch/autoload_configs
 rm -r /home/django-pbx/freeswitch/dialplan
 rm -r /home/django-pbx/freeswitch/chatplan
 rm -r /home/django-pbx/freeswitch/directory
 rm -r /home/django-pbx/freeswitch/sip_profiles
 cp -r /home/django-pbx/pbx/switch/resources/templates/conf/* /home/django-pbx/freeswitch
 chown -R django-pbx:django-pbx /home/django-pbx/freeswitch

 # setup a directory for the voicemail DB that will not get lifted into a RAM disk
 mkdir -p /var/lib/freeswitch/vm_db
 chown -R django-pbx:django-pbx /var/lib/freeswitch/vm_db


 cat << \EOF > /lib/systemd/system/freeswitch.service
;;;;; Author: Travis Cross <tc@traviscross.com>
;;;;; Modified: Adrian Fretwell <adrian@djangopbx.com>

[Unit]
Description=freeswitch
Wants=network-online.target
Requires=network.target local-fs.target postgresql.service
After=network.target network-online.target local-fs.target postgresql.service memcached.service nginx.service uwsgi.service

[Service]
; service
Type=forking
PIDFile=/run/freeswitch/freeswitch.pid
Environment="DAEMON_OPTS=-nonat"
Environment="USER=django-pbx"
Environment="GROUP=django-pbx"
EnvironmentFile=-/etc/default/freeswitch
ExecStartPre=/bin/mkdir -p /var/run/freeswitch/
ExecStartPre=/bin/chown -R ${USER}:${GROUP} /var/lib/freeswitch /var/log/freeswitch /home/django-pbx/freeswitch /usr/share/freeswitch /var/run/freeswitch
ExecStart=/usr/bin/freeswitch -u ${USER} -g ${GROUP} -ncwait  -conf /home/django-pbx/freeswitch -log /var/log/freeswitch -db /var/lib/freeswitch/db -run /var/run/freeswitch ${DAEMON_OPTS}
TimeoutSec=45s
Restart=always
; exec
;User=${USER}
;Group=${GROUP}
LimitCORE=infinity
LimitNOFILE=100000
LimitNPROC=60000
LimitSTACK=250000
LimitRTPRIO=infinity
LimitRTTIME=infinity
IOSchedulingClass=realtime
IOSchedulingPriority=2
CPUSchedulingPolicy=rr
CPUSchedulingPriority=89
UMask=0007
NoNewPrivileges=false

; alternatives which you can enforce by placing a unit drop-in into
; /etc/systemd/system/freeswitch.service.d/*.conf:
;
; User=freeswitch
; Group=freeswitch
; ExecStart=
; ExecStart=/usr/bin/freeswitch -ncwait -nonat -rp
;
; empty ExecStart is required to flush the list.
;
; if your filesystem supports extended attributes, execute
;   setcap 'cap_net_bind_service,cap_sys_nice=+ep' /usr/bin/freeswitch
; this will also allow socket binding on low ports
;
; otherwise, remove the -rp option from ExecStart and
; add these lines to give real-time priority to the process:
;
; PermissionsStartOnly=true
; ExecStartPost=/bin/chrt -f -p 1 $MAINPID
;
; execute "systemctl daemon-reload" after editing the unit files.

[Install]
WantedBy=multi-user.target

EOF
 if [[ $install_postgresql_local == "no" ]]
 then
    sed -i "s/\spostgresql.service//g" /lib/systemd/system/freeswitch.service
 fi
 if [[ $install_djangopbx_local == "no" ]]
 then
    sed -i "s/\snginx.service//g" /lib/systemd/system/freeswitch.service
    sed -i "s/\suwsgi.service//g" /lib/systemd/system/freeswitch.service
 fi

 if [[ $freeswitch_core_in_postgres == "no" ]]
 then
    pbx_prompt n "Move FreeSWITCH Sqlite files to RAM disk? "
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        mkdir -p /var/lib/freeswitch/db
        chmod 777 /var/lib/freeswitch/db
        chown -R django-pbx:django-pbx /var/lib/freeswitch/db
        echo "# DjangoPBX for Freeswitch DB" >> /etc/fstab
        echo "tmpfs /var/lib/freeswitch/db tmpfs defaults 0 0" >> /etc/fstab
        mount -t tmpfs -o size=64m fsramdisk /var/lib/freeswitch/db
    fi
 fi
fi

###############################################
# Sudoers
###############################################

visudo -c -q -f /home/django-pbx/pbx/pbx/resources/etc/sudoers.d/django_pbx_sudo_inc && \
cp /home/django-pbx/pbx/pbx/resources/etc/sudoers.d/django_pbx_sudo_inc /etc/sudoers.d/django_pbx_sudo_inc

if [ -f "/etc/sudoers.d/django_pbx_sudo_inc" ]; then
   chmod 600 /etc/sudoers.d/django_pbx_sudo_inc
   chown root:root /etc/sudoers.d/django_pbx_sudo_inc
   echo "Django PBX sudo installed OK"
fi


###############################################
# Scripts
###############################################

cp /home/django-pbx/pbx/pbx/resources/home/django-pbx/crontab /home/django-pbx
chown django-pbx:django-pbx /home/django-pbx/crontab
cp /home/django-pbx/pbx/pbx/resources/root/* /root
cp /home/django-pbx/pbx/pbx/resources/usr/local/bin/* /usr/local/bin
mkdir -p /usr/share/freeswitch/scripts
cp -r /home/django-pbx/pbx/pbx/resources/usr/share/freeswitch/scripts/* /usr/share/freeswitch/scripts
chown -R django-pbx:django-pbx /usr/share/freeswitch/scripts


###############################################
# Set up Django
###############################################

apt-get install -y python3-venv
sudo -u django-pbx bash -c 'cd /home/django-pbx/pbx && python3 -m venv --system-site-packages ~/envdpbx'
echo "# Automatically activate the DjangoPBX venv if available" >> /home/django-pbx/.bashrc
echo "if [ -f ~/envdpbx/bin/activate ]; then" >> /home/django-pbx/.bashrc
echo "    source ~/envdpbx/bin/activate" >> /home/django-pbx/.bashrc
echo "fi" >> /home/django-pbx/.bashrc

pbx_prompt n "Use requirements.txt to install dependencies (recommended)? "
if [[ $REPLY =~ ^[Yy]$ ]]
then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install -r /home/django-pbx/pbx/requirements.txt'
else
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install psycopg2'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install Django'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install django-static-fontawesome'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install django-bootstrap-static'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install djangorestframework'

    # Markdown support for the browsable API.
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install markdown'

    # Filtering support
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install django-filter'

    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install django-tables2'

    # import export data in Admin
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install django-import-export'

    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install django-ace'

    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install distro'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install psutil'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install lxml'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install pymemcache'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install xmltodict'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install regex'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install python-ipware'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install pika'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && pip3 install paramiko'
fi

if [[ $install_djangopbx_local == "yes" ]]
then

 ###############################################
 # Set up Webserver
 ###############################################

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
plugin = python3
socket = /home/django-pbx/pbx/django-pbx.sock
uid = django-pbx
gid = www-data
chmod-socket = 666
chdir = /home/django-pbx/pbx/
wsgi-file = pbx/wsgi.py
processes = 8
threads = 4
stats = 127.0.0.1:9191
enable-threads = true
harakiri = 120
vacuum = true
home = /home/django-pbx/envdpbx

EOF

 ln -s /etc/uwsgi/apps-available/djangopbx.ini /etc/uwsgi/apps-enabled/djangopbx.ini
 sed -i "s/www-data/django-pbx/g" /etc/nginx/nginx.conf

 cat << EOF > /etc/uwsgi/apps-available/fs_config.ini
[uwsgi]
plugins-dir = /usr/lib/uwsgi/plugins/
plugin = python3
http-socket = 127.0.0.1:8008
uid = django-pbx
gid = www-data
chmod-socket = 666
chdir = /home/django-pbx/pbx/
wsgi-file = pbx/wsgi.py
processes = 8
threads = 4
stats = 127.0.0.1:9192
enable-threads = true
harakiri = 120
vacuum = true
home = /home/django-pbx/envdpbx

EOF

 ln -s /etc/uwsgi/apps-available/fs_config.ini /etc/uwsgi/apps-enabled/fs_config.ini


 # get the IP used to talk to the Internet
 my_ip=`ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'`
 echo -e $c_green
 echo "The installer has guessed your public IP address as the following:"
 echo -en $c_white
 echo $my_ip
 echo -e $c_green
 echo "If this is not what you want to use then please edit:"
 echo "/etc/nginx/sites-available/djangopbx"
 echo "After the installation has completed."
 pbx_prompt n "Press any key to continue "
 # enable DjangoPBX nginx config
 my_redirect='https://$host$request_uri;'
 cat << EOF > /etc/nginx/sites-available/djangopbx
# the upstream component nginx needs to connect to
upstream django {
    server unix:///home/django-pbx/pbx/django-pbx.sock; # for a file socket
    #server 127.0.0.1:8001; # for a web port socket (we will use this first)
}

server {
    listen 127.0.0.1:8009;
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

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    client_max_body_size 80M;
    client_body_buffer_size 128k;

    location /fsmedia {
        alias /home/django-pbx/media/fs;
        allow 127.0.0.1;
        deny  all;
    }

    location / {
        return 301 https://$host$request_uri;
    }

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

    location /favicon.ico {
        alias /var/www/static/favicon.ico;
    }

    location /static {
        alias /var/www/static;
    }

    location /fsmedia {
        alias /home/django-pbx/media/fs;
        allow 127.0.0.1;
        deny  all;
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
fi


###############################################
# RabbitMQ Local
###############################################
if [[ $install_rabbitmq_local == "yes" ]]
then
    apt-get install -y rabbitmq-server
    rabbitmq-plugins enable rabbitmq_management
    if [[ $rabbitmq_password == "random" ]]
    then
        echo "Generating random rabbitMQ pasword... "
        rabbitmq_password=$(cat /proc/sys/kernel/random/uuid | md5sum | head -c 20)
    fi
    echo "Waiting for RabbitMQ..."
    /usr/bin/sleep 5
    rabbitmqctl change_password guest $rabbitmq_password
    rabbitmqctl add_user djangopbx $rabbitmq_password
    rabbitmqctl set_permissions -p / "djangopbx" ".*" ".*" ".*"
    mv /etc/rabbitmq/rabbitmq.conf /etc/rabbitmq/rabbitmq.conf.orig
    cat << \EOF > /etc/rabbitmq/rabbitmq.conf
## Core Settings
listeners.tcp.default            = 5672

## Default Users
#
default_user = guest
default_pass = djangopbx-insecure
loopback_users.guest = true

## TLS configuration.
#
listeners.ssl.default            = 5671
ssl_options.verify               = verify_peer
ssl_options.fail_if_no_peer_cert = false
# ssl_options.cacertfile           = /path/to/cacert.pem
ssl_options.certfile             = /etc/ssl/certs/ssl-cert-snakeoil.pem
ssl_options.keyfile              = /etc/ssl/private/ssl-cert-snakeoil.key

## Management section
#
management.tcp.port       = 15672
management.ssl.port       = 15671
# management.ssl.cacertfile = /path/to/cacert.pem
management.ssl.certfile   = /etc/ssl/certs/ssl-cert-snakeoil.pem
management.ssl.keyfile    = /etc/ssl/private/ssl-cert-snakeoil.key

## AHF - Core server variables for production
vm_memory_high_watermark.relative = 0.6
disk_free_limit.absolute = 8G
log.file.level = warning

EOF
fi
echo "RabbitMQ Password" >> /root/djangopbx-passwords.txt
echo $rabbitmq_password >> /root/djangopbx-passwords.txt

###############################################
# Use RabbitMQ
###############################################
if [[ $use_rabbitmq_broker == "yes" ]]
then
cat << \EOF > /lib/systemd/system/pbx_event_receiver@.service
;;;;; Author: Adrian Fretwell <adrian@djangopbx.com>

[Unit]
Description=PBX Event Receiver, instance %i
PartOf=pbx_event_receiver.target
Wants=network-online.target
Requires=network.target local-fs.target postgresql.service
After=network.target network-online.target local-fs.target postgresql.service memcached.service

[Service]
; service
Type=simple
User=django-pbx
WorkingDirectory=/home/django-pbx/pbx
ExecStart=/home/django-pbx/envdpbx/bin/python manage.py eventreceiver
TimeoutSec=45s
Restart=always
KillSignal=SIGINT

[Install]
WantedBy=pbx_event_receiver.target

EOF
cat << \EOF > /lib/systemd/system/pbx_event_receiver.target
;;;;; Author: Adrian Fretwell <adrian@djangopbx.com>

[Unit]
Description=PBX Event Receiver serice
Wants=network-online.target
Requires=network.target local-fs.target postgresql.service
After=network.target network-online.target local-fs.target postgresql.service memcached.service

[Install]
WantedBy=multi-user.target

EOF
fi

if [[ $install_remote_event_receiver == "yes" ]]
then
cat << \EOF > /lib/systemd/system/pbx_remote_event_receiver.service
;;;;; Author: Adrian Fretwell <adrian@djangopbx.com>

[Unit]
Description=PBX Remote Event Receiver
Wants=network-online.target
Requires=network.target local-fs.target
After=network.target network-online.target local-fs.target

[Service]
; service
Type=simple
User=django-pbx
WorkingDirectory=/home/django-pbx/pbx/pbx/scripts
ExecStart=/home/django-pbx/envdpbx/bin/python remote_event_receiver.py
TimeoutSec=45s
Restart=always

[Install]
WantedBy=multi-user.target

EOF
fi


###############################################
# Set up passwords, session expiry etc.
###############################################

sed -i "s/^SECRET_KEY.*/SECRET_KEY ='${system_password}'/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/postgres-insecure-abcdef9876543210/${database_password}/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/postgres-insecure-abcdef9876543210/${database_password}/g" /home/django-pbx/pbx/pbx/scripts/resources/db/pgdb.py
sed -i "s/^DEBUG\s=.*/DEBUG = False/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/^ALLOWED_HOSTS\s=.*/ALLOWED_HOSTS = ['127.0.0.1', '${my_ip}', '${domain_name}']/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/#\sSESSION_COOKIE_AGE\s=\s3600/SESSION_COOKIE_AGE = 3600/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/#\sSESSION_EXPIRE_AT_BROWSER_CLOSE\s=\sTrue/SESSION_EXPIRE_AT_BROWSER_CLOSE = True/g" /home/django-pbx/pbx/pbx/settings.py
sed -i "s/XXXXXXXX/${database_password}/g" /root/pbx-backup.sh
sed -i "s/XXXXXXXX/${database_password}/g" /root/pbx-restore.sh
sed -i "s/^PBX_FREESWITCHES\s=.*/PBX_FREESWITCHES = ['$HOSTNAME']/g" /home/django-pbx/pbx/pbx/settings.py

if [[ $install_djangopbx_local == "yes" ]]
then

 cwd=$(pwd)
 cd /tmp

 # Perform initial steps on new DjangoPBX Django application
 echo " "
 echo "Performing migrations..."
 sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py migrate'
 echo " "
 echo "Loading user groups..."
 sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app tenants group.json'
 echo " "
 echo "Setting Django Core Sequences..."
 sudo -u postgres psql -d djangopbx -c "alter sequence if exists auth_group_id_seq increment by ${core_sequence_increment} restart with ${core_sequence_start};"
 sudo -u postgres psql -d djangopbx -c "alter sequence if exists auth_permission_id_seq increment by ${core_sequence_increment} restart with ${core_sequence_start};"
 sudo -u postgres psql -d djangopbx -c "alter sequence if exists auth_user_id_seq increment by ${core_sequence_increment} restart with ${core_sequence_start};"
 sudo -u postgres psql -d djangopbx -c "alter sequence if exists django_admin_log_id_seq increment by ${core_sequence_increment} restart with ${core_sequence_start};"
 sudo -u postgres psql -d djangopbx -c "alter sequence if exists django_content_type_id_seq increment by ${core_sequence_increment} restart with ${core_sequence_start};"
 sudo -u postgres psql -d djangopbx -c "alter sequence if exists pbx_users_id_seq increment by ${core_sequence_increment} restart with ${core_sequence_start};"

 sleep 1
 echo -e $c_green
 echo "You are about to create a superuser to manage DjangoPBX, please use a strong, secure password."
 echo -e "Hint: Use the email format for the username e.g. <user@${default_domain_name}>"
 pbx_prompt n "Press any key to continue "
 sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py createsuperuser'
 sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py collectstatic'

 ###############################################
 # Basic Data loading
 ###############################################
 sudo -u django-pbx bash -c "source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py createpbxdomain --domain ${default_domain_name} --user ${core_sequence_start}"

 pbx_prompt $skip_prompts "Load Default Access controls? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch accesscontrol.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch accesscontrolnode.json'
 fi

 pbx_prompt $skip_prompts "Load Default Email Templates? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch emailtemplate.json'
 fi

 pbx_prompt $skip_prompts "Load Default Modules data? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch modules.json'
 fi

 pbx_prompt $skip_prompts "Load Default SIP profiles? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch sipprofile.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch sipprofiledomain.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch sipprofilesetting.json'
 fi

 pbx_prompt $skip_prompts "Load Default Switch Variables? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app switch switchvariable.json'
 fi

 pbx_prompt $skip_prompts "Load Default Music on Hold data? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app musiconhold musiconhold.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app musiconhold mohfile.json'
 fi

 pbx_prompt $skip_prompts "Load Number Translation data? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app numbertranslations numbertranslations.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app numbertranslations numbertranslationdetails.json'
 fi

 pbx_prompt $skip_prompts "Load Conference Settings? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app conferencesettings conferencecontrols.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app conferencesettings conferencecontroldetails.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app conferencesettings conferenceprofiles.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app conferencesettings conferenceprofileparams.json'
 fi

 ###############################################
 # Default Settings
 ###############################################
 pbx_prompt $skip_prompts "Load Default Settings? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app tenants defaultsetting.json'
    sudo -u django-pbx bash -c "source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py updatedefaultsetting --category cluster --subcategory message_broker_password --value $rabbitmq_password"
 fi

 pbx_prompt $skip_prompts "Load Default Provision Settings? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app provision commonprovisionsettings.json'
 fi

 pbx_prompt $skip_prompts "Load Yealink Provision Settings? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app provision yealinkprovisionsettings.json'
 fi

 pbx_prompt $skip_prompts "Load Yealink vendor provision data? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app provision devicevendors.json'
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py loaddata --app provision devicevendorfunctions.json'
 fi

 ###############################################
 # Freeswitch core DB in postgreSql
 ###############################################
 if [[ $freeswitch_core_in_postgres == "yes" ]]
 then
    echo " "
    echo "Updating Switch DSNs..."
    sudo -u django-pbx bash -c "source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py updateswitchvariable --category DSN --name dsn --value \"pgsql://hostaddr=127.0.0.1 dbname=freeswitch user=freeswitch password='${database_password}'\""
    sudo -u django-pbx bash -c "source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py updateswitchvariable --category DSN --name dsn_callcentre --value \"pgsql://hostaddr=127.0.0.1 dbname=freeswitch user=freeswitch password='${database_password}'\""
    sudo -u django-pbx bash -c "source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py updateswitchvariable --category DSN --name dsn_voicemail --value \"pgsql://hostaddr=127.0.0.1 dbname=freeswitch user=freeswitch password='${database_password}'\""
    sed -r -i 's/<!-- (<param name="core-db-dsn" value="\$\$\{dsn\}" \/>) -->/\1/g' /home/django-pbx/freeswitch/autoload_configs/switch.conf.xml
    sed -r -i 's/<!-- (<param name="auto-create-schemas" value="false"\/>) -->/\1/g' /home/django-pbx/freeswitch/autoload_configs/switch.conf.xml
    sed -r -i 's/<!-- (<param name="auto-clear-sql" value="false"\/>) -->/\1/g' /home/django-pbx/freeswitch/autoload_configs/switch.conf.xml
    sed -r -i 's/<!--(<param name="odbc-dsn" value="\$\$\{dsn\}"\/>)-->/\1/g' /home/django-pbx/freeswitch/autoload_configs/voicemail.conf.xml
    sed -r -i 's/<!--(<param name="odbc-dsn" value="\$\$\{dsn\}"\/>)-->/\1/g' /home/django-pbx/freeswitch/autoload_configs/fifo.conf.xml
    sed -r -i 's/<!--(<param name="odbc-dsn" value="\$\$\{dsn\}"\/>)-->/\1/g' /home/django-pbx/freeswitch/autoload_configs/db.conf.xml
    sed -r -i 's/(<param name="dbname" value="\/var\/lib\/freeswitch\/vm_db\/voicemail_default.db"\/>)/<!--\1-->/g' /home/django-pbx/freeswitch/autoload_configs/voicemail.conf.xml
    sudo -u postgres psql -d djangopbx -c "update pbx_sip_profile_settings set enabled = 'true' where name = 'odbc-dsn';"
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py writeoutswitchvars'
 fi

 ###############################################
 # Menu Defaults
 ###############################################
 pbx_prompt n "Load Menu Defaults? "
 if [[ $REPLY =~ ^[Yy]$ ]]
 then
    sudo -u django-pbx bash -c 'source ~/envdpbx/bin/activate && cd /home/django-pbx/pbx && python3 manage.py menudefaults'
 fi

 cd $cwd

fi

###############################################
# Set Up crontab
###############################################
pbx_prompt n "Set up crontab? "
if [[ $REPLY =~ ^[Yy]$ ]]
then
    apt-get install -y cron
    sudo -u django-pbx bash -c 'crontab /home/django-pbx/pbx/pbx/resources/home/django-pbx/crontab'
fi

cd $cwd

pbx_prompt n "Show database password? "
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo $database_password
fi

pbx_prompt n "Show system password? "
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo $system_password
fi

systemctl daemon-reload

if [[ $install_freeswitch_local == "yes" ]]
then
    systemctl start freeswitch
    systemctl enable freeswitch
fi
if [[ $install_djangopbx_local == "yes" ]]
then
    service uwsgi start
    service nginx start
fi
if [[ $use_rabbitmq_broker == "yes" ]]
then
#  If more than one worker is required change {1..1} below.  Eg. {1..2} for two workers.
/usr/bin/systemctl enable pbx_event_receiver@{1..1}.service
/usr/bin/systemctl enable pbx_event_receiver.target
fi
if [[ $install_remote_event_receiver == "yes" ]]
then
/usr/bin/systemctl enable pbx_remote_event_receiver.service
fi

echo -e $c_green
cat << EOF
Installation Complete.

Make sure /etc/nftables.conf is correct for you!!
By default you must put your IP address in the white list to access ssh on port 22.

When you are sure that you will NOT LOCK YOURSELF OUT, issue the following command:
systemctl enable nftables

EOF
echo -e "${c_white}Then reboot!"
echo " "
echo -e "${c_green}Once you have rebooted, try logging in to your PBX at:"
echo "https://${default_domain_name}"
echo " "
echo -e "${c_yellow}Thankyou for using DjangoPBX"
echo -e $c_clear
