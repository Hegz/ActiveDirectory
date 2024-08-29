# Active Directory NixOS container
This is a configuration to run Samba Active Directory from a LXC Container on NixOS.

## Setup
Notes on getting the container setup.
### Initialise Container

Create the container, start it and collect the generated MAC address

    sudo lxc-create --name ActiveDirectory --template download -- --dist nixos --release 24.05 --arch amd64
    sudo lxc-start --name ActiveDirectory --foreground
    ...
    ip addr
    shutdown

Add the following to the container config

    lxc.start.auto = 1
    
    lxc.net.0.link = br0
    lxc.net.0.hwaddr = yo:ur:ma:ca:dd:r1
    lxc.net.0.ipv4.address = 454.734.963.361/45
    lxc.net.0.ipv4.gateway = 454.734.963.1

Start and attach to the container
    
    sudo lxc-start --name ActiveDirectory
    sudo lxc-attach --name ActiveDirectory

Start a shell with vim, git & git-crypt.

    cd /root
    nix-shell -p vim git git-crypt

Download the config   

    git clone https://github.com/hegz/ActiveDirectory

Decrypt Secrets

    echo SuperSecretBase64EncodedKey | base64 --decode > ./secret-key
    cd ActiveDirectory
    git-crypt unlock ../secret-key
    rm ../secret-key

copy Stage 1 configuration into place, and rebuild

    cp configuration.nix /etc/nixos/
    nixos-rebuild switch

Exit, then stop/start the container & reenter

    exit
    exit
    sudo lxc-stop --name ActiveDirectory
    sudo lxc-start --name ActiveDirectory
    sudo lxc-attach --name ActiveDirectory

Edit the top of AD.nix to match your site

    cd /root/ActiveDirectory
    vim AD.nix

add changes to local repo

    git add AD.nix
    
Switch to the final configuration

    nixos-rebuild switch --flake .

Exit and connect to our container via SSH

    exit
    
    ssh USERNAME@ActiveDirectory
    sudo -s
    
Run the following commands to Initialise a fresh Domain.
 
    samba-tool domain provision --use-rfc2307 --realm=Sample.Full.Domain.name --domain=WORKGROUP --server-role=dc --dns-backend=SAMBA_INTERNAL

The last lines of this command contain some important info about the domain.   Save this for future use.
in /root/ActiveDirectory/secrets/domain_info

Start the Samba service

    systemctl start samba.service

Create the local DNS zone for AD to manage.

    samba-tool dns zonecreate ad.Sample.Full.Domain.name 963.734.434.in-addr.arpa -U Administrator
    samba-tool dns add ad.Sample.Full.Domain.name 963.734.434.in-addr.arpa 5 PTR ad.Sample.Full.Domain.name -U Administrator
