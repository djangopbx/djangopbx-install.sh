DjangoPBX Install
--------------------------------------
A simple install script for installing DjangoPBX. It is recommended to start with a minimal install of the operating system.

### Debian is the ONLY supported operating system
Debian is the preferred operating system by the FreeSWITCH developers. 

The current OS version being used for DjangoPBX development is Bullseye.
Details here: https://www.debian.org/releases/bullseye/installmanual

```sh
mkdir -p /usr/src/djangopbx-install
cd /usr/src/djangopbx-install
wget https://raw.githubusercontent.com/djangopbx/djangopbx-install.sh/debian11/install.sh
wget https://raw.githubusercontent.com/djangopbx/djangopbx-install.sh/debian11/requirements.txt
chmod +x install.sh
```
Modify the script to suit your requirements (eg. nano install.sh).
The Configuration Section of the script is a good place to start.
Then simply run it and follow the prompts:
```sh
./install.sh
```
## Under development
The install script has now entered a stage of Alpha Testing.

It has sucessfully installed on several servers but that does not guarantee
that it will work in every environment.
