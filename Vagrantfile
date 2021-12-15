vm_name="vpn"
Vagrant.configure("2") do |config|
  config.vm.box = "asharlohmar/vpn_dm"
  config.vm.hostname = vm_name
  config.vm.define vm_name

  config.vm.network :forwarded_port, guest: 2375, host: 2375, host_ip: "127.0.0.1"
  config.vm.network :forwarded_port, guest: 8443, host: 8443, host_ip: "127.0.0.1"
  config.vm.network :forwarded_port, guest: 8088, host: 8088, host_ip: "127.0.0.1"

  config.vm.provider "virtualbox" do |vb|
    vb.name = vm_name
  end
end
