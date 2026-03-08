# Tasks: App Discovery System

**Input**: Design documents from `/specs/014-app-discovery-system/`\
**Prerequisites**: plan.md, spec.md, data-model.md

**Organization**: Tasks grouped by implementation phase for incremental delivery

## Format: `[ID] [P?] [Phase] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Phase]**: Implementation phase (P1-P8)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Core Discovery Functions (MVP Foundation)

**Purpose**: Add app resolution logic to discovery.nix

- [ ] T001 Add `findRepoRoot` helper function to `system/shared/lib/discovery.nix` (climb up from caller path until .git or flake.nix found)
- [ ] T002 [P] Add `detectContext` function to `system/shared/lib/discovery.nix` (determine if caller is user-config, darwin-profile, nixos-profile, or unknown)
- [ ] T003 [P] Add `buildSearchPaths` function to `system/shared/lib/discovery.nix` (create prioritized list of search paths based on context)
- [ ] T004 Add `findAppInPath` function to `system/shared/lib/discovery.nix` (recursive search for app.nix in directory)
- [ ] T005 Add `matchPartialPath` function to `system/shared/lib/discovery.nix` (match app paths containing "/")
- [ ] T006 Add `resolveApp` function to `system/shared/lib/discovery.nix` (resolve single app name to path using search paths)
- [ ] T007 Add `resolveApplications` main function to `system/shared/lib/discovery.nix` (orchestrate app resolution for list of apps)
- [ ] T008 Export new functions in `system/shared/lib/discovery.nix` (add to `in { inherit ... }` block)
- [ ] T009 Test `resolveApplications` in nix repl with simple app name (verify git resolves correctly)
- [ ] T010 Test `resolveApplications` with platform-specific app (verify aerospace resolves correctly)

**Checkpoint**: discovery.nix has working resolveApplications function

______________________________________________________________________

## Phase 2: Applications Module (Integration)

**Purpose**: Create module that integrates with discovery functions

- [ ] T011 Create `system/shared/lib/applications.nix` file
- [ ] T012 Define `options.applications` in `applications.nix` (type: listOf str, default: [], with description and examples)
- [ ] T013 Import discovery.nix in `applications.nix` (let discovery = import ./discovery.nix { inherit lib; };)
- [ ] T014 Implement config.imports generation in `applications.nix` (call resolveApplications and convert to imports)
- [ ] T015 Add passthru for debugging in `applications.nix` (expose resolved paths for troubleshooting)
- [ ] T016 Test applications module in isolation (create test config that imports it)
- [ ] T017 Verify imports generated correctly (check that resolved paths are valid)

**Checkpoint**: applications.nix module functional and ready to use

______________________________________________________________________

## Phase 3: User Story 1 - Simple App Declaration (P1 MVP)

**Purpose**: Validate simple name resolution works end-to-end

- [ ] T018 Backup current `user/cdrokar/default.nix` (copy to user/cdrokar/default.nix.backup)
- [ ] T019 Update `user/cdrokar/default.nix` to import `../shared/lib/applications.nix`
- [ ] T020 Add `applications = []` list to `user/cdrokar/default.nix` with 3 test apps: ["git" "zsh" "helix"]
- [ ] T021 Comment out manual imports in `user/cdrokar/default.nix` (keep as reference during testing)
- [ ] T022 Build configuration (run `nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system`)
- [ ] T023 Verify all 3 apps resolved correctly (check build output for import paths)
- [ ] T024 Add remaining apps to applications list in `user/cdrokar/default.nix` (all 10+ apps)
- [ ] T025 Build configuration with full app list (verify no errors)
- [ ] T026 Test dry-run activation (run `darwin-rebuild build --flake .#cdrokar-home-macmini-m4`)
- [ ] T027 Verify no duplicate imports (compare with manual import version)

**Checkpoint**: Simple name resolution working for real user config

______________________________________________________________________

## Phase 4: User Story 2 - Platform-Specific Priority (P1 MVP)

**Purpose**: Validate platform-specific apps prioritized correctly

- [ ] T028 Test resolveApplications from user config context (verify shared/app/ searched first)
- [ ] T029 Test resolveApplications from darwin profile context (verify darwin/app/ searched first)
- [ ] T030 Create test app in both `system/darwin/app/testapp.nix` and `system/shared/app/testapp.nix` (same name, different content)
- [ ] T031 Resolve "testapp" from darwin profile (should get darwin version)
- [ ] T032 Resolve "testapp" from user config (should get shared version)
- [ ] T033 Delete test apps created in T030
- [ ] T034 Document priority rules in `system/shared/lib/applications.nix` (add comments explaining platform priority)
- [ ] T035 Add priority rule examples to README.md

**Checkpoint**: Platform-specific priority working as designed

______________________________________________________________________

## Phase 5: User Story 3 - Path Disambiguation (P2)

**Purpose**: Support partial and full paths for disambiguation

- [ ] T036 Test partial path resolution: "darwin/aerospace" (should find system/darwin/app/aerospace.nix)
- [ ] T037 Test partial path resolution: "shared/app/dev/git" (should find system/shared/app/dev/git.nix)
- [ ] T038 Test full path resolution: "system/shared/app/editor/helix" (should find exact path)
- [ ] T039 Test mixed list: ["git" "darwin/aerospace" "shared/app/shell/zsh"] (all should resolve)
- [ ] T040 Update `user/cdrokar/default.nix` to use partial paths for platform-specific apps (for clarity)
- [ ] T041 Build configuration with partial paths (verify works correctly)
- [ ] T042 Document path disambiguation syntax in quickstart.md
- [ ] T043 Add path disambiguation examples to README.md

**Checkpoint**: Path disambiguation working for all formats

______________________________________________________________________

## Phase 6: User Story 4 - Error Messages (P2)

**Purpose**: Provide helpful errors when apps not found

- [ ] T044 Implement `formatError` function in `system/shared/lib/discovery.nix` (generate error message with searched paths)
- [ ] T045 Implement `getAllAvailableApps` function in `system/shared/lib/discovery.nix` (scan app directories for fuzzy matching)
- [ ] T046 Implement `fuzzyMatchApps` function in `system/shared/lib/discovery.nix` (simple prefix/suffix matching)
- [ ] T047 Integrate error formatting in `resolveApp` function (throw formatted error when app not found)
- [ ] T048 Test error message with nonexistent app (add "nonexistent-app" to applications list and verify error)
- [ ] T049 Verify error shows searched paths (check error message format)
- [ ] T050 Verify error shows suggestions (check fuzzy matched similar apps shown)
- [ ] T051 Remove test nonexistent app
- [ ] T052 Document error troubleshooting in quickstart.md

**Checkpoint**: Clear, actionable error messages implemented

______________________________________________________________________

## Phase 7: Documentation & Migration

**Purpose**: Update all documentation with new pattern

- [ ] T053 [P] Update README.md "Adding a New User" section (show applications pattern)
- [ ] T054 [P] Update README.md "Adding New Content" section (document applications list)
- [ ] T055 [P] Create "App Discovery" section in README.md (explain pattern, benefits, examples)
- [ ] T056 [P] Add migration guide to README.md (show before/after, migration steps)
- [ ] T057 Update `docs/guides/architecture.md` with application discovery section
- [ ] T058 Create example user config template in `docs/examples/user-with-applications.nix` (show best practices)
- [ ] T059 Document performance characteristics in plan.md (update with actual benchmarks)
- [ ] T060 Create troubleshooting guide in quickstart.md (common issues and solutions)

**Checkpoint**: Complete documentation for app discovery system

______________________________________________________________________

## Phase 8: Testing & Validation

**Purpose**: Comprehensive testing and validation

- [ ] T061 Test `user/cdrokar/default.nix` with applications list (verify all apps resolve)
- [ ] T062 Test `user/cdrolet/default.nix` with applications list (migrate and test work user)
- [ ] T063 Test mixed manual imports + applications list (verify both work together)
- [ ] T064 Test from profile config (add applications to profile if applicable)
- [ ] T065 Benchmark build time before and after (compare with manual imports)
- [ ] T066 Verify performance < 10% regression (check benchmarks)
- [ ] T067 Test all error scenarios (nonexistent app, ambiguous path, invalid format)
- [ ] T068 Test backward compatibility (verify manual imports still work)
- [ ] T069 Run full system build (nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system)
- [ ] T070 Test actual activation (darwin-rebuild switch --flake .#cdrokar-home-macmini-m4)
- [ ] T071 Verify all apps installed correctly (check Home Manager packages)
- [ ] T072 Create feature summary in `docs/features/014-app-discovery-system.md`

**Checkpoint**: Fully tested and validated app discovery system

______________________________________________________________________

## Phase 9: Cleanup & Finalize

**Purpose**: Clean up test files and finalize implementation

- [ ] T073 Remove any test files created during development
- [ ] T074 Remove backup files (user/cdrokar/default.nix.backup)
- [ ] T075 Review all code for TODOs and FIXMEs
- [ ] T076 Final code review of all changes
- [ ] T077 Update spec.md status to "Implemented"
- [ ] T078 Commit all changes with descriptive message referencing feature 014

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Core)**: No dependencies - foundation
- **Phase 2 (Module)**: Depends on Phase 1 (needs resolveApplications)
- **Phase 3 (Simple Names)**: Depends on Phases 1-2 (needs module)
- **Phase 4 (Platform Priority)**: Depends on Phase 3 (validation)
- **Phase 5 (Disambiguation)**: Depends on Phase 3 (extension)
- **Phase 6 (Errors)**: Depends on Phase 3 (can implement alongside)
- **Phase 7 (Docs)**: Can start after Phase 3 MVP
- **Phase 8 (Testing)**: Depends on all features complete
- **Phase 9 (Cleanup)**: Depends on Phase 8 (final step)

### Critical Path

```
P1 → P2 → P3 → P4/P5/P6 (parallel) → P7 (parallel) → P8 → P9
```

### Parallel Opportunities

- **Phase 1**: T002 (detectContext) and T003 (buildSearchPaths) independent
- **Phase 4-6**: Can implement in parallel after Phase 3
- **Phase 7**: All documentation tasks (T053-T060) can run in parallel

______________________________________________________________________

## Implementation Strategy

### MVP First (Phases 1-3)

1. Complete Phase 1: Core functions
1. Complete Phase 2: Module integration
1. Complete Phase 3: Validate with real config
1. **STOP and VALIDATE**: Test with one user, gather feedback

### Feature Complete (Phases 4-6)

1. Add Phase 4: Platform priority
1. Add Phase 5: Path disambiguation
1. Add Phase 6: Error messages
1. **STOP and VALIDATE**: Test all features

### Finalize (Phases 7-9)

1. Complete Phase 7: Documentation
1. Complete Phase 8: Testing
1. Complete Phase 9: Cleanup
1. **DONE**: Ready for production

______________________________________________________________________

## Testing Checklist

### Unit Testing (Nix REPL)

```nix
# Test resolveApplications function
nix repl
> :l <nixpkgs>
> discovery = import ./system/shared/lib/discovery.nix { inherit (pkgs) lib; }

# Test 1: Simple name
> discovery.resolveApplications { apps = ["git"]; callerPath = ./user/test; }

# Test 2: Platform priority
> discovery.resolveApplications { apps = ["aerospace"]; callerPath = ./system/darwin/profiles/test; }

# Test 3: Partial path
> discovery.resolveApplications { apps = ["darwin/aerospace"]; callerPath = ./user/test; }

# Test 4: Multiple apps
> discovery.resolveApplications { apps = ["git" "zsh" "helix"]; callerPath = ./user/test; }
```

### Integration Testing

```bash
# Test 1: Build with applications list
cd /Users/charles/project/nix-config
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system

# Test 2: Verify imports
nix eval .#darwinConfigurations.cdrokar-home-macmini-m4.config.imports --json | jq

# Test 3: Mixed imports
# (manual imports + applications list)
nix build .#darwinConfigurations.test-mixed.system

# Test 4: Error handling
# Config with nonexistent app
nix build .#darwinConfigurations.test-error.system 2>&1 | grep "not found"
```

### Performance Testing

```bash
# Benchmark baseline (manual imports)
time nix eval .#darwinConfigurations.cdrokar-home-macmini-m4.config --raw

# Benchmark with applications list
time nix eval .#darwinConfigurations.cdrokar-home-macmini-m4.config --raw

# Calculate difference
# Should be < 10% increase
```

______________________________________________________________________

## Success Criteria

### Must Have (MVP - Phases 1-3)

- ✅ resolveApplications function works
- ✅ applications module integrates correctly
- ✅ Simple names resolve to correct paths
- ✅ Configuration builds successfully
- ✅ No duplicate imports
- ✅ 100% backward compatible

### Should Have (Full - Phases 4-6)

- ✅ Platform-specific priority works
- ✅ Path disambiguation supported
- ✅ Clear error messages with suggestions
- ✅ Performance < 10% regression

### Nice to Have (Polish - Phases 7-9)

- ✅ Complete documentation
- ✅ Migration examples
- ✅ Troubleshooting guide
- ✅ Feature summary document

______________________________________________________________________

## Rollback Plan

At any point, can revert to manual imports:

1. **Phase 3+**: Replace applications list with manual imports
1. **Phase 2+**: Remove applications.nix from imports
1. **Phase 1+**: New functions in discovery.nix harmless if unused

**No Breaking Changes**: Feature is purely additive, opt-in

______________________________________________________________________

## Notes

- Focus on MVP first (Phases 1-3)
- Get feedback before building all features
- Keep manual imports working throughout
- Test incrementally at each phase
- Document as you go
- Commit after each major phase

______________________________________________________________________

## Estimated Time

- **Phase 1**: 4-6 hours (core functions)
- **Phase 2**: 2-3 hours (module)
- **Phase 3**: 2-3 hours (MVP validation)
- **Phase 4**: 2-3 hours (platform priority)
- **Phase 5**: 2-3 hours (disambiguation)
- **Phase 6**: 3-4 hours (error messages)
- **Phase 7**: 3-4 hours (documentation)
- **Phase 8**: 4-5 hours (testing)
- **Phase 9**: 1-2 hours (cleanup)

**Total**: 23-33 hours (3-4 days)
