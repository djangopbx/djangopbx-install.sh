DjangoPBX Install Binaries
--------------------------------------
Some additional binary files provided for convenience.

### mod_bcg729
There is currently no Debian package available for the royalty free
version of the G.729 codec.
A compiled version is available here:

This module was compiled on a Debian 12.4 Operating system (x86-64 GLIBC_2.2.5)
Details of the build process given below:

```sh
apt-get -y install libfreeswitch-dev git autoconf automake cmake libtool
cd /usr/src/
git clone https://github.com/xadhoom/mod_bcg729.git
cd mod_bcg729
make && make install
```

Details about the package, author and copyright can be found at the link below:

https://github.com/xadhoom/mod_bcg729
