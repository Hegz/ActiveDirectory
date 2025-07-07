# Flake configuration

{
  description = "Systems configuration flake";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");

  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Available through 'nixos-rebuild --flake .#hostname'
    nixosConfigurations = {
      AD = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit secrets inputs outputs;};
        modules = [
          # > Our main nixos configuration file <
          ./AD.nix
        ];
      };
    };
  };
}
