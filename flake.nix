{
  description = "Nix Configuration - Multi-platform";

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

    # nix-on-droid = {
    #   url = "github:nix-community/nix-on-droid/release-23.11";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.home-manager.follows = "home-manager";
    # };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS kernel (BORE scheduler, LTO, PGO, AMD-optimised)
    # NOTE: intentionally no nixpkgs.follows — version pinning required for binary cache
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # Private user/host config repo (Feature 047)
    # Default: empty stub (framework repo used as-is)
    # Override: --override-input user-host-config path:~/.config/nix-private
    user-host-config = {
      url = "path:config";
      flake = false;
    };

  };

  outputs = {
    self,
    nixpkgs,
    nix-darwin,
    home-manager,
    # nix-on-droid,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;

    # ============================================================================
    # SHARED DISCOVERY FUNCTIONS
    # Platform-agnostic utilities imported from shared library
    # ============================================================================

    # Import discovery functions from shared library
    discovery = import ./system/shared/lib/discovery.nix {inherit lib;};

    # Private user/host config repo (Feature 047 — mandatory)
    # Override at build time: --override-input user-host-config path:~/.config/nix-private
    # Without override, the stub (config/) is used → zero users/hosts (framework-only mode)
    privateConfigRoot = inputs.user-host-config;

    # User/host discovery always from private repo layout (users/, hosts/<system>/)
    validUsers = discovery.discoverDirectoriesWithDefault (privateConfigRoot + "/users");
    discoverHosts = system: discovery.discoverDirectoriesWithDefault (privateConfigRoot + "/hosts/${system}");

    # ============================================================================
    # TREEFMT CONFIGURATION
    # Multi-language formatter using treefmt-nix
    # ============================================================================

    # Systems to generate formatters for
    supportedSystems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];

    # Generate treefmt wrapper for each system
    treefmtEval = system:
      inputs.treefmt-nix.lib.evalModule
      nixpkgs.legacyPackages.${system}
      ./treefmt.nix;

    # ============================================================================
    # PLATFORM-SPECIFIC OUTPUTS
    # Each platform lib exports complete outputs for that platform
    # Only loaded if the platform directory exists
    # ============================================================================

    # Darwin outputs (macOS via nix-darwin)
    darwinOutputs =
      if builtins.pathExists ./system/darwin/lib/darwin.nix
      then
        (import ./system/darwin/lib/darwin.nix {
          inherit inputs lib nixpkgs validUsers discoverHosts privateConfigRoot;
        })
        .outputs
      else {};

    # NixOS outputs (Linux via nixpkgs)
    nixosOutputs =
      if builtins.pathExists ./system/nixos/lib/nixos.nix
      then
        (import ./system/nixos/lib/nixos.nix {
          inherit inputs lib nixpkgs validUsers discoverHosts privateConfigRoot;
        })
        .outputs
      else {};

    # Home Manager standalone outputs (Feature 036)
    # Provides lib.hm utilities by using standalone mode instead of module integration
    homeManagerOutputs =
      if builtins.pathExists ./user/lib/home-manager.nix
      then
        (import ./user/lib/home-manager.nix {
          inherit inputs lib nixpkgs validUsers discoverHosts privateConfigRoot;
        })
        .outputs
      else {};

    # # Nix-on-Droid outputs (Android)
    # # TODO: Create system/nix-on-droid/lib/nix-on-droid.nix when needed
    # nixOnDroidOutputs = {};

    # ============================================================================
    # MERGE ALL PLATFORM OUTPUTS
    # Combine platform-specific outputs with shared outputs
    # ============================================================================

    # Merge all validHosts from platforms (organized by platform)
    validHosts =
      (darwinOutputs.validHosts or {})
      // (nixosOutputs.validHosts or {});

    # Generate formatters for all supported systems using treefmt
    formatter = lib.genAttrs supportedSystems (
      system:
        (treefmtEval system).config.build.wrapper
    );
  in
    # Final flake outputs - platform-agnostic orchestration
    {
      # Platform-specific configurations
      darwinConfigurations = darwinOutputs.darwinConfigurations or {};
      nixosConfigurations = nixosOutputs.nixosConfigurations or {};
      homeConfigurations = homeManagerOutputs.homeConfigurations or {};

      # Only export nixOnDroidConfigurations if they exist
      # nixOnDroidConfigurations = nixOnDroidOutputs.nixOnDroidConfigurations or {};

      # Formatters from all platforms
      inherit formatter;

      # Development shells and packages for all supported systems
      devShells = lib.genAttrs supportedSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          buildInputs = with nixpkgs.legacyPackages.${system}; [
            just # Command runner (justfile)
            nixpkgs-fmt # Nix formatter
            cachix # Binary cache management
            age # Secret encryption/decryption
            jq # JSON processor (used in scripts)
            git # Version control
            openssl # Provides passwd -6 (used by set-password)
          ];

          shellHook = ''
            echo "🚀 nix-config development environment"
            echo ""
            echo "Available commands:"
            echo "  just --list          # Show all available commands"
            echo "  just build <u> <h>   # Build configuration"
            echo "  just install <u> <h> # Install configuration"
            echo "  cachix --help        # Binary cache management"
            echo "  age --help           # Secret management"
            echo ""
          '';
        };
      });

      # Packages output (empty but satisfies flake schema)
      packages = lib.genAttrs supportedSystems (system: {});

      # Apps output (empty but satisfies flake schema)
      apps = lib.genAttrs supportedSystems (system: {});
    };
}
