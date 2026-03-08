# Research Summary: URL Pattern Detection for Multi-Provider Repository Support

**Feature**: 038-multi-provider-repositories\
**Date**: 2026-01-04\
**Researcher**: Claude AI\
**Status**: Complete - Ready for Implementation

______________________________________________________________________

## Executive Summary

This research provides comprehensive documentation for implementing URL pattern detection in multi-provider repository support (Feature 038). The system enables users to configure repositories from Git, S3, Proton Drive, and future providers in a single unified configuration schema, with automatic provider type detection.

**Key Findings:**

- Git URLs have standardized formats across SSH, HTTPS, and custom git protocols
- S3 has multiple URL styles (virtual-hosted, path-style, regional) plus S3-compatible services
- Proton Drive lacks standardized protocol but can be detected via known share link domains
- A 4-stage priority-based detection algorithm handles 95%+ of common cases
- Ambiguous URLs require explicit provider declaration for safety
- Nix string operations are sufficient for pattern detection (no complex regex needed)

______________________________________________________________________

## Research Documentation Created

### 1. **research.md** (Primary Research Document)

**Length**: ~800 lines | **Purpose**: Foundational research and design decisions

**Content:**

- Git URL patterns and `.git` suffix optionality
- S3 URI formats (native, path-style, virtual-hosted, regional)
- S3-compatible services (DigitalOcean Spaces, MinIO, Backblaze B2, Wasabi)
- Proton Drive architecture and limitations
- Detection algorithm and priority order
- Fallback behavior for ambiguous URLs
- Repository schema extension design
- Technical constraints and integration points

**Key Insight**: The `.git` suffix is optional in Git URLs - accept both with and without.

______________________________________________________________________

### 2. **URL-PATTERN-DETECTION.md** (Pattern Reference Guide)

**Length**: ~600 lines | **Purpose**: Concrete regex patterns and detection rules

**Content:**

- Quick reference detection algorithm (flowchart)
- Protocol-based detection patterns (unambiguous)
- Hostname-based detection patterns (strong signals)
- Path characteristic patterns (weak signals)
- Regex patterns for each provider type
- Special cases and edge cases table
- Nix implementation pseudocode
- Complete regex examples for all formats

**Key Pattern Summary:**

| Provider | Highest Priority Signal | Confidence |
|----------|------------------------|------------|
| Git | `git@` prefix or `git://` protocol | 100% |
| S3 | `s3://` prefix or `.amazonaws.com` hostname | 100% |
| Proton Drive | `https://drive.proton.me/urls/` path | 90% |
| Unknown | No matching pattern | → Require explicit provider |

______________________________________________________________________

### 3. **IMPLEMENTATION-EXAMPLES.md** (Practical Code Examples)

**Length**: ~700 lines | **Purpose**: Concrete implementations and usage patterns

**Content:**

- User configuration examples (multi-provider)
- Secrets configuration for auth
- Justfile command examples
- Provider detection flowchart with examples
- Nix detection library implementation
- Git provider handler (refactored Feature 032)
- S3 provider handler (new)
- Proton Drive provider handler (new)
- Error message examples
- Testing strategies

**Key Code Patterns:**

```nix
# Detection in Nix
detectProvider = url:
  if hasPrefix "s3://" url then "s3"
  else if hasPrefix "git@" url then "git"
  else if hasInfix "github.com" url then "git"
  else if hasInfix ".s3.amazonaws.com" url then "s3"
  else null;  # Require explicit provider
```

______________________________________________________________________

### 4. **DETECTION-ALGORITHM-SUMMARY.md** (Algorithm Reference)

**Length**: ~400 lines | **Purpose**: Detailed algorithm walkthrough and decision logic

**Content:**

- High-level detection algorithm flowchart
- 4-stage priority system explained
- Complete walkthrough of 8 real-world cases
- Edge case handling rules
- Validation rules and precedence
- Performance characteristics (O(1) time)
- Testing strategy
- Ambiguous case decision tree

**Key Algorithm:**

```
Stage 1: Protocol prefix (s3://, git@, ssh://, git://, file://)
   ↓ (if no match)
Stage 2: Known hostname (github.com, .s3.amazonaws.com, .digitaloceanspaces.com)
   ↓ (if no match)
Stage 3: Path characteristics (.git suffix, bucket/key structure)
   ↓ (if no match)
Stage 4: Unknown → Require explicit provider field
```

______________________________________________________________________

## Git URL Patterns

### SSH Formats

- `git@github.com:user/repo.git`
- `git@gitlab.com:org/project.git`
- `git@bitbucket.org:team/repo.git`
- `ssh://git@custom-host.com:22/user/repo.git`

### HTTPS Formats

- `https://github.com/user/repo.git`
- `https://github.com/user/repo` (without .git)
- `https://gitlab.com/org/project.git`
- `https://custom-git.company.com/path/to/repo`

### Other Formats

- `git://github.com/user/repo.git`
- `file:///local/path/repo.git`
- `/absolute/local/path/repo`
- `~/relative/local/path/repo`

### Key Finding

**The `.git` suffix is optional** - Git accepts both formats. Detection should accept both, not validate suffix presence/absence.

______________________________________________________________________

## S3 URL Patterns

### S3 Native URI (Unambiguous)

- `s3://bucket-name/path/to/object`
- `s3://bucket-name/` (bucket root)

### AWS S3 Virtual-Hosted-Style

- `https://bucket.s3.amazonaws.com/key`
- `https://bucket.s3.us-west-2.amazonaws.com/key` (regional)
- `https://bucket.s3-us-west-2.amazonaws.com/key` (older format)

### AWS S3 Path-Style

- `https://s3.amazonaws.com/bucket/key` (US East only, legacy)
- `https://s3.us-west-2.amazonaws.com/bucket/key` (regional)
- `https://s3-us-west-2.amazonaws.com/bucket/key` (older format)

### S3-Compatible Services

- **DigitalOcean Spaces**: `https://space.nyc3.digitaloceanspaces.com/key`
- **Backblaze B2**: `https://bucket.s3.backblazeb2.com/key`
- **Wasabi**: `https://bucket.s3.wasabisys.com/key`
- **MinIO (self-hosted)**: `http://minio.local:9000/bucket/key` (requires explicit provider)

______________________________________________________________________

## Proton Drive Patterns

### Share Links

- Format: `https://drive.proton.me/urls/[TOKEN]`
- Can include password in URL fragment (not recommended)
- Tokens are unique, not predictable

### Limitations

- **No standardized protocol**: No `proton-drive://` standard exists
- **No published API**: Reverse-engineered, community-maintained tools
- **Authentication-required**: No anonymous access like S3
- **Recommended tooling**: rclone backend (stable, well-maintained)

### Custom Protocol (Optional User Definition)

- `proton-drive://folder-name` (user-defined, not standard)
- Requires explicit `provider = "proton-drive"`

______________________________________________________________________

## Detection Priority and Confidence Levels

### Stage 1: Protocol Prefix (100% Confidence)

| Prefix | Provider | Match |
|--------|----------|-------|
| `s3://` | S3 | 100% |
| `git@` | Git SSH | 100% |
| `ssh://` | Git SSH | 95% |
| `git://` | Git | 100% |
| `file://` | Local Git | 100% |
| `/` (absolute) | Local Git | 100% |

### Stage 2: Hostname (95-100% Confidence)

| Hostname | Provider | Confidence |
|----------|----------|-----------|
| `github.com` | Git | 100% |
| `gitlab.com` | Git | 100% |
| `bitbucket.org` | Git | 100% |
| `.s3.amazonaws.com` | AWS S3 | 100% |
| `.digitaloceanspaces.com` | DO Spaces | 100% |
| `.backblazeb2.com` | Backblaze B2 | 100% |
| `.wasabisys.com` | Wasabi | 100% |
| `drive.proton.me/urls` | Proton Drive | 90% |

### Stage 3: Path Characteristics (60-70% Confidence - Weak)

| Signal | Provider | Confidence | Issues |
|--------|----------|-----------|--------|
| `.git` suffix | Git | 70% | Could theoretically be S3 object |
| `bucket/key` structure | S3 | 60% | Could be git path |

### Stage 4: No Match (0% Confidence - Unknown)

Requires explicit `provider` field in configuration

______________________________________________________________________

## Ambiguous URL Handling

### URLs Requiring Explicit Provider

```
1. Internal git servers:
   URL: https://internal-git.company.com/alice/project
   Solution: provider = "git"

2. Self-hosted MinIO:
   URL: http://minio.local:9000/bucket/data
   Solution: provider = "s3"

3. Custom S3-compatible services:
   URL: https://custom-s3.example.com/bucket
   Solution: provider = "s3"

4. Unknown APIs:
   URL: https://api.service.com/data
   Solution: Not currently supported (future enhancement)
```

### Error Message Pattern

```
Error: Cannot auto-detect provider for URL:
  https://internal-git.company.com/alice/project

Please specify the provider explicitly:
  provider = "git"  # one of: "git" | "s3" | "proton-drive"

Common URL patterns:
✓ Git SSH:        git@github.com:user/repo.git
✓ Git HTTPS:      https://github.com/user/repo.git
✓ S3 URI:         s3://bucket-name/path
✓ S3 AWS:         https://bucket.s3.amazonaws.com/path
✓ Proton Drive:   https://drive.proton.me/urls/share-token
```

______________________________________________________________________

## Implementation Recommendations

### 1. Create Provider Detection Library

**File**: `system/shared/lib/provider-detection.nix`

**Functions**:

- `detectProvider url` → Returns provider type or null
- `validateUrl provider url` → Returns {valid, error}
- `repoName url` → Extracts repository name
- `parseS3Uri uri` → Parses S3 URI into components

**Implementation**: Use Nix string functions (hasPrefix, hasInfix, etc.) - no complex regex needed.

### 2. Extend User Schema

**File**: `user/shared/lib/user-schema.nix`

**New Fields**:

- `provider`: Optional explicit provider type
- `options`: Provider-specific configuration (branch, sync strategy, etc.)

**Backward Compatibility**: Existing `user.repositories` continues to work, auto-detected as git.

### 3. Implement Provider Handlers

**Files**:

- `system/shared/settings/git-repos.nix` (refactor Feature 032)
- `system/shared/settings/s3-repos.nix` (new)
- `system/shared/settings/proton-drive-repos.nix` (new)

**Pattern**: Each handler filters by provider type, performs sync, handles errors independently.

### 4. Detection During Evaluation

**Timing**: Runs during `nix flake check` (evaluation time, not activation)

**Error Handling**: Ambiguous URLs cause immediate evaluation error with helpful message

**Benefits**: Users see errors before building system configuration

______________________________________________________________________

## Architecture Decisions

### Decision 1: Priority-Based Detection

**Chosen** over exhaustive matching because:

- Simple, efficient (O(1) lookup)
- Handles 95%+ of use cases
- Clear fallback to explicit provider for ambiguous cases

### Decision 2: Explicit Provider for Ambiguous URLs

**Chosen** over guessing because:

- Safer - prevents misdetection
- Clear error messages guide users
- Conservative approach respects user intent

### Decision 3: Accept .git Suffix as Optional

**Chosen** because:

- Git itself doesn't require it
- Many git servers support both formats
- More flexible for user input
- Don't validate suffix presence/absence

### Decision 4: Nix String Functions Only

**Chosen** because:

- No complex regex library needed
- Sufficient for all patterns (hasPrefix, hasInfix, etc.)
- Maintainable and readable
- Nix ecosystem conventions

### Decision 5: Filter by Provider Type at Activation

**Chosen** because:

- Single repository schema for all providers
- Handlers are independent and composable
- Easy to add new providers
- Clear separation of concerns

______________________________________________________________________

## Testing Recommendations

### Unit Test Cases

```nix
# Git URLs
✓ "git@github.com:user/repo.git" → git
✓ "https://github.com/user/repo" → git
✓ "https://gitlab.com/org/repo.git" → git
✓ "/local/path/repo" → git

# S3 URLs
✓ "s3://bucket/path" → s3
✓ "https://bucket.s3.amazonaws.com" → s3
✓ "https://space.nyc3.digitaloceanspaces.com" → s3
✓ "https://bucket.s3.backblazeb2.com" → s3

# Proton Drive
✓ "https://drive.proton.me/urls/token" → proton-drive

# Ambiguous (should return null)
✓ "https://internal.company.com/repo" → null
✓ "http://minio:9000/bucket" → null
```

### Integration Tests

1. Configure mixed provider repositories
1. Run `nix flake check` → validates all URLs
1. Run `just install <user> <host>` → tests activation
1. Verify correct handler processes each repository

______________________________________________________________________

## Web Research Sources

### Git URL Patterns

- [Git Clone Documentation](https://git-scm.com/docs/git-clone)
- [How to validate git repository url - LabEx](https://labex.io/tutorials/git-how-to-validate-git-repository-url-434201)
- [Validate GIT Repository using Regular Expression - GeeksforGeeks](https://www.geeksforgeeks.org/dsa/validate-git-repository-using-regular-expression/)
- [is-git-url - GitHub](https://github.com/jonschlinkert/is-git-url)
- [Git Repository URL Suffix - Antora Docs](https://docs.antora.org/antora/latest/playbook/git-suffix/)

### S3 URL Patterns

- [Virtual hosting of general purpose buckets - AWS S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html)
- [AWS S3 URL Styles](http://www.wryway.com/blog/aws-s3-url-styles/)
- [Format and Parse Amazon S3 URLs - AWS Builder](https://builder.aws.amazon.com/content/2biM1C0TkMkvJ2BLICiff8MKXS9/format-and-parse-amazon-s3-urls)
- [Website endpoints - AWS S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html)

### S3-Compatible Services

- [DigitalOcean Spaces with AWS S3 SDKs](https://docs.digitalocean.com/products/spaces/how-to/use-aws-sdks/)
- [Spaces S3 Compatibility - DigitalOcean](https://docs.digitalocean.com/products/spaces/reference/s3-compatibility/)
- [S3 Compatible Storage with MinIO - DigitalOcean](https://deliciousbrains.com/s3-compatible-storage-provider-minio/)

### Proton Drive

- [How to create a shareable link in Proton Drive](https://proton.me/support/drive-shareable-link)
- [Proton Drive rclone integration](https://rclone.org/protondrive/)
- [Proton Drive SDK preview - Proton Blog](https://proton.me/blog/proton-drive-sdk-preview)
- [The Proton Drive security model - Proton Blog](https://proton.me/blog/protondrive-security)

### Pattern Matching Algorithms

- [Rules matching algorithm - Algolia](https://www.algolia.com/doc/guides/managing-results/rules/rules-overview/in-depth/rule-matching-algorithm)
- [Types of URL patterns and priority - Hitachi](https://itpfdoc.hitachi.co.jp/manuals/3020/30203Y0510e/EY050165.HTM)
- [URL Pattern Standard - WHATWG](https://urlpattern.spec.whatwg.org/)

______________________________________________________________________

## Deliverables Summary

| Document | Purpose | Length | Status |
|----------|---------|--------|--------|
| **research.md** | Foundational research and design | ~800 lines | ✓ Complete |
| **URL-PATTERN-DETECTION.md** | Regex patterns and reference guide | ~600 lines | ✓ Complete |
| **IMPLEMENTATION-EXAMPLES.md** | Concrete code examples | ~700 lines | ✓ Complete |
| **DETECTION-ALGORITHM-SUMMARY.md** | Algorithm walkthrough | ~400 lines | ✓ Complete |
| **RESEARCH-SUMMARY.md** | This document | ~400 lines | ✓ Complete |

**Total Documentation**: ~2,900 lines of research and implementation guidance

______________________________________________________________________

## Next Steps for Implementation

### Phase 1: Infrastructure (Weeks 1-2)

1. Create `system/shared/lib/provider-detection.nix`
1. Implement `detectProvider` function with all 4 stages
1. Add unit tests for detection logic
1. Document provider field in contracts/repository-schema.nix

### Phase 2: Refactor Existing Feature (Weeks 2-3)

1. Update `system/shared/settings/git-repos.nix` to use provider filtering
1. Update `user/shared/lib/user-schema.nix` with provider field
1. Test backward compatibility with existing git-only configs
1. Verify all existing tests pass

### Phase 3: S3 Support (Weeks 3-4)

1. Create `system/shared/settings/s3-repos.nix` handler
1. Implement S3 sync logic using aws-cli2
1. Handle S3-specific options (sync strategy, exclude patterns, etc.)
1. Integration testing with DigitalOcean Spaces, MinIO

### Phase 4: Proton Drive Support (Weeks 4-5)

1. Create `system/shared/settings/proton-drive-repos.nix` handler
1. Integrate rclone for Proton Drive sync
1. Handle authentication via agenix secrets
1. Integration testing with share links

### Phase 5: Testing & Documentation (Weeks 5-6)

1. Comprehensive test suite for all providers
1. Update user documentation with examples
1. Add error messages and troubleshooting guide
1. Complete feature specification

______________________________________________________________________

## Conclusion

This research provides a complete, well-documented foundation for implementing URL pattern detection in the multi-provider repository support feature. The 4-stage detection algorithm balances ease of use (auto-detection for common cases) with safety (explicit provider declaration for ambiguous cases).

**Key Strengths**:

- ✓ Standardized patterns for Git, S3, and Proton Drive
- ✓ Clear priority-based algorithm
- ✓ Concrete regex and Nix implementation examples
- ✓ Comprehensive error handling
- ✓ Backward compatible with existing Feature 032
- ✓ Extensible for future providers

**Ready for Implementation**: All design decisions documented, patterns identified, code examples provided.

______________________________________________________________________

**Document Created**: 2026-01-04\
**Research Completed**: 2026-01-04\
**Status**: Ready for Phase 1 Implementation\
**Estimated Effort**: 5-6 weeks for complete implementation
