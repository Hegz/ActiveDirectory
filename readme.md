# Active Directory NixOS container
This is a configuration to run Active Directory from a LXC Container on NixOS.

**!!This is currently untested!!**

## Setup
Notes on getting the container setup.
### Initialise Container

Create, start, and connect to the container.

    $ sudo lxc-create --name ActiveDirectory --template download -- --dist nixos --release 24.05 --arch amd64
    $ sudo lxc-start --name ActiveDirectory
    $ sudo lxc-attach --name ActiveDirectory

Start a shell with vim, git & git-crypt.

	# cd
	# nix-shell -p vim git git-crypt

Download the config   

    # git clone https://github.com/hegz/ActiveDirectory

Decrypt Secrets

    # echo SuperSecretBase64EncodedKey | base64 --decode > ./secret-key
    # git-crypt unlock ./secret-key

Edit the top of configuration.nix to match your site
     
    # cd ActiveDirectory
    # vim configuration.nix
    
Switch to the new configuration

    # nixos-rebuild switch -I /root/ActiveDirectory

Rebuild once more to enable the flake, and lock package versions

    # nixos-rebuild switch --flake .

Disconnect from the container, and restart

    # exit
    # exit
    $ sudo lxc-stop --name ActiveDirectory
    $ sudo lxc-start --name ActiveDirectory

### Fresh domain
Connect to the container via SSH

    $ ssh USERNAME@ActiveDirectory
    
Run the following commands to Initialise a fresh Domain.
 
    $ samba-tool domain provision --use-rfc2307 --realm=Sample.Full.Domain.name --domain=WORKGROUP --server-role=dc --dns-backend=SAMBA_INTERNAL

Note the output from this command contains a randomised Administrator password.  Use that when prompted for the following commands.  Adjust **ad.Sample.Full.Domain.name** and **0.0.127** to match the config file.
  
