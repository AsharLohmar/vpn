# vpn
## The problem
I have to deal with several VPNs for several clients on a daily basis, most of the time at the same time, and often they are configured in a "catch them all" manner. This leads to a lot of hassle because either the traffic of a VPN ends up going through another or sometimes activating the VPN just cuts you off from "The" internet leaving you with access only to whatever the VPN allows you to access from the Client's network.
## My solution
First of all, this is the result of several years of working and trying various solutions ... At first there were plain VMs, then came Vagrant, now ... docker.

My current/final solution is to run the VPN clients inside docker containers and let them do whatever they want inside there (changing routes, firewalling, changing nameserver). Inside each container I also add a "forward proxy" on a specific port(2226) and using that port as a proxy you get access to anything that is reachable from inside the container.  
On top of all these "VPN containers" I use another container that I keep running almost all of the time, which has another proxy that, by using some rules, it diverts the incoming traffic to the proxy running inside the needed VPN container and from there to the final destination.  

For the forward proxy I'm using this tool I've found called [glider](https://github.com/nadoo/glider) (thanks @nadoo), so for a detailed documentation on "how & what" it does you should check there.  

All the containers are published on my DockerHub (https://hub.docker.com/u/asharlohmar). You check how I build them by looking at my [vpn_containers](https://github.com/AsharLohmar/vpn_containers) repo. They are built using the "alpine:latest" and are/will be updated when I notice a version change of the OS or used software.  
For now I've built containers for:  
* [vpnc](https://github.com/streambinder/vpnc) - installed from the [alpine repos](https://pkgs.alpinelinux.org/package/edge/community/x86_64/vpnc)  
* [openvpn](https://openvpn.net/) - also installed from [alpine repos](https://pkgs.alpinelinux.org/package/edge/main/x86_64/openvpn)  
* openfortivpn - built from sources downloaded from https://github.com/adrienverge/openfortivpn (thanks @adrienverge)
 
## Installation
First of all you'll need a few things:
* you need to run docker, so ... that's that. Check [docker](https://www.docker.com/) docs on how to do that. If you can't use docker natively, like in my case (I'm working on Windows with WSL1), you can use my [Vagrantfile](Vagrantfile) to spin up a small VM I've cooked up with alpine, docker and some other stuff needed to run the VPN clients. This would add [vagrant](https://www.vagrantup.com/) to the list.
* the [vpn.sh](vpn.sh) is written for bash, so you'll need bash
* depending on the approach in the next steps ... you can add "the usuals": git, unzip, some text editor, ...

All you need is the `vpn.sh` script (and a folder named `conf` just alongside it), you can choose to clone the whole repo (might help to keep you updated) or just download/copy what you need. You can/should symlink the `vpn.sh` somewhere in your `$PATH` for convenience. For example I do `ln -s "$(realpath vpn.sh)" ~/bin/vpn`.  
The vpn.sh checks for the presence of a file `.settings` which if found it then sources it, this can be used to override some of the defaults/running variables.

Word of advice, in case you use WSL1... vagrant/virtualbox can't mount (add shared folders) folders that are in the WSL1 space, some details [here](https://github.com/hashicorp/vagrant/issues/10576), so you should put everything in the "windows space".  

The `conf/proxy` folder contains the needed configuration for the main proxy, we'll check that later.

## Configuration  
### Configuring a VPN destination
In order to configure a VPN destination, you have to create a folder inside the `conf/` folder (I'd stick with simple 1-worded names, avoiding non ascii characters 'cause I didn't tested so much).   
Inside you **must** put:
* a file named `.container_args` - the main intent of this file is to manage the args of the docker command used to start the container (check on DockerHub page of the wanted container for instructions on the content)  
and 
* `vpn.conf` file with the configuration specific to the VPN client used.

For example for a VPN destination called "client1" that has/uses FortinetVPN I'd have something like this:
```
$ tree -a conf/client1/
conf/client1/
├── .container_args
└── vpn.conf
```
where
```
$ grep -r "" conf/client1
conf/client1/.container_args:d_args+=( "--device=/dev/ppp"  "asharlohmar/glider-openfortivpn" )
conf/client1/.container_args:

conf/client1/vpn.conf:host = vpn.client1.com
conf/client1/vpn.conf:port = 443
conf/client1/vpn.conf:username = my_username
conf/client1/vpn.conf:password = my_secret_passwd
conf/client1/vpn.conf:trusted-cert = 52e92d...some_signture...cc2cb76
```
As you can see I'm using my [asharlohmar/glider-openfortivpn](https://hub.docker.com/r/asharlohmar/glider-openfortivpn) VPN container and the vpn.conf ... it's just a simple configuration for the [openfortivpn](https://github.com/adrienverge/openfortiVPN) client.

You can also add the following files:
* `.motd` - as the name implies is a (static) [motd](https://en.wikipedia.org/wiki/Motd_(Unix)) file that it will show at the `start` of a VPN container. I mainly use it to keep some useful notes ... URLs, reminders, ...
* `.hosts` - the content will be added to the `/etc/hosts` inside the container, this will allow to override records provided from the available nameservers or help when the available nameserver does not provide (all) the needed records.

In order to start this VPN you can run `vpn.sh client1 [start]`, this will start a container with the name "client1". The various configurations ensure that the container will be "reachable" by that same name and that will help the main proxy know how to reach it.

All the containers are running on the same separated/dedicated network in order to avoid interfering with other containers.
```
docker network inspect vpn &>/dev/null || docker network create --driver bridge --subnet 192.168.253.0/24 --gateway 192.168.253.1  vpn
# the subnet was chosen in order to avoid conflicting with the network of one of my clients, there's no other reason or dependency whatsoever. 
```

### Configuring the main proxy
The proxy container stays on top of the VPN containers and acts as single-point-of contact in order to get the traffic to the final intended destination. 
The proxy (`conf/proxy`) uses the `asharlohmar/glider-proxy` container image, the glider that starts there it will be looking for rule files (`*.rule`) in the folder `/conf/rules.d` which will be the where the contents of the `conf/proxy/rules.d/` folder will be mounted. For a detailed documentation on the configuration you can check the [glider](https://github.com/nadoo/glider)'s documentation, the following is just a TLDR version. the typical `*.rule` file should look something like this:
```
$ cat conf/proxy/rules.d/client1.rule
# it's first "were to forward" 
# (we can reach the container by it's name, and the proxy running inside is on the port 2226)
forward=socks5://client1:2226

# then "what to forward" there

# by IPs
ip=1.2.3.4
ip=11.2.3.4

# entire networks
cidr=10.11.12.0/24
cidr=20.11.12.0/24

# and/or domains
domain=domain1.client1.local
domain=domain2.client1.com
````

You can start the proxy with `vpn.sh proxy start` and when started it binds on 2 ports
* one for the proxying (default 8443)
* and on another one there's a "http server" that provides a [proxy.pac](https://en.wikipedia.org/wiki/Proxy_auto-config) generated from the content of all the rule files. The "http server" is actually a `nc` listening and responding using a bash script that I've built based on @avleen's [bashttpd](https://github.com/avleen/bashttpd). The `proxy.pac` file is created so that it sends requests for the destinations found in the `*.rule` files to the proxy and leaves everything else to be accessed directly.

If you check the contents of the proxy's [.container_args](conf/proxy/.container_args) you'll see that you can change the ports by defining/overriding `PROXY_PORT` and `PROXYPAC_PORT` in the `.settings` file


## Usage
As I was saying, I'm using Windows and WSL1, so I'm using vagrant with the provided [Vagrantfile](Vagrantfile) to spin up my vpn docker machine. The machine has the IP address `192.168.56.200` fixed on a `host-only` interface (so when/if you have docker supported natively just use 127.0.0.1).  
My `.settings` file looks like this:
```
VPN_MOUNT="/vagrant/conf/${name}"
PROXY_ENDPOINT="192.168.56.200"

export DOCKER_HOST=tcp://192.168.56.200:2375
```
So I'm using the default ports 8443 and 80888,

I've configured http://192.168.56.200:8088/proxy.pac directly in the "Use automatic configuration script" in `Interner Options > Connections > LAN settings`, so my browsers are always using it. Firefox has its own proxy configuration.  
This way I can keep using the browser(s) as usual for the "normal browsing", but also when I need to go to one of the destinations accessible only through the VPN (for example `domain1.client1.local` from the example above, or some webapp running on some host) the generated `proxy.pac` file will redirect the traffic to the proxy that will consult the `*.rule` files and will redirect it to the proxy in the vpn container and from there it will make its way to the destination ... all transparently and hassle free.

I also do lots of ssh-ing to hosts accessible through these VPNs so for that I've modified my `~/.ssh/config` adding `ProxyCommand` pointing to the proxy on needed `Host` records, something like:
```
Host 1.2.3.4
    ProxyCommand nc -F -X 5 -x 192.168.56.200:8443 %h %p
```
I've also used the proxy in some other applications, for example I have an Eclipse working environment with a Java project that's using it and this way I can have the local configuration files using the same ip addresses I'm using in the lab or production env in order to reach DBs, third-party webapps/webservices, devices, ... no more tunneling (`ssh -L ...`) and/or simulators just because I "don't have access" to "the real thing".


**Extras**
Sometimes I have to deal with situations where some hosts are not reachable directly from the VPN so I have to use some "jump host"/bastion to reach them. For "ssh-ing" that would not be such a big problem there are various way to configure it to use a/the jump host ... but I also want access to "the other stuff" as uncumbersome as possible.  
In these cases I start another proxy inside the VPN container using ssh's `DynamicForward` option.

Let's say that for the same "client1" from before I have to use the "jump host" "1.0.0.1" in order to reach server 11.11.11.11 and the "intranet" webapps `[*.]intranet.client1.net`:
* inside `conf/client1` I'd add a `ssh_config` file with:
```
Host jumphost01
    User some_user
    Hostname 1.0.0.1
    DynamicForward 127.0.0.1:2227

```
and I can start a ssh-tunnel inside the VPN container running `ssh -F/conf/ssh_config -qfN jumphost01` (this will send the ssh process in the background).
Actually I'm using the following script
```
#!/bin/sh
dest="${1:?which tunnel}"
if [ "$(grep -E '^\s*Host' /conf/ssh_config | grep -c -E "\b${dest}\b")" = "0" ]; then
    echo "Unknown tunne ${dest}"
else
    if [ ! -f /tmp/tunnel_key ]; then
        # when using vagrant, the permissions are all scrambled and un manageable
        # so I move and use the key from /tmp 
        cp /conf/tunnel_key /tmp/tunnel_key
        chmod 400  /tmp/tunnel_ke*
    fi 
    which ssh || apk add openssh-client
    # shellcheck disable=SC2078
    (while [ 1=1 ];do echo "starting tunnel ${dest}"; ssh -F/conf/ssh_config -qN "${dest}"; sleep 1; done)&
fi
```
in order to start ssh command inside an infinite loop so that it reconnects in case it goes down ( notice the missing `-f` , this keeps the process in the foreground)  
* now I'd have to add a new `*.rule` file. I usually go with something like `conf/proxy/rules.d/client1_jumphost01.rule` so it's easier to identify what's what. The content of the file would be something like this:
```
forward=socks5://client1:2226,socks5://127.0.0.1:2227

ip=11.11.11.11
domain=intranet.client1.net
```
* and that's pretty much it.  
Note: the glider (so the proxy container) needs to be restarted every time the `*.rule` files are changed in order to "see" the changes. There's a feature request asking for support for reloading the rules [here](https://github.com/nadoo/glider/issues/75), but it's been there since 2018 so ... .


# Final words 

So basically what I've done here was to take these several tools and pieces of code and build this whole ... mechanism  ... that is controlled by this bash script.  
All the thanks and praises should go to the owners, maintainers and communities of those tools and "sources of inspiration",  if someone notices something/someone I've forgotten to mention please let me know.  
I don't know pretty much anything about licensing & Co. so ... use it as you please, but it would mean a lot if you give me a shout if you do. I hope I didn't "break" any license, if so just let me know.  
Feel free to snoop around the code (both the vpn script and container's creation script) and see that nothing nefarious is being done (at least on the stuff I control). 
