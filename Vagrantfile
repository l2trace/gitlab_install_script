Vagrant::Config.run do |config|
  config.vm.box = "Centos 6.4_x86_64"
  config.vm.box_url = "https://github.com/2creatives/vagrant-centos/releases/download/v0.1.0/centos64-x86_64-20131030.box"
  config.vm.network :hostonly, '192.168.3.14'
  config.vm.provision "shell", path: "install.sh"
  config.vm.network :forwarded_port, host: 8080, guest: 80
  config.vm.network :forwarded_port, host: 8443, guest: 443
  end