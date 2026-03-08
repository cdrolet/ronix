# Feature 038: Multi-Provider Repository Support - Research Index

**Feature**: 038-multi-provider-repositories\
**Date**: 2026-01-04\
**Status**: Research Complete - Ready for Implementation\
**Total Documentation**: 2,734 lines across 5 research documents

______________________________________________________________________

## Document Navigation

### 1. **research.md** - PRIMARY RESEARCH DOCUMENT

**What**: Comprehensive research findings on URL pattern detection\
**When to read**: First - foundational understanding\
**Length**: ~800 lines\
**Key sections**:

- Git URL patterns and `.git` suffix optionality
- S3 URI formats (native, path-style, virtual-hosted, regional)
- S3-compatible services (DigitalOcean, MinIO, Backblaze, Wasabi)
- Proton Drive architecture and limitations
- Detection algorithm with 4-stage priority system
- Repository schema extension design
- Technical constraints and integration points
- 8 research references with sources

**Best for**: Understanding the "why" behind design decisions

______________________________________________________________________

### 2. **URL-PATTERN-DETECTION.md** - PATTERN REFERENCE GUIDE

**What**: Concrete regex patterns and detection rules\
**When to read**: Second - specific pattern matching\
**Length**: ~600 lines\
**Key sections**:

- Quick reference detection algorithm flowchart
- Protocol-based detection (100% confidence patterns)
- Hostname-based detection (95%+ confidence patterns)
- Path characteristic patterns (weak signals)
- Complete regex examples for each provider
- Nix implementation pseudocode
- Testing patterns with examples

**Best for**: Looking up specific URL patterns or regex rules

______________________________________________________________________

### 3. **IMPLEMENTATION-EXAMPLES.md** - PRACTICAL CODE EXAMPLES

**What**: Concrete Nix implementations and usage patterns\
**When to read**: Third - when ready to implement\
**Length**: ~700 lines\
**Key sections**:

- User configuration with multiple providers
- Secrets configuration examples
- Justfile command examples
- Provider detection flowchart with 8 examples
- Nix detection library implementation (actual code)
- Git provider handler (refactored Feature 032)
- S3 provider handler (new)
- Proton Drive provider handler (new)
- Error messages and user guidance
- Testing strategies

**Best for**: Copy-paste code examples and actual implementation

______________________________________________________________________

### 4. **DETECTION-ALGORITHM-SUMMARY.md** - ALGORITHM REFERENCE

**What**: Detailed algorithm walkthrough and edge cases\
**When to read**: For algorithm understanding\
**Length**: ~400 lines\
**Key sections**:

- High-level algorithm flowchart
- 4-stage priority system with examples
- 8 real-world case walkthroughs
- Edge case resolution table
- Validation rules and precedence
- O(1) performance characteristics
- Decision flowchart for ambiguous cases
- Testing strategy

**Best for**: Understanding algorithm logic and decisions

______________________________________________________________________

### 5. **RESEARCH-SUMMARY.md** - EXECUTIVE SUMMARY

**What**: Overview of all research findings\
**When to read**: Last - for quick reference\
**Length**: ~400 lines\
**Key sections**:

- Executive summary and key findings
- Git, S3, and Proton Drive pattern summary tables
- Detection priority matrix
- Ambiguous URL handling
- Implementation recommendations (4 steps)
- Architecture decisions with rationale
- Web research sources (16 references)
- Testing recommendations
- Next steps for implementation (5 phases)

**Best for**: Getting the big picture or refreshing memory

______________________________________________________________________

## Quick Reference Tables

### Provider Detection at a Glance

| Provider | Highest Confidence Signal | Regex/Pattern | Detection Confidence |
|----------|--------------------------|---|------|
| **Git** | `git@` prefix | `^git@` | 100% |
| **Git** | `ssh://` prefix | `^ssh://` | 95% |
| **Git** | `git://` prefix | `^git://` | 100% |
| **Git** | `github.com` hostname | contains | 100% |
| **Git** | `gitlab.com` hostname | contains | 100% |
| **Git** | `.git` suffix (weak) | hasSuffix | 70% |
| **S3** | `s3://` prefix | `^s3://` | 100% |
| **S3** | `.s3.amazonaws.com` | contains | 100% |
| **S3** | `.digitaloceanspaces.com` | contains | 100% |
| **S3** | `.backblazeb2.com` | contains | 100% |
| **S3** | `.wasabisys.com` | contains | 100% |
| **Proton** | `drive.proton.me/urls` | contains | 90% |
| **Unknown** | No match | (null) | 0% → Explicit provider |

### Detection Algorithm Stages

```
Stage 1: Protocol Prefix        (100% confidence if match)
         s3:// git@ ssh:// git:// file:// /

Stage 2: Known Hostname         (95-100% confidence if match)
         github.com, gitlab.com, bitbucket.org
         .s3.amazonaws.com, .digitaloceanspaces.com
         drive.proton.me/urls

Stage 3: Path Characteristics   (60-70% confidence, weak)
         .git suffix, bucket/key structure

Stage 4: Unknown                (0% confidence)
         → Require explicit provider field
```

### Example URL Detections

| URL | Detected As | Confidence | Stage |
|-----|---------|-----------|-------|
| `git@github.com:user/repo.git` | Git | 100% | 1 (protocol) |
| `https://github.com/user/repo` | Git | 100% | 2 (hostname) |
| `s3://bucket/path` | S3 | 100% | 1 (protocol) |
| `https://bucket.s3.amazonaws.com/key` | S3 | 100% | 2 (hostname) |
| `https://space.nyc3.digitaloceanspaces.com` | S3 | 100% | 2 (hostname) |
| `https://drive.proton.me/urls/token` | Proton | 90% | 2 (hostname) |
| `https://internal.company.com/data` | Unknown | 0% | 4 (no match) |
| `http://minio.local:9000/bucket` | Unknown | 0% | 4 (no match) |

______________________________________________________________________

## Key Findings Summary

### Git URLs

✓ `.git` suffix is **optional** - Git accepts both with and without
✓ SSH format `git@host:path` is standard for private repos
✓ HTTPS format works for both public and private (with auth)
✓ Newer platforms support cloning without `.git` suffix
✓ Repository name extracted from last path segment

### S3 URLs

✓ Native S3 URI format `s3://bucket/path` is unambiguous
✓ AWS S3 has multiple URL styles (virtual-hosted, path-style, regional)
✓ S3-compatible services (MinIO, DigitalOcean, Backblaze) use subdomain/path patterns
✓ Older formats (dash before region: `s3-us-west-2`) still valid
✓ Bucket names must be 3-63 alphanumeric chars with hyphens

### Proton Drive

✓ No standardized protocol like `git://` or `s3://`
✓ Share links have predictable domain `drive.proton.me/urls/`
✓ API is reverse-engineered (community-maintained tools)
✓ rclone is stable, recommended tooling for automation
✓ Requires explicit authentication (no anonymous access)

### Detection Algorithm

✓ 4-stage priority system handles 95%+ of common cases
✓ Protocol prefix has highest priority (unambiguous)
✓ Known hostnames have strong confidence (95-100%)
✓ Path characteristics are weak signals (60-70%)
✓ Unknown patterns require explicit provider declaration (safer)

### Implementation Strategy

✓ Single unified `user.repositories` schema for all providers
✓ Each provider handler filters by type, no interference
✓ Detection runs at evaluation time (`nix flake check`)
✓ Ambiguous URLs show clear error messages
✓ Backward compatible with existing Feature 032 (git-only)

______________________________________________________________________

## Document Quick Links

### By Purpose

**Understanding the Problem**
→ Start with: **RESEARCH-SUMMARY.md** (Executive Summary)

**Learning Detection Patterns**
→ Read: **URL-PATTERN-DETECTION.md** (Pattern Reference)

**Implementing the Solution**
→ Use: **IMPLEMENTATION-EXAMPLES.md** (Code Examples)

**Understanding the Algorithm**
→ Study: **DETECTION-ALGORITHM-SUMMARY.md** (Algorithm Details)

**Deep Research Diving**
→ Explore: **research.md** (Primary Research)

### By Role

**Architects/Planners**

1. RESEARCH-SUMMARY.md (overview)
1. research.md (design decisions)
1. DETECTION-ALGORITHM-SUMMARY.md (algorithm logic)

**Developers/Implementers**

1. IMPLEMENTATION-EXAMPLES.md (start coding)
1. URL-PATTERN-DETECTION.md (reference patterns)
1. research.md (understand constraints)

**QA/Testers**

1. IMPLEMENTATION-EXAMPLES.md (test examples section)
1. DETECTION-ALGORITHM-SUMMARY.md (test strategy)
1. URL-PATTERN-DETECTION.md (test patterns)

**Reviewers/Decision-Makers**

1. RESEARCH-SUMMARY.md (overview)
1. DETECTION-ALGORITHM-SUMMARY.md (approach validation)
1. research.md (decision rationale)

______________________________________________________________________

## Key Design Decisions

### 1. Priority-Based Detection Algorithm

**Decision**: Use 4-stage priority detection (protocol → hostname → path → explicit)
**Rationale**: Simple, efficient (O(1)), handles 95%+ of cases, clear fallback
**Alternative Rejected**: Exhaustive matching (complex, overkill)

### 2. Explicit Provider for Ambiguous URLs

**Decision**: Require explicit `provider` field for unknown patterns
**Rationale**: Safer, prevents misdetection, clear error messages
**Alternative Rejected**: Best-guess detection (too risky)

### 3. Accept .git Suffix as Optional

**Decision**: Accept git URLs both with and without `.git`
**Rationale**: Git itself doesn't require it, more flexible
**Alternative Rejected**: Validate/require suffix (unnecessary constraint)

### 4. Single Repository Schema

**Decision**: One `user.repositories` schema for all providers
**Rationale**: Users configure once, handlers filter by type
**Alternative Rejected**: Separate schemas per provider (verbose)

### 5. Nix String Functions Only

**Decision**: Use lib.hasPrefix, lib.hasInfix (no complex regex)
**Rationale**: Sufficient, maintainable, follows Nix conventions
**Alternative Rejected**: Complex regex library (overkill)

______________________________________________________________________

## Implementation Roadmap

### Phase 1: Infrastructure (Weeks 1-2)

- [ ] Create `system/shared/lib/provider-detection.nix`
- [ ] Implement `detectProvider` function (4 stages)
- [ ] Add unit tests
- [ ] Document in contracts/

### Phase 2: Refactor Existing (Weeks 2-3)

- [ ] Update `system/shared/settings/git-repos.nix`
- [ ] Update `user/shared/lib/user-schema.nix`
- [ ] Test backward compatibility
- [ ] Verify all tests pass

### Phase 3: S3 Support (Weeks 3-4)

- [ ] Create `system/shared/settings/s3-repos.nix`
- [ ] Implement AWS CLI sync logic
- [ ] Handle S3 options
- [ ] Integration testing

### Phase 4: Proton Drive (Weeks 4-5)

- [ ] Create `system/shared/settings/proton-drive-repos.nix`
- [ ] Integrate rclone
- [ ] Authentication setup
- [ ] Integration testing

### Phase 5: Testing & Docs (Weeks 5-6)

- [ ] Comprehensive test suite
- [ ] User documentation
- [ ] Error messages & troubleshooting
- [ ] Complete feature spec

______________________________________________________________________

## Web References Used

### Git URL Patterns (4 sources)

- Git Clone Documentation (git-scm.com)
- Git repository validation tutorials
- GitHub/GitLab/Bitbucket documentation
- `.git` suffix optionality research

### S3 URL Patterns (4 sources)

- AWS S3 Virtual Hosting guide
- AWS S3 URL Styles reference
- AWS S3 regional endpoints documentation
- Website endpoints documentation

### S3-Compatible Services (4 sources)

- DigitalOcean Spaces with AWS SDKs
- MinIO and S3-compatible support discussions
- Backblaze B2 S3 API documentation
- Wasabi S3-compatible storage

### Proton Drive (4 sources)

- Proton Drive shareable link documentation
- rclone Proton Drive backend
- Proton Drive SDK preview announcement
- Proton Drive security architecture

### Pattern Matching (2 sources)

- URL pattern matching algorithms
- WHATWG URL Pattern Standard

______________________________________________________________________

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Lines of Documentation | 2,734 |
| Number of Documents | 5 |
| Git URL Patterns Documented | 15+ |
| S3 URL Patterns Documented | 12+ |
| Proton Drive Patterns | 4+ |
| Regex Examples | 8+ |
| Implementation Examples | 25+ |
| Test Cases | 20+ |
| Decision Points Documented | 8+ |
| Web Sources Referenced | 18+ |
| Example Configurations | 10+ |
| Error Message Examples | 3+ |

______________________________________________________________________

## Getting Started

### For Quick Understanding (30 minutes)

1. Read RESEARCH-SUMMARY.md
1. Skim URL-PATTERN-DETECTION.md for your provider type
1. Check IMPLEMENTATION-EXAMPLES.md for code samples

### For Implementation (2-3 hours)

1. Read IMPLEMENTATION-EXAMPLES.md completely
1. Study provider handler examples
1. Review DETECTION-ALGORITHM-SUMMARY.md for algorithm
1. Reference URL-PATTERN-DETECTION.md while coding

### For Complete Understanding (4-5 hours)

1. Read all 5 documents in order
1. Study research.md design decisions
1. Review implementation roadmap
1. Plan implementation phases

______________________________________________________________________

## Next Steps

**Immediate**: Review this index and pick relevant documents
**Short-term**: Implement infrastructure (Phase 1) based on examples
**Medium-term**: Complete refactoring and new provider support (Phases 2-4)
**Long-term**: Comprehensive testing and documentation (Phase 5)

______________________________________________________________________

## Questions Answered by This Research

✓ What are all the common git URL formats?
✓ What are all the S3 URI and URL formats?
✓ What S3-compatible services exist and their URL patterns?
✓ What are Proton Drive URL patterns and limitations?
✓ How should the system prioritize pattern matching?
✓ How to handle ambiguous URLs?
✓ What fallback behavior should occur?
✓ How to implement detection in Nix?
✓ What are concrete regex patterns?
✓ How to structure provider handlers?

______________________________________________________________________

**Research Completed**: 2026-01-04\
**Status**: Complete and Ready for Implementation\
**Next Phase**: Feature 038 Implementation Planning\
**Estimated Implementation Time**: 5-6 weeks

See individual documents for detailed information on your area of interest.
