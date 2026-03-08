# Implementation Tasks: User Git Repository Configuration

**Feature**: 032-user-git-repos\
**Branch**: `032-user-git-repos`\
**Created**: 2025-12-30

## Overview

This document provides the implementation task breakdown for user-configurable git repository cloning during Home Manager activation. Tasks are organized by user story to enable independent implementation and testing.

## Task Summary

- **Total Tasks**: 17
- **P1 Tasks (MVP)**: 11 (User Stories 1 + 5)
- **P2 Tasks**: 4 (User Stories 2 + 3)
- **P3 Tasks**: 1 (User Story 4)
- **Polish Tasks**: 1

**Parallel Opportunities**: 5 tasks marked with [P] can run in parallel

## Implementation Strategy

**MVP Scope** (User Stories 1 + 5):

- Basic repository cloning with default paths
- Activation ordering and credential dependency
- SSH authentication support
- Graceful degradation when git not installed

**Incremental Delivery**:

1. Phase 3: US1 + US5 (P1) → MVP - Basic cloning works
1. Phase 4: US2 (P2) → Section root path support
1. Phase 5: US3 (P2) → Individual custom paths
1. Phase 6: US4 (P3) → Repository updates
1. Phase 7: Polish → Documentation and validation

______________________________________________________________________

## Phase 1: Setup

Foundation tasks required before any user story implementation.

- [x] T001 Verify existing git library functions in system/shared/lib/git.nix
- [x] T002 [P] Review Feature 030 (fonts) activation pattern in system/darwin/settings/fonts.nix for reference

______________________________________________________________________

## Phase 2: Foundational (Required for All Stories)

Core library functions that all user stories depend on.

- [x] T003 Implement normalizeRepo function in system/shared/lib/git.nix
- [x] T004 Implement resolveRepoPath function in system/shared/lib/git.nix
- [x] T005 Implement mkRepoCloneScriptWithPaths function in system/shared/lib/git.nix
- [x] T006 Add Home Manager option schema for user.repositories in system/shared/settings/git-repos.nix

______________________________________________________________________

## Phase 3: User Story 1 (P1) - Clone Single Repository with Default Location

**Goal**: Users can clone one repository to home folder without path configuration.

**Independent Test**: Configure single HTTPS repo URL, activate, verify repo exists in ~/{repoName}

**Story Tasks**:

- [x] T007 [US1] Create git-repos.nix settings module in system/shared/settings/git-repos.nix with activation entry
- [x] T008 [US1] Implement conditional activation guard (hasGit && hasRepos) in git-repos.nix
- [x] T009 [US1] Implement default path resolution (home folder) in activation script
- [ ] T010 [US1] Test: Configure HTTPS repo, activate, verify clone to ~/repo-name

______________________________________________________________________

## Phase 4: User Story 5 (P1) - Activation Ordering and Credential Dependency

**Goal**: Repository cloning happens after git installation and SSH key deployment.

**Independent Test**: Configure private SSH repo with secrets, activate, verify cloning after credentials deployed.

**Story Tasks**:

- [x] T011 [US5] Implement DAG ordering entryAfter ["writeBoundary" "agenixInstall"] in git-repos.nix
- [x] T012 [US5] Implement SSH authentication setup (GIT_SSH_COMMAND) in activation script
- [x] T013 [US5] Implement graceful skip when git not in applications list
- [ ] T014 [US5] Test: Configure private SSH repo, activate, verify successful clone with authentication

______________________________________________________________________

## Phase 5: User Story 2 (P2) - Clone Multiple Repositories with Section Root Path

**Goal**: Users can organize multiple repositories under a common parent directory.

**Independent Test**: Configure rootPath="~/projects" with 3 repos, activate, verify all in ~/projects/

**Story Tasks**:

- [x] T015 [US2] Implement rootPath-based resolution in path resolution logic
- [x] T016 [US2] Implement parent directory creation (mkdir -p) in activation script
- [ ] T017 [US2] Test: Configure rootPath with 3 repos, activate, verify all cloned correctly

______________________________________________________________________

## Phase 6: User Story 3 (P2) - Clone Repositories with Individual Custom Paths

**Goal**: Users can specify custom clone paths per repository, overriding defaults.

**Independent Test**: Configure repos with mix of custom paths, activate, verify each at correct location.

**Story Tasks**:

- [x] T018 [P] [US3] Implement individual path override logic in resolveRepoPath function
- [ ] T019 [US3] Test: Configure repos with absolute, relative, and default paths, verify all clone correctly

______________________________________________________________________

## Phase 7: User Story 4 (P3) - Update and Sync Existing Repositories

**Goal**: Existing repositories are automatically updated during activation without losing local changes.

**Independent Test**: Clone repos, make remote changes, activate again, verify updates pulled (clean repos only).

**Story Tasks**:

- [x] T020 [US4] Implement local change detection (git status --porcelain) in clone script
- [x] T021 [US4] Implement conditional git pull (only if clean working directory)
- [x] T022 [US4] Implement re-clone logic for deleted repositories
- [ ] T023 [US4] Test: Clone repo, make remote changes, activate, verify update; test with local changes, verify skip

______________________________________________________________________

## Phase 8: Polish & Cross-Cutting Concerns

Final tasks that span multiple stories or improve overall quality.

- [x] T024 [P] Create user documentation in docs/features/032-user-git-repos.md
- [x] T025 Run nix flake check to validate syntax
- [ ] T026 Test on darwin platform with real user configuration
- [ ] T027 [P] Test on nixos platform (if available)

______________________________________________________________________

## Dependencies

### User Story Completion Order

```
Phase 1 (Setup) → Phase 2 (Foundational)
                      ↓
        ┌─────────────┴─────────────┐
        ↓                           ↓
    Phase 3 (US1)              Phase 4 (US5)
        ↓                           ↓
        └─────────────┬─────────────┘
                      ↓
                 Phase 5 (US2)
                      ↓
                 Phase 6 (US3)
                      ↓
                 Phase 7 (US4)
                      ↓
                 Phase 8 (Polish)
```

**Critical Path**: Setup → Foundational → US1 → US5 → MVP Complete

**Optional Enhancements**: US2 (P2), US3 (P2), US4 (P3)

### Task Dependencies (Detailed)

**Foundational Tasks** (T003-T006):

- **BLOCKS**: All user story tasks (T007-T023)
- **REASON**: Core library functions must exist before activation module can use them

**US1 Tasks** (T007-T010):

- **DEPENDS ON**: Foundational (T003-T006)
- **BLOCKS**: US2, US3, US4 (builds on basic cloning)

**US5 Tasks** (T011-T014):

- **DEPENDS ON**: US1 (T007-T010)
- **BLOCKS**: None (orthogonal concern - activation ordering)

**US2 Tasks** (T015-T017):

- **DEPENDS ON**: US1 (T007-T010)
- **BLOCKS**: None (extends path resolution)

**US3 Tasks** (T018-T019):

- **DEPENDS ON**: US1 (T007-T010), US2 (T015-T017)
- **BLOCKS**: None (final path resolution tier)

**US4 Tasks** (T020-T023):

- **DEPENDS ON**: US1 (T007-T010)
- **BLOCKS**: None (extends clone behavior for existing repos)

______________________________________________________________________

## Parallel Execution Opportunities

Tasks marked [P] can run in parallel with other tasks in the same phase (different files, no dependencies):

### Setup Phase

- T002 [P] can run while T001 executes (different files: fonts.nix vs git.nix)

### User Story 3

- T018 [P] can run independently (pure function modification)

### Polish Phase

- T024 [P] can run while T025-T026 execute (documentation vs testing)
- T027 [P] can run in parallel with T026 (different platforms)

**Example Parallel Execution**:

```bash
# Phase 1: Review reference code while verifying library
Task T001 & Task T002 (parallel)

# Phase 6: US3 can modify pure function independently
Task T018 (no blocking dependencies within phase)

# Phase 8: Documentation and testing in parallel
Task T024 & Task T025-T026 (parallel)
Task T027 (separate platform, parallel if available)
```

______________________________________________________________________

## Testing Strategy

### Per User Story Testing

**US1 Test Scenario** (T010):

```nix
# Configure in user/{username}/default.nix
user = {
  applications = ["git"];
  repositories.repos = [
    "https://github.com/nixos/nixpkgs.git"  # Public HTTPS repo
  ];
};

# Expected: Repository cloned to ~/nixpkgs
```

**US5 Test Scenario** (T014):

```nix
user = {
  applications = ["git"];
  sshKeys.git = "<secret>";
  repositories.repos = [
    "git@github.com:yourorg/private.git"  # Private SSH repo
  ];
};

# Expected: Repository cloned after SSH key deployed to ~/.ssh/id_git
```

**US2 Test Scenario** (T017):

```nix
user.repositories = {
  rootPath = "~/code";
  repos = [
    "https://github.com/neovim/neovim.git"
    "https://github.com/rust-lang/rust.git"
    "https://github.com/golang/go.git"
  ];
};

# Expected: All repos in ~/code/{neovim,rust,go}
```

**US3 Test Scenario** (T019):

```nix
user.repositories = {
  rootPath = "~/projects";  # Default for most
  repos = [
    "https://github.com/user/default.git"  # → ~/projects/default
    {
      url = "https://github.com/user/work.git";
      path = "~/work/project";  # → ~/work/project (overrides rootPath)
    }
    {
      url = "https://github.com/user/system.git";
      path = "/opt/configs/system";  # → /opt/configs/system (absolute)
    }
  ];
};

# Expected: Repos at ~/projects/default, ~/work/project, /opt/configs/system
```

**US4 Test Scenario** (T023):

```bash
# Initial activation: Clone repo
just install username hostname

# Make remote changes
cd remote-repo && git commit --allow-empty -m "test" && git push

# Second activation: Update repo
just install username hostname

# Expected: Local repo updated with new commit

# Test with local changes
cd ~/repo && echo "test" >> README.md

# Third activation
just install username hostname

# Expected: "Skipping update for repo: local changes detected"
```

### Integration Testing

**End-to-End Test** (combines multiple stories):

```nix
user = {
  applications = ["git"];
  sshKeys.git = "<secret>";
  
  repositories = {
    rootPath = "~/code";
    repos = [
      # US1: Simple URL
      "https://github.com/public/tool.git"
      
      # US2: Uses rootPath
      "https://github.com/other/lib.git"
      
      # US3: Custom path
      {
        url = "git@github.com:private/work.git";
        path = "~/work";
      }
    ];
  };
};

# Activate
just install username hostname

# Expected:
# - ~/code/tool (US1 + US2)
# - ~/code/lib (US2)
# - ~/work (US3 + US5 SSH auth)

# Update test (US4)
# Make remote changes, activate again
# Expected: Clean repos updated, repos with local changes skipped
```

______________________________________________________________________

## Validation Checklist

After completing all tasks, verify:

- [ ] `nix flake check` passes (no syntax errors)
- [ ] `just build <user> <host>` succeeds
- [ ] Single repository clones to home folder (US1)
- [ ] Private SSH repositories clone with authentication (US5)
- [ ] Multiple repositories clone under rootPath (US2)
- [ ] Individual custom paths work (US3)
- [ ] Existing repositories update without losing changes (US4)
- [ ] Missing git gracefully skips activation (no error)
- [ ] Repository cloning occurs after credential deployment
- [ ] Error messages are clear and actionable
- [ ] Documentation is complete and accurate

______________________________________________________________________

## File Modification Summary

**Modified Files**:

1. `system/shared/lib/git.nix` - Add normalizeRepo, resolveRepoPath, mkRepoCloneScriptWithPaths

**New Files**:
2\. `system/shared/settings/git-repos.nix` - Home Manager activation module
3\. `docs/features/032-user-git-repos.md` - User documentation

**Test Files**:

- User configurations in `user/{username}/default.nix` (for testing)

**Total Lines of Code** (estimated):

- git.nix additions: ~80 lines
- git-repos.nix (new): ~150 lines
- Documentation: ~100 lines
- **Total**: ~330 lines

All modules respect the constitutional 200-line limit:

- ✅ git.nix: ~150 lines total (existing ~70 + new ~80)
- ✅ git-repos.nix: ~150 lines (new module)

______________________________________________________________________

## Notes

**Reusing Existing Patterns**:

- Feature 030 (font repos): Activation pattern, SSH auth, DAG ordering
- Feature 027 (secrets): Secret detection, activation guards
- Existing `system/shared/lib/git.nix`: repoName, mkRepoCloneScript

**Constitutional Compliance**:

- ✅ Modules under 200 lines
- ✅ User/system split architecture
- ✅ Cross-platform compatibility
- ✅ Declarative configuration
- ✅ Activation-time execution (not build-time)

**Performance Targets**:

- 3-5 small repositories: < 5 minutes activation time
- Network-bound operation (git clone)
- Sequential cloning (parallel cloning out of scope)
