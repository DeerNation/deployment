#!/bin/bash

mkdir -p ~/.local/bin/

curl -L https://github.com/dhiltgen/docker-machine-kvm/releases/download/v0.7.0/docker-machine-driver-kvm -o ~/.local/bin/docker-machine-driver-kvm
chmod +x ~/.local/bin/docker-machine-driver-kvm

sudo apt install libvirt-bin qemu-kvm
sudo usermod -a -G libvirt `whoami`
newgrp libvirt

echo "Please add ~/.local/bin to your PATH"
