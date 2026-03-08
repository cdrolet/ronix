# Implementation Plan: Disko Declarative Disk Management

**Branch**: `046-disko-disk-management` | **Date**: 2026-02-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/046-disko-disk-management/spec.md`

## Summary

Migrate from manual partition shell scripts (`init-disk.sh`) and separate Nix `fileSystems` declarations to disko — a declarative disk management tool that serves as single source of truth for both install-time partitioning and runtime NixOS filesystem configuration. Storage hardware profiles are rewritten to disko format, `install-remote.sh` calls disko instead of shell scripts, and legacy partitioning code is removed.

## Technical Context

**Language/Version**: Nix (flakes, 2.19+)
**Primary Dependencies**: disko (nix-community/disko), nixpkgs, NixOS modules
**Storage**: Declarative disk configuration (disko.devices)
**Testing**: `nix flake check`, VM installation tests
**Target Platform**: NixOS (aarch64-linux, x86_64-linux)
**Project Type**: Nix configuration repository
**Constraints**: Module files \<200 lines, lib.mkDefault for overridability

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Module size \<200 lines | PASS | Storage profiles are small (~40-60 lines each) |
| App-centric organization | PASS | Storage profiles are self-contained per layout type |
| Hierarchical config | PASS | Shared profiles → host override via `_module.args.disks` |
| Documentation-driven | PASS | Spec, research, plan, quickstart all created |
| Pure/reproducible | PASS | Disko configs are pure Nix expressions |
| No backward compat hacks | PASS | Old `init-disk.sh` deleted, not deprecated |
| Context validation | N/A | Storage profiles are system-level only (no home-manager) |

## Project Structure

### Documentation (this feature)

```text
specs/046-disko-disk-management/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── disko-config.nix
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (files to modify/create)

```text
flake.nix                                          # Add disko input
system/nixos/lib/nixos.nix                         # Import disko module
system/shared/hardware/storage/
├── standard-partitions.nix                        # Rewrite to disko format
└── luks-encrypted.nix                             # Rewrite to disko format
system/shared/lib/discovery.nix                    # Add storage conflict detection
install-remote.sh                                  # Replace init-disk with disko
system/nixos/lib/init-disk.sh                      # DELETE
```
