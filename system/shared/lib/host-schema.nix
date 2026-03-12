# Host Configuration Schema
#
# Purpose: Provide standardized host configuration schema for system modules
# Usage: Automatically imported by platform libs (darwin.nix, nixos.nix, home-manager.nix)
# Platform: Cross-platform (darwin, nixos, home-manager)
#
# This module provides options for host configuration that are available
# to all system modules via config.host. It is automatically included
# by the platform libraries.
#
# Feature 021: Host/family architecture with pure data hosts
# Hosts are pure data configurations that define machine-specific settings.
#
# Example host config (pure data):
#   { ... }:
#   {
#     name = "home-macmini-m4";
#     family = [];
#   }
{
  config,
  lib,
  ...
}: {
  options.host = lib.mkOption {
    type = lib.types.submodule {
      # No freeform type for hosts - structure is fixed

      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = ''
            Host identifier (machine name).

            Used for:
            - Identifying the host configuration directory
            - Network hostname (on NixOS)
            - System identification

            Examples: "home-macmini-m4", "work-laptop", "nixos-workstation"
          '';
          example = "home-macmini-m4";
        };

        architecture = lib.mkOption {
          type = lib.types.enum ["aarch64" "x86_64"];
          description = ''
            CPU architecture of the host machine.

            Platform-agnostic architecture specification.
            The platform library automatically appends the platform suffix:
            - Darwin: "aarch64" → "aarch64-darwin"
            - NixOS: "x86_64" → "x86_64-linux"

            Available architectures:
            - "aarch64": ARM 64-bit (Apple Silicon, modern ARM servers)
            - "x86_64": Intel/AMD 64-bit (most desktops, laptops, servers)
          '';
          example = "aarch64";
        };

        family = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = ''
            List of cross-platform families this host belongs to.

            Families provide shared configurations across platforms.
            Examples: ["linux", "gnome"], ["server"], []

            Available families are discovered from system/shared/family/

            Note: Darwin hosts typically use family = [] (no cross-platform sharing)
            Note: Families are for cross-platform sharing, NOT deployment contexts
          '';
          example = ["linux" "gnome"];
        };

        hardware = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = ''
            List of shared hardware profiles to load.

            Profiles are reusable hardware configuration modules located under
            system/shared/hardware/{category}/{name}.nix.

            Bare names are resolved by searching all subdirectories:
              "qemu-guest" -> finds system/shared/hardware/vm/qemu-guest.nix

            Full paths resolve directly:
              "vm/qemu-guest" -> system/shared/hardware/vm/qemu-guest.nix

            Ambiguous bare names (matching multiple categories) cause a build error.
            Profiles are loaded before the host's local hardware.nix.
          '';
          example = ["qemu-guest" "spice" "standard-partitions"];
        };

        schedule = lib.mkOption {
          default = {};
          description = "Scheduled automation settings for this host.";
          type = lib.types.submodule {
            options = {
              updateSystem = lib.mkOption {
                default = {};
                description = "Automatic system update schedule.";
                type = lib.types.submodule {
                  options.frequency = lib.mkOption {
                    type = lib.types.nullOr (lib.types.enum ["on-boot" "daily" "weekly"]);
                    default = null;
                    description = ''
                      How often to automatically pull and apply the latest nix-config.

                      Runs `just fresh-install` (git pull + rebuild + activate) in the
                      repository at $HOME/.config/nix-config.

                      - null:       no automatic updates (default)
                      - "on-boot":  update once each time the user logs in
                      - "daily":    update once per day (at 3:00 AM)
                      - "weekly":   update once per week (Sunday at 3:00 AM)

                      Log output: ~/.local/share/nix-config/auto-update.log

                      Note: System-level activation (nixos-rebuild / darwin-rebuild)
                      requires passwordless sudo. Add to /etc/sudoers:
                        %wheel ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
                    '';
                    example = "daily";
                  };
                };
              };

              garbageCollection = lib.mkOption {
                default = {};
                description = "Nix store garbage collection schedule.";
                type = lib.types.submodule {
                  options = {
                    frequency = lib.mkOption {
                      type = lib.types.nullOr (lib.types.enum ["daily" "weekly" "monthly"]);
                      default = "weekly";
                      description = ''
                        How often to run Nix garbage collection.

                        - null:      disable automatic garbage collection
                        - "daily":   collect daily
                        - "weekly":  collect weekly (default)
                        - "monthly": collect monthly
                      '';
                      example = "weekly";
                    };
                    olderThan = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = "30d";
                      description = ''
                        Delete store paths not referenced by any generation newer than this age.
                        Format: Nix duration string (e.g. "7d", "30d", "3m").
                        null disables the age filter (deletes all unreferenced paths).
                      '';
                      example = "30d";
                    };
                  };
                };
              };
            };
          };
        };

        display = lib.mkOption {
          type = lib.types.submodule {
            options.scale = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = ''
                Integer display scale factor (1 = 100%, 2 = 200%).
                Applied via GNOME dconf scaling-factor when using the gnome family.
                Use 2 for HiDPI monitors or high-resolution VM displays.
              '';
              example = 2;
            };
          };
          default = {};
          description = "Display configuration for this host.";
        };

        virtualMachine = lib.mkOption {
          type = lib.types.bool;
          default = let
            hw = config.host.hardware;
            vmProfiles = ["qemu-guest" "apple-virtualization" "spice"];
            hasVmHardware =
              lib.any (
                h:
                  lib.any (vm: h == vm || lib.hasPrefix "vm/" h) vmProfiles
              )
              hw;
          in
            hasVmHardware;
          description = ''
            Whether this host is a virtual machine.

            Automatically derived from hardware profiles: true when any
            VM hardware profile (qemu-guest, apple-virtualization, spice)
            is present in the hardware list. Can be overridden manually.

            When true, modules can adjust behavior for VM environments:
            - Disable suspend/sleep (pointless in VMs)
            - Skip battery-related settings
            - Enable VM-specific optimizations
          '';
          example = true;
        };
      };
    };
    description = "Host configuration data (pure data from host directory)";
  };
}
