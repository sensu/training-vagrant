Vagrant.configure("2") do |config|

  config.vm.define "enterprise-server" do |se|
    se.vm.box = "bento/centos-7.4"
    se.vm.hostname = "enterprise-server"
    se.vm.network "private_network", ip: "192.168.50.10"
    se.vm.provider "virtualbox" do |vb|
      vb.memory = "3072"
    end
  end

  config.vm.define("linux-client") do |lnx|
    lnx.vm.box = "bento/centos-7.4"
    lnx.vm.hostname = "linux-client"
    lnx.vm.network "private_network", ip: "192.168.50.20"
  end

  config.vm.define("windows-client") do |win|
    win.vm.box = "mwrock/Windows2016"
    win.vm.network "private_network", ip: "192.168.50.30"
    win.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
    end
  end
end
