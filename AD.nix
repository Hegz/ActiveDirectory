# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
 
{ config, secrets, pkgs, lib, modulesPath, ... }:

with lib;

 let
  siteConfig = import ./SiteConfig.nix;
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
        search ${siteConfig.adDomain}
        nameserver ${siteConfig.AdContainerIp}
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
  
  # Enable Samba service and setup for Active Directory Domain Controller.
  services.samba = {
    enable = true;
    nmbd.enable = false;
    winbindd.enable = false;
    openFirewall = true;
    settings = {
      global = {
        "dns forwarder" = "${siteConfig.hostServerIp}";
        "netbios name" = "${siteConfig.adNetbiosName}";
        realm = "${toUpper siteConfig.adDomain}";
        "server role" = "active directory domain controller";
        workgroup = "${siteConfig.adWorkgroup}";
        "idmap_ldb:use rfc2307" = "yes";
        "dns update command" = "${samba}/sbin/samba_dnsupdate --use-samba-tool";
        "log level" = 1;
      };
      sysvol = { 
          path = "/var/lib/samba/sysvol";
          "read only" = "No";
      };
      netlogon = {
          path = "/var/lib/samba/sysvol/${siteConfig.adDomain}/scripts";
          "read only" = "No";
      };
    };
  };    
 
  # Setup timezone and chrony for NTP synchronization.
  time.timeZone = "America/Vancouver";

  services.chrony = {
    enable = true;
    extraConfig = ''
      allow all
      ntpsigndsocket /var/lib/samba/ntp_signd
    '';
    extraFlags = [ "-x" ];
    servers = [ "${siteConfig.hostServerIp}" ];
  };

  systemd.services.chronyd = {
    unitConfig.ConditionCapability = lib.mkForce "";
  };

  systemd.tmpfiles.rules = [
    "z /var/lib/samba/ntp_signd 750 root chrony"
  ];
 
  i18n.defaultLocale = "en_CA.UTF-8";
 
  networking = {
  # nftables and networking section are to provide access to the school web server.
    nftables = {
      enable = true;
      ruleset = ''
        table ip nat {
          chain PREROUTING {
            type nat hook prerouting priority dstnat; policy accept;
            iifname "eth0" tcp dport 80 dnat to ${siteConfig.webServerIp}:80
            iifname "eth0" tcp dport 443 dnat to ${siteConfig.webServerIp}:443
          }
        }
      '';
      };
    nat = {
      enable = true;
      internalInterfaces = [ "eth0" ];
      externalInterface = "eth0";
      forwardPorts = [
        {
          sourcePort = 80;
          proto = "tcp";
          destination = "${siteConfig.webServerIp}:80";
        }
        {
          sourcePort = 443;
          proto = "tcp";
          destination = "${siteConfig.webServerIp}:443";
        }
      ];
    };
    hostName = "${siteConfig.adNetbiosName}";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "${siteConfig.AdContainerIp}";
        prefixLength = 16;
      }];
    defaultGateway = {
      address = "${siteConfig.hostServerIp}";
      interface = "eth0";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 53 88 135 389 464 636 3268 3269 ];
      allowedTCPPortRanges = [ {from = 49152; to = 65535;} ];
      allowedUDPPorts = [ 53 88 123 137 138 389 464];
      allowPing = true;
    }; 
  };
 
  services.openssh.enable = true;
 
  environment.systemPackages = with pkgs; [
    vim
    git
    git-crypt
  ];

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
