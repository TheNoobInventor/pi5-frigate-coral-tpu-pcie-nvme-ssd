# Frigate setup on Raspberry Pi 5 using Google Coral PCIe Edge TPU

This repository serves as a guide on how to set up the [Frigate Network Video Recorder (NVR)](https://frigate.video/)
on a Raspberry Pi 5. Frigate provides an open source NVR solution that processes
camera feeds locally using real-time Artificial Intelligence (AI) for detecting an object of interest in motion such as a person, car, cat, and more.

The Google Coral Edge Tensor Processing Unit (TPU), in the PCIe form factor, is employed here
for object detection and even [outperforms powerful PCs](https://docs.frigate.video/) in processing the camera feeds with minimal overhead. The Coral is inserted in one of the M.2 NVMe Solid State Drive (SSD) slots of Geekworm's [X1004 Dual NVMe SSD Shield](https://wiki.geekworm.com/X1004). The
other slot has a 512 GB NVMe SSD used as a boot drive, runs the Frigate Docker container,
and stores Frigate's snapshots and recordings.

The steps on how to integrate Frigate with Home Assistant are also outlined in this guide.
This guide is available in video format in this [Youtube video](https://youtu.be/GZTiWnuYwOc).

---
- [Frigate setup on Raspberry Pi 5 using Google Coral PCIe Edge TPU](#frigate-setup-on-raspberry-pi-5-using-google-coral-pcie-edge-tpu)
  - [Hardware components](#hardware-components)
  - [Software installation](#software-installation)
    - [Boot from NVMe SSD](#boot-from-nvme-ssd)
    - [Google Coral PCIe Edge TPU setup](#google-coral-pcie-edge-tpu-setup)
    - [IP Camera setup](#ip-camera-setup)
    - [Frigate installation](#frigate-installation)
  - [Home Assistant integration](#home-assistant-integration)
    - [Mosquitto broker Add-on](#mosquitto-broker-add-on)
    - [MQTT Integration](#mqtt-integration)
    - [go2rtc](#go2rtc)
    - [Recording](#recording)
    - [Detect](#detect)
    - [Snapshots](#snapshots)
    - [Frigate HA Integration](#frigate-ha-integration)
    - [Frigate Card](#frigate-card)
    - [Setup motion masks in Frigate](#setup-motion-masks-in-frigate)
  - [Long term NVR solution](#long-term-nvr-solution)
  - [Temperature graphs](#temperature-graphs)
  - [Project demo](#project-demo)
    - [Reference Links](#reference-links)
      - [Geekworm related:](#geekworm-related)
      - [Frigate related:](#frigate-related)
      - [Coral related:](#coral-related)
      - [Raspberry Pi related:](#raspberry-pi-related)
      - [Dahua IP camera related:](#dahua-ip-camera-related)
      - [Linux related:](#linux-related)
      - [Docker related:](#docker-related)
      - [MQTT related:](#mqtt-related)
      - [Home Assistant related:](#home-assistant-related)
---

## Hardware components

These are the components used in this project:

- Raspberry Pi 5 8 GB
- Pi 5 power supply
- [Google Coral PCIe Edge TPU (single version)](https://s.click.aliexpress.com/e/_DE6uBIl)
- Geekworm X1004 Dual NVMe SSD shield
- [Pi 5 active cooler](https://s.click.aliexpress.com/e/_Dl0q71f)
- IP camera
- MicroSD card (16 GB minimum)
- [MicroSD card reader](https://s.click.aliexpress.com/e/_DktQGtF)
- 512 GB NVMe SSD drive
- [NVMe SSD enclosure](https://s.click.aliexpress.com/e/_Dl7Sh4v)
- Power Over Ethernet (POE) Switch
- Router
- Ethernet cables (for Pi 5, POE switch and IP camera)

***Note: The Raspberry Pi 5 2 GB and 4 GB versions could work well but I do not have any for
a performance evaluation.***

Geekworm's [X1004 Dual NVMe SSD shield](https://wiki.geekworm.com/X1004) has two NVMe SSD slots that can take up to 4 TB each, bringing the total storage to 8 TB. So it can serve as a very good Network Attached Storage (NAS) or home media solution, it should be noted that it **only** supports PCIe Gen 2 speeds not Gen 3 because of the ASMedia PCIe switch the shield uses. However for this project, the Edge TPU is installed in one slot and a NVMe SSD drive in the other. Another thing to note is that the shield is **only** compatible with M.2 NVMe SSDs; a list of incompatible NVMe SSD's is available [here](https://wiki.geekworm.com/NVMe_SSD_boot_with_the_Raspberry_Pi_5).
The shield is shown below.

<p align="center">
  <img title='X1004 empty' src=images/x1004_empty.jpg width=500>
  <img title='X1004 mounted' src=images/x1004_mounted.jpg width=500>
</p>

The IP camera used should meet Frigate's requirements of supporting H.264 encoding and the real-time streaming protocol or RTSP. The IP camera is setup in this [subsection](#ip-camera-setup).

But before connecting the hardware components, let's set up the software.

## Software installation

The Raspberry Pi 5 will initially boot from the MicroSD card flashed with Raspberry Pi OS Lite. This is done to upgrade the bootloader version to the one that supports booting from SSDs, set the boot order to boot from the NVMe drive and also make changes to the boot `config.txt` file to enable the Pi detect the Coral driver.

Raspberry Pi OS Lite was chosen because the Pi 5 will be running headless, meaning it won't be connected to a monitor, so the Desktop variant of Raspberry Pi OS is not needed.

***Note: Ubuntu Server 24.04 was considered as well but I encountered bootup issues after running [this bash script](./scripts/coral-tpu-pcie-geekworm-x1004-shield-pi5-setup.sh), which will be introduced in the Google Coral [subsection](#google-coral-pcie-edge-tpu-setup), to get the Pi to detect the Coral driver.***

The Raspberry Pi Imager is used to flash the Raspberry Pi OS Lite on the MicroSD card (and also on the NVMe drive), it can be downloaded [here](https://www.raspberrypi.com/software/); the Raspberry Pi Foundation recommends using an SD card with [at least 16 GB of storage](https://www.raspberrypi.com/documentation/computers/getting-started.html#recommended-sd-cards) for the Raspberry Pi OS Lite. After installing the Raspberry Pi Imager, plug in the MicroSD card into the MicroSD card reader, then start the flashing process by picking the Raspberry Pi device to flash the OS image on.

<p align='center'>
  <img title='Imager home' src=images/imager_home.png width="500">
  <img title='Imager Pi device' src=images/imager_pi_device.png width="500">
</p>

Next, click on **"Raspberry Pi OS (other)"** and choose the **Raspberry Pi OS Lite (64-bit)** image.
<p align='center'>
  <img title='Imager os 1' src=images/imager_os_1.png width="500">
  <img title='Imager os 2' src=images/imager_os_2.png width="500">
</p>

Then choose the inserted MicroSD card as the storage for the image. Afterwards, there will be prompt to customize the OS, click **Edit Settings**.

<p align='center'>
<img title='Imager storage' src=images/imager_storage.png width="500">
<img title='Imager custom settings' src=images/imager_cust_set_1.png width="500">
</p>

Under the **General** settings tab, choose a **hostname**, a **username** and **password**. The hostname is the unique identifier for the Pi 5 on the network.

Navigate to the **Services** tab, check **Enable SSH** and click on **Use password authentication**, this is the password chosen in the previous step. Enabling SSH provides [secure access](https://www.raspberrypi.com/documentation/computers/remote-access.html#remote-access) to a terminal session on the Raspberry Pi 5 from any device on the same local network as the Pi; commands can be sent to the Pi 5 over the network to run programs, change settings and [install packages](https://www.ev3dev.org/docs/tutorials/connecting-to-ev3dev-with-ssh/).

Then save these settings.

<p align='center'>
  <img title='Imager custom settings 2' src=images/imager_cust_set_2.png width="500">
  <img title='Imager custom settings 3' src=images/imager_cust_set_3.png width="500">
</p>

You will be prompted to input your admin password before the Imager starts writing the OS image to the MicroSD card. The card can be ejected once the flashing process is done.

<p align='center'>
  <img title='Imager flashing' src=images/imager_flashing.png width="500">
  <img title='Imager flash done' src=images/imager_flash_done.png width="500">
</p>

### Boot from NVMe SSD

Insert the newly flashed MicroSD card into the Raspberry Pi 5, plug an ethernet cable from the POE switch (or directly from the router) into the Pi's ethernet port then connect the Pi's power supply
to power it on. Give the Raspberry Pi 5 roughly 30 seconds to bootup before proceeding to the next step. These connections are shown in the figure below.

<p align="center">
  <img title='Pi5 connection' src=images/pi5_connection.png width=1000>
</p>

We'll connect to the Raspberry Pi 5 using `ssh` by running the specific form of this command: `ssh username@hostname`. In our case this will be:

```
ssh testpi@testpi.local
```

When connecting to the Pi 5 for the first time, you will be prompted to confirm the authenticity of
the host.

<p align='center'>
  <img title='Host auth 1' src=images/host_auth1.png width="500">
</p>

Type `yes` and enter the password when prompted in order to log in.

<p align='center'>
  <img title='Host auth 2' src=images/host_auth2.png width="500">
  <img title='Host auth 3' src=images/host_auth3.png width="500">
</p>

In order to boot from the NVMe, we first have to update the bootloader on the Raspberry Pi 5 to a version dated **2024/05/17** or later.
The bootloader contains code which starts up the various hardware components and loads the operating system. It is stored on the Pi 5's [EEPROM](https://www.lenovo.com/us/en/glossary/what-is-eeprom/).

The current bootloader version can be checked by running this command:

```
vcgencmd bootloader_version
```

This will produce an output that looks like this:

```
2024/11/12 16:10:44
version 4b019946a06ea87c36d14fd6d702cc65fb458b9e (release)
timestamp 1731427844
update-time 1732247059
capabilities 0x0000007f
```

This version is dated **2024/11/12** therefore booting from an NVMe SSD is supported. However, if you wanted to update the bootloader version, the following
steps can be followed.

Run the command:

```
sudo raspi-config
```

Scroll down to **Advanced Options** and press enter, then select **A5 Bootloader Version**, click on **E1 Latest** and choose **Yes**.
Then click on **Ok**, **Finish** and finally reboot the Pi for the bootloader update to be effected.

<p align='center'>
  <img title='Bootloader update 1' src=images/bootloader_update_1.png width="500">
  <img title='Bootloader update 2' src=images/bootloader_update_2.png width="500">
</p>

<p align='center'>
  <img title='Bootloader update 3' src=images/bootloader_update_3.png width="500">
  <img title='Bootloader update 4' src=images/bootloader_update_4.png width="500">
</p>

<p align='center'>
  <img title='Bootloader update 5' src=images/bootloader_update_5.png width="500">
  <img title='Bootloader update 6' src=images/bootloader_update_6.png width="500">
  <img title='Bootloader update 7' src=images/bootloader_update_7.png width="500">
</p>

The next thing we need to do is to enable PCIe connector on the Pi 5 because it is disabled by default. To enable the PCIe connector,
open the `/boot/firmware/config.txt` file with this command,

```
sudo nano /boot/firmware/config.txt
```

Then add the following lines at the end of the file,

```
# Enable the PCIe External connector
dtparam=pciex1
```

Save these changes and close the editor with `Ctrl+x`, then reboot with the command `sudo reboot`.

Now we need to set the boot order for the Raspberry Pi 5 to boot from an NVMe first before trying out other options. This can be done in two ways:

Using `raspi-config`,

```
sudo raspi-config
```

Scroll down and select **6 Advanced Options** choose **A4 Boot Order** click on **B2 NVMe/USB Boot**.
Then click on **Ok**, **Finish** choose **Yes** to reboot.

<p align='center'>
  <img title='Boot order 1' src=images/boot_order_1.png width="500">
  <img title='Boot order 2' src=images/boot_order_2.png width="500">
</p>

<p align='center'>
  <img title='Boot order 3' src=images/boot_order_3.png width="500">
  <img title='Boot order 4' src=images/boot_order_4.png width="500">
</p>

<p align='center'>
  <img title='Boot order 5' src=images/boot_order_5.png width="500">
  <img title='Boot order 6' src=images/boot_order_6.png width="500">
</p>

Or using the following command,

```
sudo rpi-eeprom-config --edit
```

Change the `BOOT_ORDER` line to this:

```
BOOT_ORDER=0xf416
```

Again save these changes and close the editor with `Ctrl+x`. Reboot the Pi 5 for the changes to be effected.

With the PCIe connector enabled and the Pi 5 set to boot from an NVMe first, the main thing left to do is to boot the Raspberry Pi 5 from the NVMe SSD.
We'll carry out the following steps to achieve this:

- Shutdown the Raspberry Pi 5, unplug the MicroSD card and power cable,
- Flash the Raspberry Pi OS Lite on the NVMe SSD using an NVMe SSD enclosure,
- Attach the NVMe SSD to the Dual NVMe SSD shield,
- Connect the shield to the Pi 5's PCIe port with the provided ribbon cable,
- Power on the Pi 5 with the ethernet cable plugged in, then
- Connect to the Pi 5 via SSH with the chosen username and hostname.

The process of flashing Raspberry Pi OS Lite on the NVMe SSD are the same steps followed in the previous section.

When booting off the NVMe SSD, the Raspberry Pi 5 might reboot a couple of times, you can optionally connect the Pi 5 to a monitor with
HDMI to confirm when it's ready to work with.

Using Geekworm's Dual NVMe SSD Shield allows you to leverage the faster read and write speeds of an SSD compared to a MicroSD card. This will beneficial
when storing and playing back videos of detected objects from Frigate.

A comparison of the read and write speeds of the MicroSD card and the NVMe SSD used in this project are shown in the images below.

<p align='center'>
  <img title='Microsd card speed' src=images/microsd_card_speed_test.png width="500">
  <img title='NVMe SSD speed' src=images/nvme_ssd_speed_test.png width="500">
</p>

The commands used were obtained from this [guide](https://linuxconfig.org/how-to-test-sd-card-speed-on-raspberry-pi) where the write speeds are tested by writing
1 GB of data in 10 blocks of 100 MB. This is carried out with the following command,

```
dd if=/dev/zero of=./TestingFile bs=100M count=10 oflag=direct
```

While the read speeds are tested by reading the `TestingFile` generated in the previous command in 10 blocks of 100 MB each with this command,

```
dd if=./TestingFile of=/dev/zero bs=100M count=10 oflag=dsync
```

Notice how fast the NVMe SSD speeds are compared to the MicroSD card and also the time it took to complete the respective operations.

### Google Coral PCIe Edge TPU setup

Frigate strongly recommends using a Google Coral for object detection as this $60 device is [able to outperform a $2000 CPU](https://docs.frigate.video/frigate/hardware#google-coral-tpu).
The Goolge Coral PCIe Edge TPU used in this project is shown below.

<p align="center">
  <img title='Coral PCIe TPU' src=images/coral_pcie_tpu.jpg width=1000>
</p>

The Google Coral comes in other form factors as shown in the Coral [products page](https://coral.ai/products/). The Google Coral Edge TPU needs to be configured to work on the Dual NVMe SSD Shield and the Raspberry Pi 5. This includes installing the required drivers and packages, installing the Edge TPU runtime and adding some lines to the `/boot/firmware/config.txt` file to get the Coral TPU to run.

I wrote a bash script, in the `scripts` directory of this repository, based on this [guide](https://pineboards.io/blogs/tutorials/how-to-configure-the-google-coral-edge-tpu-on-the-raspberry-pi-5) from Pineboards to configure the Coral. Additionally, this [Raspberry PI forum post](ttps://forums.raspberrypi.com/viewtopic.php?t=363682&start=25) offered the solution to get the Pi 5 to detect the Coral driver by adding this line `dtoverlay=pciex1-compat-pi5,no-mip` to the `/boot/firmware/config.txt` file.

If you cloned this repository on the Pi 5, navigate to the `scripts` directory then run the Google Coral PCIe TPU setup script,

```
bash coral-tpu-pcie-geekworm-x1004-shield-pi5-setup.sh
```

Alternatively you can run this command to execute the same script from a GitHub gist I wrote,

```
curl https://gist.githubusercontent.com/TheNoobInventor/ef00bc82f3a166653a8cff744f74ec23/raw/a79e70a028b124591363b41771745faaf81e8c9a/coral-tpu-pcie-geekworm-x1004-shield-pi5-setup.sh | sh
```

The script reboots the Raspberry Pi 5 to effect all the changes. To verify that the Coral driver is loaded run the following command,

```
sudo lspci -v
```

This lists out information about all PCI buses and devices on the Pi 5. Look through the terminal output for the following lines:

```
0000:01:00.0 System peripheral: Global Unichip Corp. Coral Edge TPU (prog-if ff)
Subsystem: Global Unichip Corp. Coral Edge TPU
Flags: bus master, fast devsel, latency 0, IRQ 39
Memory at 1800100000 (64-bit, prefetchable) [size=16K]
Memory at 1800000000 (64-bit, prefetchable) [size=1M]
Capabilities: [80] Express Endpoint, MSI 00
Capabilities: [d0] MSI-X: Enable+ Count=128 Masked-
Capabilities: [e0] MSI: Enable- Count=1/32 Maskable- 64bit+
Capabilities: [f8] Power Management version 3
Capabilities: [100] Vendor Specific Information: ID=1556 Rev=1 Len=008 <?>
Capabilities: [108] Latency Tolerance Reporting
Capabilities: [110] L1 PM Substates
Capabilities: [200] Advanced Error Reporting
Kernel driver in use: apex
Kernel modules: apex
```

Next let's check if the Google Coral is connected and detected by the Pi with this command,

```
ls /dev/apex_0
```

This should output,

```
/dev/apex_0
```

You can also confirm that the Coral TPU works well by installing the PyCoral library and running image classification tests with these guides from [Pineboards](https://pineboards.io/blogs/tutorials/installing-pycoral-for-google-coral-on-raspberry-pi-5) and [Google](https://coral.ai/docs/m2/get-started/#4-run-a-model-on-the-edge-tpu). But we'll proceed to setting up the IP Camera for Frigate with the assumption that the device is working properly.

### IP Camera setup

To obtain the most compatibility with all the Frigate and Home Assistant features, the IP cameras used [should output H.264 video and AAC audio](https://docs.frigate.video/frigate/hardware/#cameras). Additionally, it would be beneficial that the chosen cameras support multiple substreams to allow different resolutions to be used for detection, streaming (with the Real Time Streaming Protocol (RTSP)), and recordings without re-encoding.

The image below shows the video pipeline that Frigate uses to process the camera feed.

<p align="center">
  <img title='Frigate video pipeline' src=images/frigate_video_pipeline.png width=600>
</p>

More detailed information about the video pipeline can be found in the [documentation](https://docs.frigate.video/frigate/video_pipeline).

Dahua cameras are recommended because they are more readily available compared to other brands and meet the previously stated requirements. The Dahua bullet camera below is used in this project.

<p align="center">
  <img title='Dahua camera' src=images/dahua_camera.JPG width=1000>
</p>

The Dahua camera will need to be setup before using it with Frigate, this [YouTube video by @ecologicaltime](https://www.youtube.com/watch?v=JxTM-Ja2SI8) provides a walkthrough on how to do this.
Plug in the IP camera into the POE switch as shown in the connection diagram below.

<p align="center">
  <img title='IP camera connection' src=images/ip_camera_connection.png width=1000>
</p>

After setting up the Dahua camera with the YouTube video, we will need to configure the camera streams for use in Frigate.

***Note: Write/type out your camera IP address, username and password which will be used in the next section.***

This example camera configuration is provided in the [Frigate documentation](https://docs.frigate.video/frigate/camera_setup/#example-camera-configuration):

```
Main Stream (Recording & RTSP)

Encode Mode: H.264
Resolution: 2688*1520
Frame Rate(FPS): 15
I Frame Interval: 30

Sub Stream (Detection)

Enable: Sub Stream 2
Encode Mode: H.264
Resolution: 1280*720
Frame Rate: 5
I Frame Interval: 5
```

My Dahua bullet camera configurations are as follows,

<p align="center">
  <img title='Dahua camera setup' src=images/dahua_camera_setup.png width=1000>
</p>

The camera sub stream resolution does not go up to `1280*720`, mine was configured at `640*480`; but it still performs well for object detection. More information about choosing
detection resolutions for Frigate can be found [here](https://docs.frigate.video/frigate/camera_setup/#choosing-a-detect-resolution).

Now, let's install Frigate.

### Frigate installation

From the [Frigate documentation](https://docs.frigate.video/frigate/installation):

> Frigate is a Docker container that can run on any Docker host including as a HassOS Addon. Note that a Home Assistant Addon is not the same thing as the integration. The integration is required to integrate Frigate into Home Assistant.

In following this guide to set up Frigate on a Raspberry Pi 5, it is assumed that you have some knowledge of Docker. Otherwise, this YouTube [Docker Crash
Course by TechWorld with Nana](https://www.youtube.com/watch?v=pg19Z8LL06w) and the [Official Docker Getting Started Guide](https://docs.docker.com/get-started/docker-overview/) are good places to start learning about Docker.

I wrote another bash script to install Docker based on the debian install steps provided by this Docker official [guide](https://docs.docker.com/engine/install/debian/).

Before proceeding, ensure that the network devices are connected as shown below.

<p align="center">
  <img title='Network device connections' src=images/network_devices.png width=1000>
</p>

Going back to the terminal on Raspberry Pi, navigate to the `scripts` folder again and execute this command,

```
bash docker-install.sh
```

Or execute the script from the GitHub gist with,

```
curl https://gist.githubusercontent.com/TheNoobInventor/e88ff191ccdf11b64a2d1da4ae144149/raw/57fe3c399c34a9a44f33217ecfcdedb1edb68691/docker-install.sh | sh
```

The Raspberry Pi is rebooted after Docker is installed and you can test the installation by running this command in the terminal,

```
docker run hello-world
```

Which will output the following message,

```
Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

The next thing we'll need to do is create the necessary files and directories for Frigate configuration and storage, using [this Pineboards blog post](https://pineboards.io/blogs/tutorials/installing-frigate-on-raspberry-pi-5-with-a-google-coral-tpu) as a guide.

Create the `config` and `storage` directories with these commands,

```
mkdir –p /home/frigipi/frigate/config 
mkdir –p /home/frigipi/frigate/storage
```

Remember to replace `frigipi` with the username you chose when flashing the OS on the NVMe SSD drive. We'll create the Frigate `config.yml` file in the `config` directory.

```
nano /home/frigipi/frigate/config/config.yml 
```

Then paste in this simple config which will be sufficient to start up Frigate:

```
mqtt:
  enabled: False

detectors:
  coral:
    type: edgetpu
    device: pci

cameras:
  test_cam: # change camera name
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://{FRIGATE_RTSP_USER}:{FRIGATE_RTSP_PASSWORD}@192.168.8.201:554/cam/realmonitor?channel=1&subtype=1
          roles:
            - detect

version: 0.14
```

MQTT is disabled for now but it is required for the Home Assistant integration in the following section; [HiveMQ](https://www.hivemq.com/mqtt/) provides a lot of useful resources on getting started with MQTT.

The next part of the config file specifies the detector to be used, which is a single PCIe Google Coral Edge TPU. More information about the supported officially supported detectors is available [here](https://docs.frigate.video/configuration/object_detectors/).

The camera input rtsp path uses one of the [URL options](https://dahuawiki.com/Remote_Access/RTSP_via_VLC) for remote access/RTSP stream with Dahua cameras; other camera brands might have different URL options. `FRIGATE_RTSP_USER` and `FRIGATE_RTSP_PASSWORD` are Docker environment variables for the IP camera's username and password, these will be set in the `docker-compose.yml` file which we will configure shortly. The IP camera address is `192.168.8.201` and `554` is the default RTSP port. For my Dahua camera, setting the `subtype` to `0` uses the main stream, while a value of `1` uses the sub stream, for detection in this instance. 

More information about setting up the Frigate camera inputs are available [here](https://docs.frigate.video/configuration/cameras/).

We'll use a Docker compose file to configure the Frigate container installation. Navigate to the `frigate` directory then create the `docker-compose.yml` file,

```
cd /home/frigipi/frigate 
nano docker-compose.yml 
```

Paste the following in the config file,

```
services:
  frigate:
    container_name: frigate
    privileged: true # this may not be necessary for all setups
    restart: unless-stopped
    image: ghcr.io/blakeblackshear/frigate:stable
    shm_size: "64mb" # update for your cameras based on calculation above
    devices:
      - /dev/apex_0:/dev/apex_0    # Passes a PCIe Coral, follow driver instructions here https://coral.ai/docs/m2/get-started/#2a-on-linux
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /home/frigipi/frigate/config:/config # Replace "frigipi" with your chosen username
      - /home/frigipi/frigate/storage:/media/frigate # Replace "frigipi" with your chosen username
      - type: tmpfs # Optional: 1GB of memory, reduces SSD/SD Card wear
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    ports:
      - "5000:5000"
      - "8554:8554" # RTSP feeds
      - "8555:8555/tcp" # WebRTC over tcp
      - "8555:8555/udp" # WebRTC over udp
    environment:
      FRIGATE_RTSP_USER: "change-me"
      FRIGATE_RTSP_PASSWORD: "change-me"
```

***Note: This config file is also available in the*** `config` directory of this repository.

Finally, run this command which will pull the Frigate docker image, and deploy the container with the configurations we set,

```
docker compose up -d
```

The `-d` flag is used to run the container in detached mode or in the background, meaning it does not flood the terminal with container log data.

If everything went well, you should be able to access the Frigate Web User Interface (UI) in the browser by either using the hostname with `frigipi.local:5000` or using the IP address of your Raspberry Pi 5 with port 5000. The Frigate home page is shown in the GIF below.

<p align='center'>
  <img title='Frigate home page' src=images/frigate_homepage.gif width="1000">
</p>

You can edit the `config.yml` file using the Frigate Configuration Editor by clicking on the gear button in the bottom left corner then on **Configuration Editor**.

<p align='center'>
  <img title='Frigate gear button config' src=images/frigate_gear_button_config.png width="1000">
</p>

There are options to copy the configuration, save config changes and restart the Frigate container or simply to save them, in the top left corner of the Frigate UI.

<p align='center'>
  <img title='Frigate config editor' src=images/frigate_config_editor.png width="1000">
</p>

You can also check out system metrics like the Google Coral detector inference speed, temperature and more.

<p align='center'>
  <img title='Frigate gear button metrics' src=images/frigate_gear_button_metrics.png width="1000">
</p>

<p align='center'>
  <img title='Frigate system metrics' src=images/frigate_system_metrics.png width="1000">
</p>

There are tabs for **Storage** and **Cameras** which includes information about the camera storage and detections respectively.

<p align='center'>
  <img title='Frigate system storage' src=images/frigate_system_storage.png width="1000">
</p>

<p align='center'>
  <img title='Frigate system cameras' src=images/frigate_system_cameras.png width="1000">
</p>

Under Configuration, click on settings, here we can see tabs for **General Settings**, **Camera Settings**, **Masks/Zones**, **Motion Tuner**,
**Debug** and **Users**. We will look at **Masks** in this [subsection](#setup-motion-masks-in-frigate), but you can go through some of these tabs using the Frigate documentation
as a guide.

<p align='center'>
<img title='Frigate gear button settings' src=images/frigate_gear_button_settings.png width="1000">
</p>

<p align='center'>
  <img title='Frigate config settings' src=images/frigate_config_settings.png width="1000">
</p>

With Frigate installed and running, let's integrate it with Home Assistant.

## Home Assistant integration

Home Assistant (HA) is an open source home automation platform that prioritizes local control and privacy. Users can [integrate](https://www.home-assistant.io/integrations) over a thousand different devices and services, perform
[automations](https://www.home-assistant.io/docs/automation) with these devices, and visualize smart home information using [dashboards](https://www.home-assistant.io/dashboards) in Home Assistant. Your smart home system can be extended using [add-ons](https://www.home-assistant.io/addons) and can be controlled with your voice
using the [Assist voice assistant](https://www.home-assistant.io/voice_control/). There are more Home Assistant features which can be explored on their [homepage](https://www.home-assistant.io/).

There are four different installation methods for HA depending on the features required, these [installation methods](https://www.home-assistant.io/installation/#advanced-installation-methods) are shown in the image below.

<p align="center">
  <img title='Home Assistant Install options' src=images/home_assistant_install_options.png width=1000>
</p>

We'll need to either install **Home Assistant Operating System (HA OS)** or **Home Assistant Supervised** as these are the only methods that allow use of **add-ons** which is a requirement for integrating HA with Frigate.
Home Assistant Supervised requires the user to maintain the operating system by themselves so installing HA OS is the preferred method for a beginner. I have HA OS installed on a Minisforum mini PC. On another note Home Assistant is also abbreviated as **Hass**.

You can follow the [official guide](https://www.home-assistant.io/installation/) or this comprehensive [YouTube video by CrossTalk Solutions](https://www.youtube.com/watch?v=Y38qRYYAwAI&t=71s) to install Home Assistant. Let's briefly go over the Home Assistant concepts of **add-ons** and **integrations**.

[Add-ons](https://www.home-assistant.io/getting-started/concepts-terminology/#add-ons) are third-party applications that provide additional functionality in Home Assistant. Examples of add-ons are: an MQTT broker, a file editor or a database server.
[Integrations](https://www.home-assistant.io/getting-started/concepts-terminology/#integrations) are pieces of software that allow Home Assistant to connect to other software and platforms. For instance, a product by Philips called Hue would use the Philips Hue integration and
allow Home Assistant to talk to the hardware controller Hue Bridge. Any HA compatible devices connected to the Hue Bridge would appear in Home Assistant as devices.

In summary, add-ons run directly alongside Home Assistant, whereas integrations connect Home Assistant to other apps. The full list of Home Assistant terminology and glossary are available [here](https://www.home-assistant.io/getting-started/concepts-terminology/) and [here](https://www.home-assistant.io/docs/glossary/) respectively.

Add-ons are installed from the add-on store under **Settings** > **Add-ons**. Then click on the button on the bottom right corner to view the full add-ons list. 

<p align='center'>
  <img title='HA add-ons 1' src=images/add-ons-1.png width="1000">
</p>

<p align='center'>
  <img title='HA add-ons 2' src=images/add-ons-2.png width="1000">
</p>

<p align='center'>
  <img title='HA add-ons 3' src=images/add-ons-3.png width="1000">
</p>

You can also open the add-on store by clicking on the HA badge below,

[![Open your Home Assistant instance and show the add-on store.](https://my.home-assistant.io/badges/supervisor_store.svg)](https://my.home-assistant.io/redirect/supervisor_store/)

Again, from the [Frigate documentation](https://docs.frigate.video/frigate/installation/#dependencies),

> An MQTT broker is optional with Frigate, but is required for the Home Assistant integration.
> If using Home Assistant, Frigate and Home Assistant must be connected to the same MQTT broker.

But before setting up the MQTT broker, we need to create a new person in HA with login credentials that will be used when we are configuring the broker.

In Home Assistant, go to Settings > People then click on **Add Person** at the bottom right corner. Choose a name for the person and toggle on the **Allow login** button.
The username for the person is set to what you chose by default, next input a password and confirm it, toggle the **Local access only** button, click on **Create**, then on **Create** again.

<p align='center'>
  <img title='New person 1' src=images/new_person_1.png width="1000">
</p>

<p align='center'>
  <img title='New person 2' src=images/new_person_2.png width="1000">
</p>

<p align='center'>
  <img title='New person 3' src=images/new_person_3.png width="1000">
</p>

<p align='center'>
  <img title='New person 4' src=images/new_person_4.png width="1000">
</p>

<p align='center'>
  <img title='New person 5' src=images/new_person_5.png width="1000">
</p>

<p align='center'>
  <img title='New person 6' src=images/new_person_6.png width="1000">
</p>

### Mosquitto broker Add-on

We'll use the official Mosquitto broker add-on as the MQTT broker. Click on the badge below then on **Open link**, this opens the add-on in your Home Assistance instance, afterwards click on **Install** to install the Mosquitto broker; this might take a while depending on your internet connection.

[![Open your Home Assistant instance and show the dashboard of an add-on.](https://my.home-assistant.io/badges/supervisor_addon.svg)](https://my.home-assistant.io/redirect/supervisor_addon/?addon=core_mosquitto&repository_url=https%3A%2F%2Fgithub.com%2Fhassio-addons%2Frepository)

<p align='center'>
  <img title='Mosquitto install 1' src=images/mosquitto_install_1.png width="1000">
</p>

Start the add-on once it has been installed,

<p align='center'>
  <img title='Mosquitto install 2' src=images/mosquitto_install_2.png width="1000">
</p>

<p align='center'>
  <img title='Mosquitto install 3' src=images/mosquitto_install_3.png width="1000">
</p>

### MQTT Integration

The next thing we need to do is to setup the MQTT integration. Click on the badge below,

[![Open your Home Assistant instance and start setting up a new integration.](https://my.home-assistant.io/badges/config_flow_start.svg)](https://my.home-assistant.io/redirect/config_flow_start/?domain=mqtt)

This will prompt you to pick what MQTT option you want to add, choose **MQTT**. The next prompt will be to choose
how you want to connect to the MQTT broker, choose **Use the official Mosquitto Mqtt Broker add-on**. This should successfully
create a configuration for Mosquitto.

<p align='center'>
  <img title='MQTT integration 1' src=images/mqtt_int_1.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 2' src=images/mqtt_int_2.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 3' src=images/mqtt_int_3.png width="1000">
</p>

Next click on the **MQTT** integration then on **Configure**. Select **Re-configure MQTT**

<p align='center'>
  <img title='MQTT integration 4' src=images/mqtt_int_4.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 5' src=images/mqtt_int_5.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 6' src=images/mqtt_int_6.png width="1000">
</p>

This will open up the Broker options, here input the username and password you chose for the new person you previously created then click on **Next**. More options are shown here but we will stick to the defaults, click on **Submit** to save the configuration.

<p align='center'>
  <img title='MQTT integration 7' src=images/mqtt_int_7.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 8' src=images/mqtt_int_8.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 9' src=images/mqtt_int_9.png width="1000">
</p>

<p align='center'>
  <img title='MQTT integration 10' src=images/mqtt_int_10.png width="1000">
</p>

With MQTT configured, enable MQTT in the `config.yml` file by providing the host IP address of the computer running Home Assistant and the login credentials for the MQTT broker,

```
mqtt:
  host: 192.168.8.243     # change to your own IP address
  user: mqtt_broker       # change to your broker username
  password: "change_me"   # change to your broker password
  
  ...
```

More sections need to be added to the `config.yml` file before setting up the Frigate integration.

### go2rtc

[go2rtc](https://github.com/AlexxIT/go2rtc) is a camera streaming application which supports a lot of streaming formats like RTSP, RTMP, WebRTC and [more](https://github.com/AlexxIT/go2rtc?tab=readme-ov-file#module-streams).

Adding go2rtc is optional, but if you wish to live stream the camera feed in Home Assistant, go2rtc will need to be configured.

This snippet below shows how go2rtc is configured using RTSP. 

```
go2rtc:
  streams:
    test_cam: # change camera name
      - rtsp://{FRIGATE_RTSP_USER}:{FRIGATE_RTSP_PASSWORD}@192.168.8.201:554/cam/realmonitor?channel=1&subtype=1
      - rtsp://{FRIGATE_RTSP_USER}:{FRIGATE_RTSP_PASSWORD}@yourip:port/channel
```

More information on configuring go2rtc is available in the [documentation](https://docs.frigate.video/guides/configuring_go2rtc/).

### Recording

Frigate offers flexibility on how video is recorded. One can choose to record all video from the camera feed, only save video when motion is detected or only record video when an event is ongoing. This [page](https://docs.frigate.video/configuration/record/) provides detailed information on different configuration permutations for recording in Frigate.

The following configuration only saves video when motion is detected and retains the footage for 30 days.

```
record:
  enabled: True
  retain:
    days: 5
    mode: motion
  events:
    retain:
      default: 30
      mode: motion
```

In the `config.yml`, the `record` role is added to the camera stream with the higher resolution.

```
cameras:
  test_cam: # change camera name
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://{FRIGATE_RTSP_USER}:{FRIGATE_RTSP_PASSWORD}@192.168.8.201:554/cam/realmonitor?channel=1&subtype=0
          roles:
            - record
```

### Detect

If you plan to create automations in Home Assistant using motion events detected by Frigate, the `detect` configuration has to be enabled. A sample automation could be if camera A detects motion from 10 PM, turn on outdoor light A for 10 seconds. The `detect` functionality is optional and can be toggled on and off for each camera in HA after integrating Frigate. The toggle buttons will be shown at the end of the Frigate HA integration [subsection](#frigate-hacs-integration). 

```
detect:
  enabled: True
```

### Snapshots

Snapshots are pictures of an event, in `jpg` format. Enabling snapshots is also optional and like the detect functionality, it can be toggled on and off in Frigate HA integration.

```
snapshots:
  enabled: True
  retain:
    default: 30
```

The full template of this Frigate `config.yml` file and my configuration are available in this repository [here](config.yml) and [here](my_config.yml) respectively.

### Frigate HA Integration

Not all integrations are supported by the HA development team, this is where the Home Assistant Community Store (HACS) comes in. 

From the [HACS website](https://hacs.xyz/), 

> The Home Assistant Community Store (HACS) is a custom integration that provides a UI to manage custom elements in Home Assistant.

They defined a custom element as,

> A custom element is a Home Assistant element (such as an integration, dashboard, theme, or template) that was created by someone from the Community
> and published for others to use at their own risk. Custom elements are not supported by the Home Assistant project. They are not reviewed or tested
> by the Home Assistant development team.


There is a HACS integration for Frigate which we will use to integrate with Home Assistant. HACS can be installed by either following the [docs](https://hacs.xyz/docs/use/) 
or this [YouTube video guide by @smart_home_australia](https://www.youtube.com/watch?v=ISb7Rf1n668).

After installing HACS, open the Frigate HA integration by clicking on the badge below,

[![Open your Home Assistant instance and open a repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner=blakeblackshear&category=integration&repository=frigate-hass-integration)

Then click on **Download** and download the version shown.

<p align='center'>
  <img title='Frigate integration 1' src=images/frigate_int_1.png width="1000">
</p>

<p align='center'>
  <img title='Frigate integration 2' src=images/frigate_int_2.png width="1000">
</p>

Next, restart Home Assistant.

<p align='center'>
  <img title='Frigate integration 3' src=images/frigate_int_3.png width="1000">
</p>

<p align='center'>
  <img title='Frigate integration 4' src=images/frigate_int_4.png width="1000">
</p>

<p align='center'>
  <img title='Frigate integration 5' src=images/frigate_int_5.png width="1000">
</p>

After HA has rebooted, go to **Settings** > **Devices & services**. Click on **Add Integration** and search for **Frigate**.

<p align='center'>
  <img title='Frigate integration 6' src=images/frigate_int_6.png width="1000">
</p>

<p align='center'>
  <img title='Frigate integration 7' src=images/frigate_int_7.png width="1000">
</p>

You will need to input the URL to access Frigate. Either input the IP address or hostname of the Raspberry Pi 5 with port **5000** and click on **Submit**. I chose the hostname `http://frigipi.local:5000`.

<p align='center'>
  <img title='Frigate integration 8' src=images/frigate_int_8.png width="1000">
</p>

A **Success!** message is shown if the configuration is done properly and the integration should find your cameras and Frigate as devices.

<p align='center'>
  <img title='Frigate integration 9' src=images/frigate_int_9.png width="1000">
</p>

The camera configuration options discussed in the previous subsections can be accessed by clicking on **2 Devices** under the Frigate integration, then on **Test Cam**.

<p align='center'>
  <img title='Configuration Toggle 1' src=images/config_toggle_1.png width="1000">
</p>

<p align='center'>
  <img title='Configuration Toggle 2' src=images/config_toggle_2.png width="1000">
</p>

The different options that can be toggled are highlighted below.

<p align='center'>
  <img title='Configuration Toggle 3' src=images/config_toggle_3.png width="1000">
</p>

### Frigate Card

Also using HACS, we can install the Frigate Card which we can use to create a custom dashboard to live view multiple cameras, browse through clips and snapshots through a mini-gallery and more from Frigate.

Click on the badge below to open the HACS Frigate card.

[![Open your Home Assistant instance and open a repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?category=plugin&owner=dermotduffy&repository=frigate-hass-card)

<p align='center'>
  <img title='Frigate card 1' src=images/frigate_card_1.png width="1000">
</p>

Then click on **Download** and download the version shown.

<p align='center'>
  <img title='Frigate card 2' src=images/frigate_card_2.png width="1000">
</p>

You will then be prompted to reload the browser to use the updated resources, click on **Reload**.

<p align='center'>
  <img title='Frigate card 3' src=images/frigate_card_3.png width="1000">
</p>

We are going to create a new dashboard for the Frigate card. Go to **Settings** > **Dashboards**. At the bottom right click on **Add Dashboard** then choose **New dashboard from scratch**.

<p align='center'>
  <img title='Frigate card 4' src=images/frigate_card_4.png width="1000">
</p>

<p align='center'>
  <img title='Frigate card 5' src=images/frigate_card_5.png width="1000">
</p>

<p align='center'>
  <img title='Frigate card 6' src=images/frigate_card_6.png width="1000">
</p>

Choose a title for the dashboard and search for an appropriate icon for it.

<p align='center'>
  <img title='Frigate card 7' src=images/frigate_card_7.png width="1000">
</p>

Open the newly created dashboard and click on edit button in the top right corner.

<p align='center'>
  <img title='Frigate card 8' src=images/frigate_card_8.png width="1000">
</p>

<p align='center'>
  <img title='Frigate card 9' src=images/frigate_card_9.png width="1000">
</p>

Click on **Create section** then on **Add card**.

<p align='center'>
  <img title='Frigate card 10' src=images/frigate_card_10.png width="1000">
</p>

<p align='center'>
  <img title='Frigate card 11' src=images/frigate_card_11.png width="1000">
</p>

Search for **Frigate**, then select **Custom: Frigate card**.

<p align='center'>
  <img title='Frigate card 12' src=images/frigate_card_12.png width="1000">
</p>

Add cameras to the card, in our case we only have **Test Cam**.

<p align='center'>
  <img title='Frigate card 13' src=images/frigate_card_13.png width="1000">
</p>

You can tweak the card layout under the **Layout** tab to display the card in fullscreen, otherwise click on **Save** to create the section. Click on **Done** to create the dashboard.

<p align='center'>
  <img title='Frigate card 14' src=images/frigate_card_14.png width="1000">
</p>

<p align='center'>
  <img title='Frigate card 15' src=images/frigate_card_15.png width="1000">
</p>

The dashboard will display the live feed of the camera. Clicking on the frigate logo brings up different menu options
which are **Frigate Menu**, **Live view**, **Clips gallery**, **Snapshots gallery**, **Timeline view** and **Fullscreen** (if you only have one camera connected). 

<p align='center'>
  <img title='Frigate card 16' src=images/frigate_card_16.png width="1000">
</p>

The Frigate data can also be viewed in the Media browser in Home Assistant. Click on **Media** on the dashboard panels on the left, then on **Frigate**.
**Clips** are videos with motion/object detection, **Recordings** are saved videos depending on your configuration in `config.yml`, while **Snapshots** are pictures of an event.

<p align='center'>
  <img title='Frigate card 17' src=images/frigate_card_17.png width="1000">
</p>

<p align='center'>
  <img title='Frigate card 18' src=images/frigate_card_18.png width="1000">
</p>

### Setup motion masks in Frigate

One of the cool features of Frigate is the ability to create masks of areas of the camera feed to prevent unwanted types of motion from [triggering detection](https://docs.frigate.video/configuration/masks). These regions will be excluded when object detection is performed. An example of such a region is the camera timestamp. We will demonstrate how to setup a motion mask on the camera timestamp.

Back in the Frigate Web UI, go to system settings click on the **Debug** tab and toggle on **Motion Boxes**. This shows red boxes around areas where motion is detected. In the top right corner, you 
can see a red box around the second digits of the timestamp.

<p align='center'>
  <img title='Frigate mask 1' src=images/frigate_mask_1.png width="1000">
</p>

To create a motion mask, click on the **Masks/Zones** tab, then start drawing a polygon around the timestamp. Once you have done this, click on **Save**.

***Note: I encountered some difficulty in closing the polygon around the timestamp, you might have to try a few times to get this to work well.***

<p align='center'>
  <img title='Frigate mask 2' src=images/frigate_mask_2.png width="1000">
</p>

<p align='center'>
  <img title='Frigate mask 3' src=images/frigate_mask_3.png width="1000">
</p>

<p align='center'>
  <img title='Frigate mask 4' src=images/frigate_mask_4.png width="1000">
</p>

We get a confirmation message that the motion mask has been saved and we are prompted to restart Frigate to apply the changes.

<p align='center'>
  <img title='Frigate mask 5' src=images/frigate_mask_5.png width="1000">
</p>

Back in the config editor, the coordinates of the motion mask are included in the `config.yml` file as shown below.

<p align='center'>
  <img title='Frigate mask 6' src=images/frigate_mask_6.png width="1000">
</p>

Save the configuration and restart the Frigate container to effect the changes.

<p align='center'>
  <img title='Frigate mask 7' src=images/frigate_mask_7.png width="1000">
</p>

The GIF below confirms that the motion mask worked as there are no red boxes around the timestamp.

<p align='center'>
  <img title='Frigate after mask' src=images/frigate_after_mask.gif width="1000">
</p>

## Long term NVR solution

We have successfully setup Frigate to run a Raspberry Pi 5 using Geekworm's X1004 Dual NVMe SSD Shield with the PCIe Google Coral Edge TPU. We also integrated Frigate with Home Assistant. Frigate works well enough **out of the box** but you can consult the [full reference config](https://docs.frigate.video/configuration/reference) and related configuration guides to tune Frigate for better performance. This [YouTube video by @HomeAutomationGuy](https://www.youtube.com/watch?v=gRCtvRsTHm0) is a good place to start.

I considered using this hardware setup as a long term NVR solution with 3 cameras, so I got [Geekworm's X1202 Uninterruptible Power Supply (UPS) shield](https://wiki.geekworm.com/X1202) and their X1202-C1 metal case.
The X1202 provides backup power using 4x 18650 Li-ion batteries and other features which can read about [here](https://wiki.geekworm.com/X1202#Overview).

<p align='center'>
  <img title='Geekworm UPS' src=images/geekworm_ups.png width="1000">
</p>

<p align='center'>
  <img title='Geekworm UPS with batteries' src=images/geekworm_ups_batteries.png width="1000">
</p>

The assembly guide for the UPS Shield and the metal case are also available in the [User Manual section](https://wiki.geekworm.com/X1202#User_Manual) of the X1202 Geekworm wiki. I might consider getting a backup power system to run the HA PC, router and POE switch in case the power goes out.

<p align='center'>
  <img title='Geekworm UPS assembled' src=images/geekworm_ups_assembled.png width="1000">
</p>

<p align="center">
  <img title='Metal case power plugged in' src=images/metal_case_plugged.JPG width="1000">
</p>

<p align="center">
  <img title='Metal case power unplugged' src=images/metal_case_unplugged.JPG width="1000">
</p>

One final thing to setup are mobile notifications to notify you of any objects detected by Frigate. This [Home Assistant blueprint](https://community.home-assistant.io/t/frigate-mobile-app-notifications-2-0/559732) can be used to setup 
Frigate mobile app notifications but at the time of writing this guide, I was not able to get it to work. It worked initially but stopped after a few minutes. 

## Temperature graphs

Out of curiosity, I wanted to compare how hot the Google Coral Edge TPU gets when Frigate is running. I plotted the temperature data with the Raspberry Pi without the active cooler, with the active
cooler and finally the active cooler in the X1202-C1 metal case. I'm using the active cooler from Argon 40. 

<p align="center">
  <img title='Argon active cooler' src=images/argon_active_cooler.jpg width="1000">
</p>

The TPU temperature data can be accessed from an entity in Home Assistant. From the [Home Assistant terminology page](https://www.home-assistant.io/getting-started/concepts-terminology/#entities
),

> Entities are the basic building blocks to hold data in Home Assistant. An entity represents a sensor, actor, or function in Home Assistant. Entities are used to monitor physical properties 
> or to control other entities. An entity is usually part of a device or a service. Entities have states.

More information about entities can be found in the [glossary](https://www.home-assistant.io/docs/glossary/#entity).

The Google Coral Edge TPU is the device and has its temperature as an entity. Other entities are the coral inference speed and detection frames per second (fps).
By default the TPU temperature entity is disabled. To enable it, go to **Settings** > **Devices & services** click on **2 Devices** 
under the Frigate integration, then on **Frigate**. Under **Diagnostic** click on **+4 entities not shown**.

<p align='center'>
  <img title='Frigate apex temp enable 1' src=images/frigate_apex_temp_1.png width="1000">
</p>

<p align='center'>
  <img title='Frigate apex temp enable 2' src=images/frigate_apex_temp_2.png width="1000">
</p>

<p align='center'>
  <img title='Frigate apex temp enable 3' src=images/frigate_apex_temp_3.png width="1000">
</p>

Click on **Apex 0 temperature**, then on the gear button and finally on **Enable** to enable the entity. 

<p align='center'>
  <img title='Frigate apex temp enable 4' src=images/frigate_apex_temp_4.png width="1000">
</p>

<p align='center'>
  <img title='Frigate apex temp enable 5' src=images/frigate_apex_temp_5.png width="1000">
</p>

<p align='center'>
  <img title='Frigate apex temp enable 6' src=images/frigate_apex_temp_6.png width="1000">
</p>

Click on **Ok** then on **Update** to effect the changes.

<p align='center'>
  <img title='Frigate apex temp enable 7' src=images/frigate_apex_temp_7.png width="1000">
</p>

<p align='center'>
  <img title='Frigate apex temp enable 8' src=images/frigate_apex_temp_8.png width="1000">
</p>

This is how the **Diagnostic** section looks like after enabling all the Google Coral TPU entities. 

<p align='center'>
  <img title='Frigate apex temp enable 9' src=images/frigate_apex_temp_9.png width="1000">
</p>

Now that we have enabled the TPU temperature entity, we can use this data to plot our temperature graphs. We'll be using the Plotly Graph Card from HACS to achieve this.

Click on the badge below to open the Plotly Graph Card,

[![Open your Home Assistant instance and open a repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner=dbuezas&category=card&repository=lovelace-plotly-graph-card)


<p align='center'>
  <img title='Plotly graph 1' src=images/plotly_graph_1.png width="1000">
</p>

Click on **Download** and download the version shown, then reload your browser.

<p align='center'>
  <img title='Plotly graph 2' src=images/plotly_graph_2.png width="1000">
</p>

<p align='center'>
  <img title='Plotly graph 3' src=images/plotly_graph_3.png width="1000">
</p>

Next create a new dashboard and add the **Custom: Plotly Graph Card** to the card section.

<p align='center'>
  <img title='Plotly graph 4' src=images/plotly_graph_4.png width="1000">
</p>

Give the graph a title, for the hours to show, I used `0.25` which means that it will show data over a 15 minute rolling window. Under **Entities**, choose **Frigate Apex 0 temperature**, then save the configuration.
<p align='center'>
  <img title='Plotly graph 5' src=images/plotly_graph_5.png width="1000">
</p>

<p align='center'>
  <img title='Plotly graph 6' src=images/plotly_graph_6.png width="1000">
</p>

The temperature is plotted on the y-axis in degree Celsuis and time on the x-axis in minutes.

<p align='center'>
  <img title='Plotly graph 7' src=images/plotly_graph_7.png width="1000">
</p>

To keep the test conditions fairly constant,

- I had no external fan or air conditioning on in the room the Pi 5 was in
- Frigate was working on a live feed of me in the room, and 
- I shutdown the Pi before each test and allowed it to cool down.

And these are the results.

<p align="center">
  <img title='Temp test no fan' src=images/temp_test_no_fan.png width="1000">
</p>

<p align="center">
  <img title='Temp test with fan' src=images/temp_test_fan.png width="1000">
</p>

<p align="center">
  <img title='Temp test with fan and metal case' src=images/temp_test_fan_metal_case.png width="1000">
</p>

As you probably guessed, the coral temperature, without the active cooler climbed steadily, to over 60 degrees in this test; it was hot to touch. 

The best configuration is the Pi 5 with the active cooler without the case. Here the active cooler fan levels the coral temperature around 55 degrees. 

The metal case setup does not dissipate heat as fast, the temperature flattens around 60 degrees Celsuis. 

Having an external fan or air conditioning in the room should bring down the Coral TPU temperature regardless of the setup.But turning on an external fan or air conditioning should bring down the Coral TPU temperature even more regardless of the setup.

## Project demo

A video below walk through the steps of setting up Frigate on the Raspberry Pi 5 using Geekworm's X1004 Dual NVMe SSD Shield with the PCIe Google Coral Edge TPU.

[<img src="images/thumbnail.png" width="80%">](https://youtu.be/GZTiWnuYwOc)

### Reference Links

#### Geekworm related:

- [Geekworm X1004](https://wiki.geekworm.com/X1004)
- [Geekworm X1202](https://wiki.geekworm.com/X1202)
- [Incompatible NVMe SSD drive and NVMe SSD boot setup](https://wiki.geekworm.com/NVMe_SSD_boot_with_the_Raspberry_Pi_5)
- [How to update EEPROM firmware](https://wiki.geekworm.com/How_to_update_eeprom_firmware)
- [NVMe SSD boot with the Raspberry Pi 5](https://wiki.geekworm.com/NVMe_SSD_boot_with_the_Raspberry_Pi_5)

#### Frigate related:

- [Official Frigate Installation Docs](https://docs.frigate.video/frigate/installation/)
- [Recommended Frigate Hardware](https://docs.frigate.video/frigate/hardware/)
- [Installing Frigate on Raspberry Pi 5](https://pineboards.io/blogs/tutorials/installing-frigate-on-raspberry-pi-5-with-a-google-coral-tpu)
- [Frigate camera setup](https://docs.frigate.video/frigate/camera_setup/#example-camera-configuration)
- [Frigate full reference configuration](https://docs.frigate.video/configuration/reference)
- [Frigate video pipeline](https://docs.frigate.video/frigate/video_pipeline/)
- [Choosing a detect resolution](https://docs.frigate.video/frigate/camera_setup/#choosing-a-detect-resolution)
- [Frigate record](https://docs.frigate.video/configuration/record/)
- [Available objects](https://docs.frigate.video/configuration/objects/)
- [Frigate+](https://frigate.video/plus/)
- [Building Frigate With Google Coral TPU, Portainer, Docker On A Raspberry Pi 5 with NFS Storage & Home Assistant Integration](https://automation.baldacchino.net/building-frigate-with-google-coral-tpu-portainer-docker-on-a-raspberry-pi-5-with-nfs-storage-home-assistant-integration/)
- [Coral AI Person Detection with Home Assistant & Frigate](https://www.youtube.com/watch?v=xwFfcw5vmTU)
- [AI on a Pi? Believe it!](https://www.youtube.com/watch?v=so8_h0EKPWU)

#### Coral related:

- [Google Coral](https://coral.ai/products/)
- [Installing PyCoral for Google Coral on Raspberry Pi 5](https://pineboards.io/blogs/tutorials/installing-pycoral-for-google-coral-on-raspberry-pi-5)
- [Run a model on Edge TPU](https://coral.ai/docs/m2/get-started/#4-run-a-model-on-the-edge-tpu)
- [Boot config to allow the Pi to detect the Coral TPU PCIe](https://forums.raspberrypi.com/viewtopic.php?t=363682&start=25)

#### Raspberry Pi related:

- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- [Recommended SD cards](https://www.raspberrypi.com/documentation/computers/getting-started.html)
- [How to test sd card speed on Raspberry Pi](https://linuxconfig.org/how-to-test-sd-card-speed-on-raspberry-pi)
- [Updating the Bootloader on a Raspberry Pi](https://pimylifeup.com/raspberry-pi-bootloader/)

#### Dahua IP camera related:

- [Dahua IP camera setup with remote view - no NVR- step by step](https://www.youtube.com/watch?v=JxTM-Ja2SI8)
- [Dahua camera RTSP link](https://dahuawiki.com/Remote_Access/RTSP_via_VLC)

#### Linux related:

- [60 Linux Commands you NEED to know (in 10 minutes)](https://www.youtube.com/watch?v=gd7BXuUQ91w)
- [100+ Linux Things you Need to Know](https://www.youtube.com/watch?v=LKCVKw9CzFo)
- [Introduction to Linux and Basic Linux Commands for Beginners](https://www.youtube.com/watch?v=IVquJh3DXUA)

#### Docker related:

- [Docker Crash Course for Absolute Beginners](https://www.youtube.com/watch?v=pg19Z8LL06w)
- [What is Docker?](https://docs.docker.com/get-started/docker-overview/)

#### MQTT related:
- [HiveMQ](https://www.hivemq.com/mqtt/)
- [HiveMQ MQTT Essentials playlist](https://www.youtube.com/playlist?list=PLRkdoPznE1EMXLW6XoYLGd4uUaB6wB0wd)
- [MQTT Basics: What is MQTT and How Does it Work?](https://www.youtube.com/watch?v=z4r4hIZcp40&t=14s)

#### Home Assistant related:

- [Home Assistant](https://www.home-assistant.io/)
- [ Home Assistant Setup Made Easy: The Ultimate Guide](https://www.youtube.com/watch?v=Y38qRYYAwAI)
- [HACS](https://hacs.xyz/)
- [Install HACS in Home Assistant](https://www.youtube.com/watch?v=ISb7Rf1n668)
- [Add-ons](https://www.home-assistant.io/getting-started/concepts-terminology/#add-ons)
- [Integrations](https://www.home-assistant.io/getting-started/concepts-terminology/#integrations)
- [Entities](https://www.home-assistant.io/docs/glossary/#entity)
- [Frigate HA mobile notifications](https://community.home-assistant.io/t/frigate-mobile-app-notifications-2-0/559732)
- [Home Assistant Plotly Graph Card - Installation, Simple and Advanced features](https://www.youtube.com/watch?v=m0NCgkynPNY)