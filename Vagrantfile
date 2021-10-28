vm_name="vpn"
ip="192.168.56.200"
Vagrant.configure("2") do |config|
  config.vm.box = "asharlohmar/docker_alpine"
  config.vm.hostname = vm_name
  config.vm.define vm_name
  config.vm.network :private_network, ip: ip
  config.vm.provider "virtualbox" do |vb|
    vb.name = vm_name
  end
  # there's some problem with the Alpine + hostonly + static ip 
  # we need to restart the network at startup
  config.vm.provision "rs", type: "shell", run: "always" do |s|
    s.inline = <<-SHELL
    service networking restart
    service sshd restart
    service docker restart
SHELL
  end

  #config.vm.synced_folder ".", "/vagrant", disabled: true
  #config.vm.synced_folder ".", "/vpn", create: true, mount_options: ["umask=22", "fmask=11"], automount: true
end
