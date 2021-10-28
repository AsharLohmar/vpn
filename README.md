# vpn
## The problem
I have to deal with several VPNs for several clients on a daily basis. Most of them are configured in a "catch them all" manner. This leads with a lot of hassel because either the traffic of a VPN ends up going through another or sometimes activating the VPN just cuts you off from "The" internet leaving you with access only to whatever the VPN allows you to access from the Client's network.
## My solution
First of all, this is the result of several years of working and trying various solutions ... first there were plain VMs than came Vagrant, now ... docker.  
My current/final solution is to run the VPN client inside a docker container and let it do whaterver it wants inside there (changing routes, firewalling, changing nameserver). Inside each container I also add a "forward proxy" exposing a port, this way, using that port as a proxy I can have access to anything I can reach from inside the container which is whatever the VPN gives me.
On top of all these "VPN containers" I use another container, that I keep up almost all of the time, exposes an another proxy that using some rules it diverts the incomming traffic to the proxy running inside the needed VPN container and from there to the final destination.  
For the forward proxy I'm using this tool I've found called [glider](https://github.com/nadoo/glider) (thanks @nadoo) so for a detailed documentation on how&what it does you should check there.  
The "VPN containers" are published on my dockerhub https://hub.docker.com/u/asharlohmar. They are build using the "alpine:latest" and are/will be updated when I'll notice a version change of the OS or used software. For now I've built containers for: 
 * VPNc - installed from the alpine repos
 * openVPN - also installed from repos
 * openfortiVPN - build from source download from https://github.com/adrienverge/openfortiVPN. (thanks @adrienverge)
 
## Installation
### prerequisites
  * you need to run docker so ... that's that check docker docs. 
  (If you can't use docker nativelly you can use the [Vagrantfile](Vagrantfile) to spin up a small VM I've cooked up with alpine, docker and some other stuff needed to run the VPN clients. This would add vagrant to the list)
  * ... _the usuals_ ... git, zip, ...
  * bash ... the [VPN.sh](VPN.sh) is written for bash 
### preparation
Clone (or download and unpack) this repo to a folder of your choosing. (Due to some issues between VirtualBox and WSL1, this folder should be "outside" the WSL "space", some details [here](https://github.com/hashicorp/vagrant/issues/10576)).  
You can/should simlink the `VPN.sh` somewhere in your `$PATH`. For example I do `ln -s "$(realpath VPN.sh)" ~/bin/VPN`

## Configuration 
### the VPN
In order to configure a VPN destination create a folder with a meaningfull name inside the `conf/` folder. Es. `conf/client1`, `conf/my_vpn`, ...
Inside you must put:
 * `.container_args` (check on docker hub container's page for instructions on the content) and 
 * `vpn.conf` file with the configuration specific to the client used. 
For example for a VPN destination called "client1" that has/uses FortinetVPN I'd have something like this:
```
$ tree -a conf/client1/
conf/client1/
├── .container_args
└── vpn.conf

$ grep -r "" conf/client1
conf/client1/.container_args:d_args+=( "--device=/dev/ppp"  "asharlohmar/glider-openfortivpn" )
conf/client1/.container_args:
conf/client1/vpn.conf:host = vpn.client1.com
conf/client1/vpn.conf:port = 443
conf/client1/vpn.conf:username = my_username
conf/client1/vpn.conf:password = my_secret_passwd
conf/client1/vpn.conf:trusted-cert = 52e92d...some_signture...cc2cb76
```
As you can see I'm using my [asharlohmar/glider-openfortivpn](https://hub.docker.com/r/asharlohmar/glider-openfortivpn) VPN container and the vpn.conf ... it's just a simple openfortivpn conf client.
You can also add the following files:
 * `.motd` - as the name implies is a (static) [motd](https://en.wikipedia.org/wiki/Motd_(Unix)) file that it will show at the `start` of a VPN container. I mainly use it to keep some useful notes ... URLs, reminedrs, ...
 * `.hosts` - the content will be added to the `/etc/hosts` inside the container, this will allow to overide records provided from the available nameservers or help when the available nameserver does not provide (all) the neeeded records.

In order to start this VPN you can run `vpn.sh client1 [start]`, this will starta a container with the name "client1".

### the Proxy
As said before the proxy container stays on top of the VPN containers and acts as single-point-of contact in order to get the traffic to the final intended destination.
(For the configuration you can check the glider's documentation, following is just a TLDR version.) As said before the proxy uses some "rules" the rules are defined in "rules files" (`*.rule`) that stay in the `conf/proxy/rules.d/` folder. Usually for the "rule file" for a destination I'm using the same name as the folder with the VPN. For the previous example we would have `conf/proxy/rules.d/client1.rule`. The tipical content would be something like this:
```
# were to forward    v-- the name of the container 
forward=socks5://client1:2226

# what to forward there

# IPs
ip=1.2.3.4
ip=11.2.3.4

# networks
cidr=10.11.12.0/24
cidr=20.11.12.0/24

# domanins
domain=domain1.client1.local
domain=domain2.client1.com
```
