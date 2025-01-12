#!/bin/bash

# Install steps obtained from: https://pineboards.io/blogs/tutorials/how-to-configure-the-google-coral-edge-tpu-on-the-raspberry-pi-5

# Navigate to home directory
cd 

# Ensure OS is up to date
sudo apt update
sudo apt upgrade -y

# Modify boot config file to get the Coral TPU to run
echo "kernel=kernel8.img" | sudo tee -a /boot/firmware/config.txt
echo "dtoverlay=pciex1-compat-pi5,no-mip" | sudo tee -a /boot/firmware/config.txt

# Add Coral debian package repository to system
echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Update package list
sudo apt-get update

# Install Edge TPU runtime and other necessary packages
sudo apt-get install cmake libedgetpu1-std devscripts debhelper dkms dh-dkms -y

# Install the Gasket Driver
git clone https://github.com/google/gasket-driver.git

# Navigate to gasket-driver directory and build the driver
cd gasket-driver
sudo debuild -us -uc -tc -b

# Go back to the home directory and install the built package
cd ..
sudo dpkg -i gasket-dkms_1.0-18_all.deb

# Set up a udev rule to manage device permissions
sudo sh -c "echo 'SUBSYSTEM==\"apex\", MODE=\"0660\", GROUP=\"apex\"' >> /etc/udev/rules.d/65-apex.rules"

# Create a new group and add your user to it:
sudo groupadd apex
sudo adduser $USER apex

# Reboot Raspberry Pi
sudo reboot
