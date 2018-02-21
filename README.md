# Sensu Development Environment Vagrant

This repository contains Vagrantfile and some supporting scripts for configuring a Sensu development environment.

## Prerequisites
### Software
This repository was developed and tested with the following:

* Vagrant 2.0.1
* VirtualBox 5.2

The Vagrantfile enclosed here defines multiple virtual machines. Starting all of them at once will require in excess of 6GB of system memory.

### Vagrant Boxes
The vagrant boxes used by this project are publicly available [Centos 7.4][1] and [Windows 2016][2] VM images. There's nothing about these images that is specific to this workshop, so you can use a different box image if you already have one on hand. 

### Installing boxes

Run the following to download and install these vagrant boxes ahead of running `vagrant up`

```
$ vagrant box add bento/centos-7.4
$ vagrant box add mwrock/windows2016
```

[1]: https://app.vagrantup.com/bento/boxes/centos-7.4
[2]: https://app.vagrantup.com/mwrock/boxes/Windows2016
