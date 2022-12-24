DjangoPBX Install
--------------------------------------
A simple install script for installing DjangoPBX. It is recommended to start with a minimal install of the operating system.

### Debian is the ONLY supported operating system
Debian is the preferred operating system by the FreeSWITCH developers. 

The current OS version being user for DjangoPBX development is Bullseye.
Details here: https://www.debian.org/releases/bullseye/installmanual

```sh
mkdir -p /usr/src/djangopbx-install
cd /usr/src/djangopbx-install
wget https://raw.githubusercontent.com/djangopbx/djangopbx-install.sh/master/install.sh
```
Make any modifications to the [config] section of the script.
The run it:
```sh
./install.sh
```
## Under development
The code in this repository is not yet ready for download or testing.
