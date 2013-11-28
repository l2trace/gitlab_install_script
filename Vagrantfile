Vagrant::Config.run do |config|

  config.vm.box = "Centos 6.4_x86_64"
  config.vm.box_url = "https://github.com/2creatives/vagrant-centos/releases/download/v0.1.0/centos64-x86_64-20131030.box"
  config.vm.network :hostonly, '192.168.3.14'
  config.vm.provision "shell", path: "install.sh"
  config.vm.forward_port  80 , 8081
  config.vm.forward_port  443 , 8443
  config.vm.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  config.vm.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
   
 end