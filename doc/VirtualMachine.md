# Virtual Machine

PBot can interact with a virtual machine to safely execute arbitrary user-submitted
system commands and code.

This document will guide you through installing and configuring a virtual machine
by using the widely available [libvirt](https://libvirt.org) project tools, such as
`virt-install`, `virsh`, `virt-manager`, `virt-viewer`, etc.

If you're more comfortable working with QEMU directly instead, feel free to do that.
I hope this guide will answer everything you need to know to set that up. If not,
open an GitHub issue or /msg me on IRC.

Some quick terminology:

 * host: your physical Linux system hosting the virtual machine
 * guest: the Linux system installed inside the virtual machine

The commands below will be prefixed with `host$` or `guest$` to reflect where
the command should be executed.

Many commands can be configured with environment variables. If a variable is
not defined, a sensible default value will be used.

Environment variable | Default value | Description
--- | --- | ---
PBOTVM_DOMAIN | `pbot-vm` | The libvirt domain identifier
PBOTVM_SERVER | `9000` | `vm-server` port for incoming `vm-client` commands
PBOTVM_SERIAL | `5555` | TCP port for serial communication
PBOTVM_HEART  | `5556` | TCP port for serial heartbeats
PBOTVM_CID    | `7` | Context ID for VM socket (if using VSOCK)
PBOTVM_VPORT  | `5555` | VM socket service port (if using VSOCK)
PBOTVM_TIMEOUT | `10` | Duration before command times out (in seconds)
PBOTVM_NOREVERT | not set | If set then the VM will not revert to previous snapshot

## Initial virtual machine set-up
These steps need to be done only once during the first-time set-up.

### Prerequisites
#### CPU Virtualization Technology
Ensure CPU Virtualization Technology is enabled in your motherboard BIOS.

    host$ egrep '(vmx|svm)' /proc/cpuinfo

If you see your CPUs listed with `vmx` or `svm` flags, you're good to go.
Otherwise, consult your motherboard manual to see how to enable VT.

#### KVM
Ensure KVM is set up and loaded.

    host$ kvm-ok
    INFO: /dev/kvm exists
    KVM acceleration can be used

If you see the above, everything's set up. Otherwise, consult your operating
system manual or KVM manual to install and load KVM.

#### libvirt and QEMU
Ensure libvirt and QEMU are installed and ready.

    host$ virsh version --daemon
    Compiled against library: libvirt 7.6.0
    Using library: libvirt 7.6.0
    Using API: QEMU 7.6.0
    Running hypervisor: QEMU 6.0.0
    Running against daemon: 7.6.0

If there's anything missing, please consult your operating system manual to
install the libvirt and QEMU packages.

On Ubuntu: `sudo apt install qemu-kvm libvirt-daemon-system`

#### Make a pbot-vm user or directory
You can either make a new user account or make a new directory in your current user account.
In either case, name it `pbot-vm` so we'll have a home for the virtual machine.

#### Add libvirt group to your user
Add your user (or the `pbot-vm` user) to the `libvirt` group.

    host$ sudo adduser $USER libvirt

Log out and then log back in for the new group to take effect.

#### Download Linux ISO
Download a preferred Linux ISO. For this guide, we'll use Fedora. Why?
I'm using Fedora Rawhide for my PBot VM because I want convenient and reliable
access to the latest bleeding-edge versions of software.

I recommend using the Fedora Stable net-installer for this guide unless you
are more comfortable in another Linux distribution. Make sure you choose
the minimal install option without a graphical desktop.

https://download.fedoraproject.org/pub/fedora/linux/releases/35/Server/x86_64/iso/Fedora-Server-netinst-x86_64-35-1.2.iso
is the Fedora Stable net-installer ISO used in this guide.

### Create a new virtual machine
To create a new virtual machine we'll use the `virt-install` command.

* First, ensure you are the `pbot-vm` user or that you have changed your current working directory to `pbot-vm`. The Linux ISO downloaded earlier should be present in this location.

Execute the following command:

    host$ virt-install --name=pbot-vm --disk=size=12,path=vm.qcow2 --cpu=host --os-variant=fedora34 --graphics=spice --video=virtio --location=Fedora-Server-netinst-x86_64-35-1.2.iso

Note that `disk=size=12` will create a 12 GB sparse file. Sparse means the file
won't actually take up 12 GB. It will start at 0 bytes and grow as needed. You can
use the `du` command to verify this. After a minimal Fedora install, the size will be
approximately 1.7 GB. It will grow to about 2.5 GB with all PBot features installed.

For further information about `virt-install`, read its manual page. While the above command should
give sufficient performance and compatability, there are a great many options worth investigating
if you want to fine-tune your virtual machine.

#### Install Linux in the virtual machine
After executing the `virt-install` command above, you should now see a window
showing Linux booting up and launching an installer. For this guide, we'll walk
through the Fedora 35 installer. You can adapt these steps for your own distribution
of choice.

 * Click `Partition disks`. Don't change anything. Click `Done`.
 * Click `Root account`. Click `Enable root account`. Set a password. Click `Done`.
 * Click `User creation`. Create a new user. Skip Fullname and set Username to `vm`. Untick `Add to wheel` or `Set as administrator`. Untick `Require password`. Click `Done`.
 * Wait until `Software selection` is done processing and is no longer greyed out. Click it. Change install from `Server` to `Minimal`. Click `Done`.
 * Click `Begin installation`.

Installation will need to download about 328 RPMs consisting of about 425 MB. It'll take 5 minutes to an hour or longer
depending on your hardware and network configuration.

#### Set up serial ports
While the installation is in progress, switch to a terminal on your host system. Go into the
`applets/pbot-vm/host/devices` directory and run the `add-serials` script to add the `serial-2.xml` and
`serial-3.xml` files to the configuration for the `pbot-vm` libvirt machine.

    host$ ./add-serials

This will enable the `/dev/ttyS1` and `/dev/ttyS2` serial ports in the guest and connect them
to the following TCP addresses on the host: `127.0.0.1:5555` and `127.0.0.1:5556`,
respectively. `ttyS1/5555` is the data channel used to send commands or code to the
virtual machine and to read back output. `ttyS2/5556` is simply a newline sent every
5 seconds, representing a heartbeat, used to ensure that the PBot communication
channel is healthy.

You may use the `PBOTVM_DOMAIN`, `PBOTVM_SERIAL` and `PBOTVM_HEART` environment variables to override
the default values. To use ports `7777` and `7778` instead:

    host$ PBOTVM_SERIAL=7777 PBOTVM_HEART=7778 ./add-serials

If you later want to change the serial ports or the TCP ports, execute the command
`virsh edit pbot-vm` on the host. This will open the `pbot-vm` XML configuration
in your default system editor. Find the `<serial>` tags and edit their attributes.

#### Set up virtio-vsock
VM sockets (AF_VSOCK) are a Linux-specific feature (at the time of this writing). They
are the preferred way for PBot to communicate with the PBot VM Guest server. Serial communication
has several limitations. See https://vmsplice.net/~stefan/stefanha-kvm-forum-2015.pdf for an excellent
overview.

To use VM sockets with QEMU and virtio-vsock, you need:

* a Linux hypervisor with kernel 4.8+
* a Linux virtual machine on that hypervisor with kernel 4.8+
* QEMU 2.8+ on the hypervisor, running the virtual machine
* [socat](http://www.dest-unreach.org/socat/) version 1.7.4+

If you do not meet these requirements, the PBot VM will fallback to using serial communication. You may
explicitly disable VM sockets by setting `PBOTVM_CID=0`. You can skip reading the rest of this section.

If you do want to use VM sockets, read on.

First, ensure the `vhost_vsock` Linux kernel module is loaded on the host:

    host$ lsmod | grep vsock
    vhost_vsock            24576  1
    vsock                  45056  2 vmw_vsock_virtio_transport_common,vhost_vsock
    vhost                  53248  2 vhost_vsock,vhost_net

If the module is not loaded, load it with:

    host$ sudo modprobe vhost_vsock

Once the module is loaded, you should have the following character devices:

    host$ ls -l /dev/vhost-vsock
    crw------- 1 root root 10, 53 May  4 11:55 /dev/vhost-vsock
    host$ ls -l /dev/vsock
    crw-rw-rw- 1 root root 10, 54 May  4 11:55 /dev/vsock

A VM sockets address is comprised of a context ID (CID) and a port; just like an IP address and TCP/UDP port.
The CID is represented using an unsigned 32-bit integer. It identifies a given machine as either a hypervisor
or a virtual machine. Several addresses are reserved, including 0, 1, and the maximum value for a 32-bit
integer: 0xffffffff. The hypervisor is always assigned a CID of 2, and VMs can be assigned any CID between 3
and 0xffffffff — 1.

We must attach a `vhost-vsock-pci` device to the guest to enable VM sockets communication.
Each VM on a hypervisor must have a unique context ID (CID). Each service within the VM must
have a unique port. The PBot VM Guest defaults to `7` for the CID and `5555` for the port.

While still in the `applets/pbot-vm/host/devices` directory, run the `add-vsock` script:

    host$ ./add-vsock

or to configure a different CID:

    host$ PBOTVM_CID=42 ./add-vsock

In the VM guest (once it reboots), there should be a `/dev/vsock` device:

    guest$ ls -l /dev/vsock
    crw-rw-rw- 1 root root 10, 55 May  4 13:21 /dev/vsock

#### Reboot virtual machine
Once the Linux installation completes inside the virtual machine, click the `Reboot` button
in the installer window. Login as `root` when the virtual machine boots back up.

#### Install software
Now we can install any software and programming languages we want to make available
in the virtual machine. Use the `dnf search` command or your distribution's documentation
to find packages. I will soon make available a script to install all package necessary for all
languages supported by PBot.

To make use of VM sockets, install the `socat` package:

    guest$ dnf install socat

For the C programming language you will need at least these:

    guest$ dnf install libubsan libasan gdb gcc clang

#### Install Perl
Now we need to install Perl on the guest. This allows us to run the PBot VM Guest server
script.

    guest$ dnf install perl-interpreter perl-lib perl-IPC-Run perl-JSON-XS perl-English perl-IPC-Shareable

That installs the minium packages for the Perl interpreter (note we used `perl-interpreter` instead of `perl`),
as well as a few Perl modules.

#### Install PBot VM Guest
Next we install the PBot VM Guest server script that fosters communication between the virtual machine guest
and the physical host system. We'll do this inside the virtual machine guest system, logged on as `root`
while in the `/tmp` directory.

    guest$ cd /tmp

The `rsync` command isn't installed with a Fedora minimal install, but `scp` is available. Replace
`192.168.100.42` below with your own local IP address; `user` with the user account that has the
PBot directory; and `pbot` with the path to the directory.

    guest$ scp -r user@192.168.100.42:~/pbot/applets/pbot-vm/guest .

Once that's done, run the following command:

    guest$ ./guest/bin/setup-guest

This will install `guest-server` to `/usr/local/bin/`, set up some environment variables and
harden the guest system. After running the `setup-guest` script, we need to make the environment
changes take effect:

    guest$ source /root/.bashrc

We no longer need the `/tmp/guest/` stuff. We can delete it:

    guest$ rm -rf guest/

#### Start PBot VM Guest
We're ready to start the PBot VM Guest server. On the guest, as `root`, execute the command:

    guest$ guest-server

This starts up a server to listen for incoming commands or code and to handle them. We'll leave
this running.

#### Test PBot VM Guest
Let's make sure everything's working up to this point. On the host, there should
be two open TCP ports on `5555` and `5556`. On the host, execute the command:

    host$ nc -zv 127.0.0.1 5555-5556

If it says anything other than `Connection succeeded` then make sure you have completed the steps
under [Set up serial ports](#set-up-serial-ports) and that your network configuration is allowing
access.

Let's make sure the PBot VM Guest server is listening for and can execute commands. The `vm-exec` command
allows you to send commands from the shell. Change your current working directory to `applets/pbot-vm/host/bin`
and run the `vm-exec` command:

    host$ cd applets/pbot-vm/host/bin
    host$ ./vm-exec -lang=sh echo hello world

This should output some logging noise followed by "hello world". You can test other language modules
by changing the `-lang=` option. I recommend testing and verifying that all of your desired language
modules are configured before going on to the next step.

If you have multiple PBot VM Guests, or if you used a different TCP port, you can specify the
`PBOTVM_SERIAL` environment variable when executing the `vm-exec` command:

    host$ PBOTVM_SERIAL=7777 ./vm-exec -lang=sh echo test

#### Save initial state
Switch back to an available terminal on the physical host machine. Enter the following command
to save a snapshot of the virtual machine waiting for incoming commands.

* Before doing this step, ensure all commands are cached by executing them at least once. For example, the `gcc` and `gdb` commands take a long time to load into memory. The initial execution may take a several long seconds to complete. Once completed, the command will be cached. Future invocations will execute significantly quicker.

<!-- -->

    host$ virsh snapshot-create-as pbot-vm 1

If the virtual machine ever times-out or its heartbeat stops responding, PBot
will revert the virtual machine to this saved snapshot.

### Initial virtual machine set-up complete
This concludes the initial one-time set-up. You can close the `virt-viewer` window. The
virtual machine will continue running in the background until it is manually shutdown (via
`shutdown now -h` inside the VM or via `virsh shutdown pbot-vm` on the host).

## Start PBot VM Host
To start the PBot VM Host server, change your current working directory to `applets/pbot-vm/host/bin`
and execute the `vm-server` script:

    host$ cd applets/pbot-vm/host/bin
    host$ ./vm-server

This will start a TCP server on port `9000`. It will listen for incoming commands and
pass them along to the virtual machine's TCP serial port `5555`. It will also monitor
the heartbeat port `5556` to ensure the PBot VM Guest server is alive.

You may override any of the defaults by setting environment variables. For example, to
use `other-vm` with a longer `30` second timeout, on different serial and heartbeat ports:

    host$ PBOTVM_DOMAIN="other-vm" PBOTVM_SERVER=9001 PBOTVM_SERIAL=7777 PBOTVM_HEART=7778 PBOTVM_TIMEOUT=30 ./vm-server

### Test PBot
All done. Everything is set up now.

PBot is already preconfigured with commands that invoke the `host/bin/vm-client`
script to send VM commands to `vm-server` on the default port `9000`:

     <pragma-> factshow sh
        <PBot> [global] sh: /call cc -lang=sh
     <pragma-> factshow cc
        <PBot> [global] cc: /call vm-client {"nick":"$nick:json","channel":"$channel:json","code":"$args:json"}
     <pragma-> factshow vm-client
        <PBot> [global] vm-client: pbot-vm/host/bin/vm-client [applet]

In your instance of PBot, the `sh echo hello` command should output `hello`.

    <pragma-> sh echo hello
       <PBot> hello
