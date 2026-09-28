# -*- mode: ruby -*-
# vi: set ft=ruby :

JENKINS_PUB_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBeeilXdKKtPc0AfVvs69ocSrBo8zIvR9LbClbQISm4V jenkins-lab"

Vagrant.configure("2") do |config|
	nodes = [
		{ name: "web1", box: "ubuntu/jammy64",     ip: "192.168.56.20" },
		{ name: "web2", box: "bento/rockylinux-9", ip: "192.168.56.21" }
	]
	
	nodes.each do |node_info|
		config.vm.define node_info[:name] do |node|
			node.vm.box      = node_info[:box]
			node.vm.hostname = node_info[:name]
			node.vm.network "private_network", ip: node_info[:ip]
			
			node.vm.provider "virtualbox" do |vb|
				vb.name   = "jenkins-lab-#{node_info[:name]}"
				vb.memory = "1024"
				vb.cpus = 1
			end
			
			node.vm.provision "shell", inline: <<-SHELL
				mkdir -p /home/vagrant/.ssh
				touch /home/vagrant/.ssh/authorized_keys
				grep -qF "#{JENKINS_PUB_KEY}" /home/vagrant/.ssh/authorized_keys || echo "#{JENKINS_PUB_KEY}" >> /home/vagrant/.ssh/authorized_keys
				chown -R vagrant:vagrant /home/vagrant/.ssh
				chmod 700 /home/vagrant/.ssh
				chmod 600 /home/vagrant/.ssh/authorized_keys
				echo "Jenkins key installed on $(hostname)"
			SHELL
		end
	end
end