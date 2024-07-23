# Configuration Step one.
# Set hostname and enable flakes

{ config, pkgs, lib, modulesPath, ... }:

{
  imports =
    [
      # Include the default lxd configuration.
      "${modulesPath}/virtualisation/lxc-container.nix"
    ];

  networking = {
    hostname = "AD";
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
  };

  systemd.network = {
    enable = true;
    networks."50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  #Enable Flakes
  nix.settings.experimental-features = [ "nix-command flakes" ];

  system.stateVersion = "24.05"; # Did you read the comment?
}
