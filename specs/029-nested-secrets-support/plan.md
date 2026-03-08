# Implementation Plan: Nested Secrets Support

**Branch**: `029-nested-secrets-support` | **Date**: 2025-12-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/029-nested-secrets-support/spec.md`

## Summary

Extend the secrets system (Feature 027) to support nested JSON paths, enabling organized storage of multiple SSH keys, API tokens, and credentials. Users can define hierarchical secrets like `config.user.sshKeys.personal = "<secret>"` and have them resolved from nested JSON structures at activation time.

## Technical Context

**Language/Version**: Nix (flakes), Bash (justfile recipes)
**Primary Dependencies**: agenix, jq, Home Manager
**Storage**: Age-encrypted JSON files (`user/{name}/secrets.age`)
**Testing**: `nix flake check`, manual activation testing
**Target Platform**: Cross-platform (darwin, nixos)
**Project Type**: Nix configuration repository
**Performance Goals**: \<100ms activation overhead for nested secret resolution
**Constraints**: Backward compatible with flat secrets (Feature 027)
**Scale/Scope**: 3 users, unlimited nested depth (recommended max 4 levels)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Declarative Configuration First | ✅ PASS | Secrets defined declaratively in user configs |
| Modularity and Reusability | ✅ PASS | Extends existing secrets.nix helper library |
| Documentation-Driven Development | ✅ PASS | Research, data model, quickstart created |
| App-Centric Organization | ✅ PASS | Changes confined to secrets helper and justfile |
| Module Size (\<200 lines) | ✅ PASS | secrets.nix stays under 200 lines |
| No Backward Compatibility Code | ✅ PASS | New functionality, not compatibility shims |
| Cross-Platform Compatibility | ✅ PASS | Works on darwin and nixos |

**Gate Result**: ✅ PASSED - No violations

## Project Structure

### Documentation (this feature)

```text
specs/029-nested-secrets-support/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 research findings
├── data-model.md        # Entity definitions and relationships
├── quickstart.md        # Usage examples
└── checklists/
    └── requirements.md  # Specification validation
```

### Source Code Changes

```text
user/shared/lib/
└── secrets.nix          # MODIFY: Add nested path support

justfile                 # MODIFY: Update secrets-set for nested paths

system/shared/app/dev/
└── ssh.nix              # CREATE: SSH key deployment module (example)
```

## Implementation Phases

### Phase 1: Core Nested Path Support (secrets.nix)

**Goal**: Enable detection and resolution of nested secrets in the helper library.

**Changes to `user/shared/lib/secrets.nix`**:

1. **Add `pathToAttrList`** - Convert dotted path to Nix attribute list

   ```nix
   pathToAttrList = path: lib.splitString "." path;
   ```

1. **Add `fieldToVarName`** - Convert dotted path to shell variable

   ```nix
   fieldToVarName = fieldPath:
     lib.toUpper (builtins.replaceStrings ["."] ["_"] fieldPath);
   ```

1. **Update `mkJqExtract`** - Use getpath() for nested extraction

   ```nix
   mkJqExtract = pkgs: jsonPath:
     "${pkgs.jq}/bin/jq -r 'getpath(\"${jsonPath}\" | split(\".\")) // empty'";
   ```

1. **Update `mkActivationScript`** - Handle nested field paths

   - Use `lib.attrByPath` to access nested config values
   - Generate correct variable names for nested paths
   - Maintain backward compatibility with flat paths

**Validation**:

- Existing git.nix activation continues working (flat paths)
- New nested paths resolve correctly

### Phase 2: CLI Support (justfile)

**Goal**: Enable `just secrets-set user path.to.secret "value"` with nested JSON creation.

**Changes to `justfile`**:

1. **Update `secrets-set` recipe**:

   - Parse dotted path syntax
   - Create nested JSON structure using jq
   - Merge with existing secrets (preserve other fields)

   ```bash
   # Example: just secrets-set cdrokar sshKeys.personal "key"
   # Creates: {"sshKeys": {"personal": "key"}}
   # Merges with existing secrets
   ```

1. **Update `secrets-list` recipe** (optional enhancement):

   - Display nested paths in readable format
   - Show hierarchy with indentation

**Validation**:

- `just secrets-set cdrokar sshKeys.personal "test"` creates nested JSON
- Existing flat secrets continue working

### Phase 3: Example SSH Module

**Goal**: Demonstrate nested secrets usage with real-world SSH key management.

**Create `system/shared/app/dev/ssh.nix`**:

```nix
{ config, pkgs, lib, ... }:
let
  secrets = import ../../../../user/shared/lib/secrets.nix { inherit lib pkgs; };
in {
  programs.ssh.enable = true;

  home.activation.applySSHSecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "ssh";
    fields = {
      "sshKeys.personal" = ''
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        echo "$SSHKEYS_PERSONAL" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ${pkgs.openssh}/bin/ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
      '';
    };
  };
}
```

**Validation**:

- SSH key deployed to correct location
- Correct permissions set

### Phase 4: Documentation

**Goal**: Update all relevant documentation.

1. **Update CLAUDE.md**:

   - Add nested secrets examples in Secrets Management section
   - Document shell variable naming convention
   - Add SSH key management example

1. **Create feature documentation**:

   - `docs/features/029-nested-secrets-support.md`

## File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `user/shared/lib/secrets.nix` | MODIFY | Add nested path support functions |
| `justfile` | MODIFY | Update secrets-set for nested paths |
| `system/shared/app/dev/ssh.nix` | CREATE | SSH key deployment example |
| `CLAUDE.md` | MODIFY | Add nested secrets documentation |
| `docs/features/029-nested-secrets-support.md` | CREATE | Feature documentation |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing secrets | Low | High | Flat paths are subset of nested |
| jq getpath() unavailable | Very Low | High | jq 1.5+ has getpath, nixpkgs has 1.7 |
| Shell variable name conflicts | Low | Medium | Uppercase + underscores is conventional |
| Performance degradation | Low | Low | jq extraction is ~3ms per field |

## Success Criteria Mapping

| Criterion | Implementation | Verification |
|-----------|----------------|--------------|
| SC-001: 4 levels deep | `lib.attrByPath` + jq `getpath()` | Test with `a.b.c.d` path |
| SC-002: No activation pattern changes | Same `mkActivationScript` API | Existing apps unchanged |
| SC-003: \<10s CLI operation | jq merge is fast | Time `secrets-set` command |
| SC-004: Actionable errors | Add path in error messages | Test with missing path |
| SC-005: Backward compatible | Flat = nested with depth 1 | Test existing git.nix |
| SC-006: \<100ms overhead | Single jq call per secret | Profile activation |

## Dependencies

- Feature 027 (User Colocated Secrets) - base infrastructure
- jq 1.5+ (for `getpath()` function) - available in nixpkgs
- agenix - secret decryption

## Complexity Tracking

No constitution violations to justify. Implementation is straightforward extension of existing patterns.
