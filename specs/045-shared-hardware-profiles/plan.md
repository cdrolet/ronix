# Implementation Plan: Shared Hardware Profiles

**Branch**: `045-shared-hardware-profiles` | **Date**: 2026-02-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/045-shared-hardware-profiles/spec.md`

## Summary

Introduce a `system/shared/hardware/` directory for reusable hardware configuration modules organized by category subdirectories. Hosts reference profiles via a new `hardware` field in the host schema. The platform library resolves and loads these profiles before the host's local `hardware.nix`, which retains override priority.

## Technical Context

**Language/Version**: Nix (flakes, NixOS modules)\
**Primary Dependencies**: NixOS module system, home-manager (standalone), host-schema.nix\
**Storage**: Filesystem (`.nix` expression files)\
**Testing**: `nix flake check`\
**Target Platform**: NixOS (system-level modules only)\
**Project Type**: Declarative configuration repository\
**Performance Goals**: N/A (build-time only)\
**Constraints**: Module files \<200 lines, `lib.mkDefault` for overridability\
**Scale/Scope**: ~5-10 initial profiles, expandable

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | PASS | Hardware profiles are pure Nix expressions |
| II. Modularity and Reusability | PASS | Core purpose of this feature - reusable modules |
| III. Documentation-Driven Development | PASS | Header comments required on all profiles |
| IV. Purity and Reproducibility | PASS | No network access, declarative only |
| V. Testing and Validation | PASS | `nix flake check` validates, missing profiles error |
| VI. Cross-Platform Compatibility | PASS | NixOS-only by design (hardware modules), doesn't affect Darwin |
| App-Centric Organization | PASS | One concern per profile file |
| \<200 lines per module | PASS | Profiles are small, focused modules |
| No Backward Compatibility needed | PASS | Existing hosts with no `hardware` field default to `[]` |
| Context Validation | N/A | System-level modules only (no home-manager options) |

No violations. All gates pass.

## Project Structure

### Documentation (this feature)

```text
specs/045-shared-hardware-profiles/
  plan.md              # This file
  spec.md              # Feature specification
  research.md          # Phase 0: Research findings
  data-model.md        # Phase 1: Data model
  quickstart.md        # Phase 1: Quick start guide
  contracts/           # Phase 1: Schema contracts
  checklists/          # Quality checklists
    requirements.md    # Spec quality checklist
```

### Source Code (repository root)

```text
system/shared/hardware/          # NEW: Shared hardware profiles
  vm/                            # Virtual machine profiles
    qemu-guest.nix               # QEMU guest agent, boot loader, serial console
    spice.nix                    # SPICE VD agent, clipboard, display
    apple-virtualization.nix     # Rosetta, virtiofs, Apple VZ specifics
  graphics/
    virtio-gpu.nix               # Virtio GPU drivers for VMs
  storage/
    standard-partitions.nix      # Common partition layout (root, boot, swap)

system/shared/lib/host-schema.nix   # MODIFY: Add `hardware` field
system/nixos/lib/nixos.nix          # MODIFY: Resolve and load hardware profiles
system/nixos/host/*/default.nix     # MODIFY: Add `hardware` field to VM hosts
system/nixos/host/*/hardware.nix    # MODIFY: Remove duplicated content now in shared profiles
```
