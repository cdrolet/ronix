# Configuration Contract: flake.nix Schema

**Purpose**: Define the structure and requirements for the root flake.nix configuration file

______________________________________________________________________

## Flake Structure

```nix
{
  description = "Charles' Nix Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, nixpkgs, nix-darwin, home-manager, sops-nix, ...}@inputs: 
    let
      system = "x86_64-darwin";  # or "aarch64-darwin", "x86_64-linux"
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # macOS configurations
      darwinConfigurations = {
        macbook-pro = nix-darwin.lib.darwinSystem {
          inherit system;
          modules = [
            ./hosts/macbook-pro
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.charles = import ./common/users/charles;
            }
          ];
          specialArgs = {inherit inputs;};
        };
      };

      # NixOS configurations
      nixosConfigurations = {
        nixos-desktop = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/nixos-desktop
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.charles = import ./common/users/charles;
            }
          ];
          specialArgs = {inherit inputs;};
        };
      };

      # Formatter
      formatter.${system} = pkgs.alejandra;
    };
}
```

## Required Fields

- `description` (string): Human-readable description
- `inputs` (attrset): All external dependencies
- `outputs` (function): System configurations and packages

## Input Requirements

All inputs MUST:

- Use `follows` for nixpkgs to ensure consistency
- Be pinned in flake.lock via `nix flake lock`
- Use stable URLs (github:, git+https://, etc.)

## Output Requirements

MUST include at least ONE of:

- `darwinConfigurations.<hostname>` for macOS
- `nixosConfigurations.<hostname>` for NixOS

MAY include:

- `homeConfigurations.<username>` for standalone Home Manager
- `formatter.<system>` for nix fmt command
- `packages.<system>.<name>` for custom packages

## Validation

```bash
nix flake check  # Validates flake structure
nix flake show   # Shows outputs
```
