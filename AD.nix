# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
 
{ config, secrets, pkgs, lib, modulesPath, ... }:

with lib;

 let
  # Adjust these values to suit the site.
  adDomain = "Sample.Full.Domain.name";
  adWorkgroup = "WORKGROUP";
  adNetbiosName = "AD";
  AdContainerIp = "127.0.0.1";
  hostServerIp = "127.0.0.2"; 

  samba = config.services.samba.package;

in {
  imports =
    [
      # Include the default lxd configuration.
      "${modulesPath}/virtualisation/lxc-container.nix"
      ./hardware-configuration.nix
    ];
 
  # Disable resolveconf, we're using Samba internal DNS backend
  systemd.services.resolvconf.enable = false;
  environment.etc = {
    "resolv.conf" = {
      text = ''
        search ${adDomain}
        nameserver ${AdContainerIp}
      '';
    };
  };
 
  # Rebuild Samba with LDAP, MDNS and Domain Controller support
  nixpkgs.overlays = [ (self: super: {
    samba = (super.samba.override {
      enableLDAP = true;
      enableMDNS = true;
      enableDomainController = true;
      enableProfiling = true; 
    });
  })];
 
  # Disable default Samba `smbd` service, we will be using the `samba` server binary
  systemd.services.samba-smbd.enable = false;  
  systemd.services.samba = {
    description = "Samba Service Daemon";
 
    requiredBy = [ "samba.target" ];
    partOf = [ "samba.target" ];
 
    serviceConfig = {
      ExecStart = "${samba}/sbin/samba --foreground --no-process-group";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      LimitNOFILE = 16384;
      PIDFile = "/run/samba.pid";
      Type = "notify";
      NotifyAccess = "all"; #may not do anything...
    };
    unitConfig.RequiresMountsFor = "/var/lib/samba";
  };
 
  services.samba = {
    enable = true;
    enableNmbd = false;
    enableWinbindd = false;
    openFirewall = true;
    configText = ''
      # Global parameters
      [global]
          dns forwarder = ${hostServerIp}
          netbios name = ${adNetbiosName}
          realm = ${toUpper adDomain}
          server role = active directory domain controller
          workgroup = ${adWorkgroup}
          idmap_ldb:use rfc2307 = yes
          dns update command = ${samba}/sbin/samba_dnsupdate --use-samba-tool
          log level = 1 
 
      [sysvol]
          path = /var/lib/samba/sysvol
          read only = No
 
      [netlogon]
          path = /var/lib/samba/sysvol/${adDomain}/scripts
          read only = No
    '';
  };  
 
  time.timeZone = "America/Vancouver";
 
  i18n.defaultLocale = "en_CA.UTF-8";
 
  networking = {
    hostName = "${adNetbiosName}";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "${AdContainerIp}";
        prefixLength = 16;
      }];
    defaultGateway = {
      address = "${hostServerIp}";
      interface = "eth0";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 53 88 135 389 464 636 3268 3269 ];
      allowedTCPPortRanges = [ {from = 49152; to = 65535;} ];
      allowedUDPPorts = [ 53 88 137 138 389 464];
      allowPing = true;
    }; 
  };
 
  services.openssh.enable = true;
 
  environment.systemPackages = with pkgs; [
    vim
    git
    git-crypt
  ];
 
  # Enable system auto upgrade
  system.autoUpgrade = { 
    enable = true;
    dates = "Tue *-*8..14"; # Patch Tuesday!
    allowReboot = true;
    flake = "github:hegz/ActiveDirectory";
    flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
    rebootWindow = {
      lower = "00:00";
      upper = "02:00";
    };
  };  
 
  # enable automatic GC
  nix = { 
    gc = { 
      automatic = true;
      dates = "Tue *-*8..14 2:00:00";
      options = "--delete-older-than 7d";
    };  
    optimise = {
      automatic = true;
      dates = [ "Tue *-*8..14 3:00:00" ];
    };
    settings = { 
      experimental-features = [ "nix-command" "flakes" ];
    };
  };  
 
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.${secrets.user.name} = {
    isNormalUser = true;
    home = "/home/${secrets.user.name}";
    description = "Administrative User";
    extraGroups = [ "wheel" ];
    hashedPassword = "${secrets.user.hashed-password}";
  };
 
  system.stateVersion = "23.11"; # Did you read the comment?
}
