{
  description = "NixOS + Home Manager configuration for pn";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    superfile = {
      url = "github:yorukot/superfile";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, superfile, ... }:
    let
      system = "x86_64-linux";
      username = "pn";
      # NixOS machine (the heavy box). Change to taste; build with:
      #   sudo nixos-rebuild switch --flake ~/dotfiles/home-manager#<hostname>
      hostname = "tower";
    in {
      # Standalone home-manager for non-NixOS machines (Fedora laptop, etc.)
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit superfile;
          isNixOS = false;
        };
        modules = [
          ./home.nix
          ./shell.nix
        ];
      };

      # NixOS machine with home-manager wired in as a module.
      # Reuses the same home.nix/shell.nix, with isNixOS = true.
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit superfile; };
        modules = [
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit superfile;
                isNixOS = true;
              };
              users.${username} = {
                imports = [
                  ./home.nix
                  ./shell.nix
                ];
              };
            };
          }
        ];
      };
    };
}
