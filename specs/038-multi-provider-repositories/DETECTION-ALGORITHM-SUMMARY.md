# URL Pattern Detection Algorithm Summary

**Feature**: 038-multi-provider-repositories\
**Date**: 2026-01-04\
**Purpose**: Executive summary of URL pattern detection system for multi-provider repository support

## Detection Algorithm Overview

The system automatically identifies repository providers based on URL patterns, falling back to explicit provider declaration for ambiguous URLs.

### High-Level Logic

```
┌─────────────────────────────────────────────────────────────────┐
│ Input: URL string + Optional explicit provider field             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Explicit    │
                    │ provider    │
                    │ specified?  │
                    └──────┬──────┘
                 YES │      │ NO
              ┌──────▼─┐    │
              │ Return │    │
              │ it     │    │
              └────────┘    │
                            ▼
            ┌───────────────────────────────┐
            │ Check Protocol Prefix         │
            │ (highest confidence)          │
            ├───────────────────────────────┤
            │ s3://       → S3              │
            │ git@        → Git SSH         │
            │ ssh://      → Git             │
            │ git://      → Git             │
            │ file://     → Local Git       │
            │ /path       → Local Git       │
            └───────────────────┬───────────┘
                 MATCH │        │ NO MATCH
              ┌────────▼─┐      │
              │ Return   │      │
              │ provider │      │
              └──────────┘      │
                                ▼
            ┌───────────────────────────────┐
            │ Check Hostname Pattern        │
            │ (high confidence)             │
            ├───────────────────────────────┤
            │ github.com        → Git       │
            │ gitlab.com        → Git       │
            │ bitbucket.org     → Git       │
            │ .amazonaws.com    → S3        │
            │ .digitalocean...  → S3        │
            │ .backblazeb2.com  → S3        │
            │ .wasabisys.com    → S3        │
            │ drive.proton.me   → Proton    │
            └───────────────────┬───────────┘
                 MATCH │        │ NO MATCH
              ┌────────▼─┐      │
              │ Return   │      │
              │ provider │      │
              └──────────┘      │
                                ▼
            ┌───────────────────────────────┐
            │ Check Path Characteristics    │
            │ (medium confidence)           │
            ├───────────────────────────────┤
            │ .git suffix       → Git       │
            │ /key structure    → S3 (weak) │
            └───────────────────┬───────────┘
                 MATCH │        │ NO MATCH
              ┌────────▼─┐      │
              │ Return   │      │
              │ provider │      │
              └──────────┘      │
                                ▼
            ┌───────────────────────────────┐
            │ Return: null (unknown)        │
            │ → Require explicit provider   │
            └───────────────────────────────┘
```

## Pattern Matching Priority

### 1. Protocol-Based Detection (Unambiguous)

**Highest priority — immediate match**

| Protocol | Provider | Regex | Confidence |
|----------|----------|-------|-----------|
| `s3://` | S3 | `^s3://` | 100% |
| `git@` | Git SSH | `^git@` | 100% |
| `ssh://` | Git SSH | `^ssh://` | 95% |
| `git://` | Git | `^git://` | 100% |
| `file://` or `/` | Git | `^file://\|^/` | 100% |

**Examples:**

- ✓ `s3://bucket/path` → **S3** (definitive)
- ✓ `git@github.com:user/repo` → **Git** (definitive)
- ✓ `/local/path/repo` → **Git** (definitive)

### 2. Hostname-Based Detection (Strong)

**High confidence — examined when protocol is generic (http/https)**

| Hostname | Provider | Pattern | Confidence |
|----------|----------|---------|-----------|
| `github.com` | Git | exact match | 100% |
| `gitlab.com` | Git | exact match | 100% |
| `bitbucket.org` | Git | exact match | 100% |
| `.s3.amazonaws.com` | AWS S3 | contains | 100% |
| `.s3-*.amazonaws.com` | AWS S3 | contains | 100% |
| `s3.amazonaws.com` | AWS S3 | contains | 100% |
| `s3-*.amazonaws.com` | AWS S3 | contains | 100% |
| `.digitaloceanspaces.com` | DO Spaces | contains | 100% |
| `.backblazeb2.com` | Backblaze B2 | contains | 100% |
| `.wasabisys.com` | Wasabi | contains | 100% |
| `drive.proton.me/urls` | Proton Drive | path match | 90% |

**Examples:**

- ✓ `https://github.com/user/repo` → **Git** (strong)
- ✓ `https://bucket.s3.us-west-2.amazonaws.com/key` → **S3** (strong)
- ✓ `https://space.nyc3.digitaloceanspaces.com/path` → **S3** (strong)
- ✓ `https://drive.proton.me/urls/token` → **Proton** (strong)

### 3. Path Characteristics (Medium Confidence)

**Lower priority — weak signals requiring validation**

| Characteristic | Provider | Confidence | Issues |
|---|---|---|---|
| `.git` suffix | Git | 70% | Could theoretically be S3 object |
| `bucket/key` structure | S3 | 60% | Could be git path |
| Share token format | Proton | 50% | Insufficient alone |

**Examples:**

- ⚠ `https://example.com/repo.git` → Could be Git **or** S3-compatible (ambiguous)
- ⚠ `https://example.com/bucket/key` → Could be S3 **or** Git (ambiguous)

### 4. Explicit Provider Declaration (Final)

**Highest overall priority — user overrides auto-detection**

```nix
{
  url = "https://ambiguous-host.company.com/data";
  provider = "git";  # User specifies explicitly
  # This overrides any auto-detection logic
}
```

## Complete Detection Example Walkthrough

### Case 1: Simple Git Repository (SSH)

```
Input: git@github.com:alice/dotfiles.git

Step 1: Check protocol prefix
  Starts with "git@" → MATCH!
  Result: provider = "git" ✓

Final: Git repository (definitive)
```

### Case 2: S3 URI

```
Input: s3://my-backups/documents

Step 1: Check protocol prefix
  Starts with "s3://" → MATCH!
  Result: provider = "s3" ✓

Final: S3 repository (definitive)
```

### Case 3: Git HTTPS (GitHub)

```
Input: https://github.com/alice/blog

Step 1: Check protocol prefix
  Starts with "https://" → No specific match (generic protocol)
  Continue to Step 2

Step 2: Check hostname
  Contains "github.com" → MATCH!
  Result: provider = "git" ✓

Final: Git repository (strong confidence)
```

### Case 4: AWS S3 Regional

```
Input: https://bucket.s3.us-west-2.amazonaws.com/documents

Step 1: Check protocol prefix
  Starts with "https://" → No specific match (generic protocol)
  Continue to Step 2

Step 2: Check hostname
  Contains "s3.us-west-2.amazonaws.com" → MATCH!
  Result: provider = "s3" ✓

Final: S3 repository (strong confidence)
```

### Case 5: DigitalOcean Spaces

```
Input: https://my-space.nyc3.digitaloceanspaces.com/media

Step 1: Check protocol prefix
  Starts with "https://" → No specific match (generic protocol)
  Continue to Step 2

Step 2: Check hostname
  Contains ".digitaloceanspaces.com" → MATCH!
  Result: provider = "s3" ✓  (S3-compatible)

Final: S3 repository (strong confidence)
```

### Case 6: Proton Drive Share Link

```
Input: https://drive.proton.me/urls/share-abc123

Step 1: Check protocol prefix
  Starts with "https://" → No specific match (generic protocol)
  Continue to Step 2

Step 2: Check hostname
  Contains "drive.proton.me/urls" → MATCH!
  Result: provider = "proton-drive" ✓

Final: Proton Drive repository (strong confidence)
```

### Case 7: Ambiguous Custom Server (REQUIRES EXPLICIT PROVIDER)

```
Input: https://internal-git.company.com/alice/project

Step 1: Check protocol prefix
  Starts with "https://" → No specific match (generic protocol)
  Continue to Step 2

Step 2: Check hostname
  No known pattern match for "internal-git.company.com"
  Continue to Step 3

Step 3: Check path characteristics
  No ".git" suffix
  No clear bucket/key structure
  Insufficient signal

Step 4: Unknown provider
  Result: provider = null (unknown)
  Action: REQUIRE EXPLICIT PROVIDER

Error: Cannot auto-detect provider for URL:
  https://internal-git.company.com/alice/project
  Please specify provider field: provider = "git"

User must specify:
{
  url = "https://internal-git.company.com/alice/project";
  provider = "git";  # or "s3"
}
```

### Case 8: MinIO Self-Hosted (REQUIRES EXPLICIT PROVIDER)

```
Input: http://minio.local:9000/my-bucket/documents

Step 1: Check protocol prefix
  Starts with "http://" → No specific match (generic protocol)
  Continue to Step 2

Step 2: Check hostname
  No AWS/DigitalOcean/Backblaze/Wasabi patterns match
  Continue to Step 3

Step 3: Check path characteristics
  Has bucket/key-like structure (weak signal)
  Port 9000 typical for MinIO (external knowledge, not detected)

Step 4: Unknown provider
  Result: provider = null (unknown)
  Action: REQUIRE EXPLICIT PROVIDER

User must specify:
{
  url = "http://minio.local:9000/my-bucket/documents";
  provider = "s3";  # MinIO is S3-compatible
}
```

## Nix Implementation Pseudocode

```nix
# Simplified logic showing detection algorithm

detectProvider = url:
  # Protocol-based detection (Step 1)
  if hasPrefix "s3://" url then "s3"
  else if hasPrefix "git@" url then "git"
  else if hasPrefix "ssh://" url then "git"
  else if hasPrefix "git://" url then "git"
  else if hasPrefix "file://" url then "git"
  else if hasPrefix "/" url then "git"  # Absolute path
  
  # Hostname-based detection (Step 2) for HTTPS/HTTP URLs
  else if hasPrefix "https://" url || hasPrefix "http://" url then
    if hasInfix "github.com" url then "git"
    else if hasInfix "gitlab.com" url then "git"
    else if hasInfix "bitbucket.org" url then "git"
    else if hasInfix ".s3.amazonaws.com" url then "s3"
    else if hasInfix ".s3-" url && hasInfix ".amazonaws.com" url then "s3"
    else if hasInfix "s3.amazonaws.com" url then "s3"
    else if hasInfix ".digitaloceanspaces.com" url then "s3"
    else if hasInfix ".backblazeb2.com" url then "s3"
    else if hasInfix ".wasabisys.com" url then "s3"
    else if hasInfix "drive.proton.me" url && hasInfix "/urls" url then "proton-drive"
    
    # Path characteristics (Step 3) - weak signals
    else if hasSuffix ".git" url then "git"
    else null  # Step 4: Unknown, require explicit provider
  
  else null;  # Default: unknown
```

## Decision Flowchart for Ambiguous Cases

```
Provider Type Must Be Determined For:
│
├─ Starts with https:// or http://
│  └─ Hostname does NOT match known patterns
│     ├─ Is this your own git server?
│     │  └─ Set: provider = "git"
│     │
│     ├─ Is this a S3-compatible storage (MinIO, Wasabi, etc.)?
│     │  └─ Set: provider = "s3"
│     │
│     └─ Not sure?
│        └─ Check common examples:
│           • Internal git server → provider = "git"
│           • Self-hosted MinIO/S3 → provider = "s3"
│           • Custom API → Not currently supported
│
└─ Custom or unknown protocol
   └─ Must use explicit provider = "..."
```

## Edge Cases and Resolution

### Case: Git URL with Port Number

```
URL: ssh://git@github.com:22/user/repo.git
Status: Ambiguous (ssh:// matches git, but unusual format)
Resolution: Works with explicit provider = "git"
```

### Case: HTTPS URL with Credentials

```
URL: https://username:password@github.com/user/repo.git
Status: Detected as Git (contains github.com)
Risk: Credentials exposed in config
Recommendation: Use SSH keys via secrets, not credentials in URL
```

### Case: S3 with Virtual-Hosted and Older Format

```
URL: https://bucket.s3-us-west-2.amazonaws.com/key
Status: Detected as S3 (contains s3-*.amazonaws.com)
Compatibility: Works with modern AWS CLI (auto-translates format)
```

### Case: Proton Drive Share Link with Expiration

```
URL: https://drive.proton.me/urls/share-token?exp=2026-02-01
Status: Detected as Proton Drive (contains drive.proton.me/urls)
Behavior: Sync fails if link is expired (user must update config)
```

## Validation Rules

### Rule 1: Protocol Prefix Takes Absolute Precedence

```nix
# Even if hostname suggests otherwise
url = "git@s3-bucket-style-host.com:repo.git";
# Detected as: git (because of git@ prefix)
# NOT detected as: s3
```

### Rule 2: Known Hostname Overrides Weak Path Signals

```nix
url = "https://github.com/some-bucket/some-key";
# Detected as: git (because of github.com)
# NOT detected as: s3 (even though path looks like bucket/key)
```

### Rule 3: Unknown Patterns Require Explicit Provider

```nix
url = "https://custom-server.company.com/internal/repo";
# Detected as: null (unknown)
# Must provide: provider = "git" or "s3"
```

### Rule 4: Explicit Provider Overrides Everything

```nix
{
  url = "https://github.com/user/repo";
  provider = "s3";  # Forced, despite github.com detection
}
# Detected as: s3 (because explicit)
# Note: This would likely fail at runtime, but detection respects it
```

## Performance Characteristics

**Detection Time**: O(1) constant time

- Simple string prefix/substring checks
- No network calls
- No file I/O
- Runs at Nix evaluation time (during `nix flake check`)

**Memory Usage**: Negligible

- Single string input
- Small return value (provider type)

**Scalability**: Linear with number of repositories

- Each repository URL detected independently
- No cross-repository dependencies
- Parallelizable (though not currently)

## Testing Strategy

### Unit Tests

```nix
test = {
  # Git URLs
  gitSSH = detectProvider "git@github.com:user/repo.git" == "git";
  gitHTTPS = detectProvider "https://github.com/user/repo" == "git";
  gitGitlab = detectProvider "https://gitlab.com/org/repo.git" == "git";
  gitLocal = detectProvider "/local/repo" == "git";
  
  # S3 URLs
  s3URI = detectProvider "s3://bucket/path" == "s3";
  s3AWS = detectProvider "https://bucket.s3.amazonaws.com" == "s3";
  s3Regional = detectProvider "https://bucket.s3.us-west-2.amazonaws.com" == "s3";
  s3DO = detectProvider "https://space.nyc3.digitaloceanspaces.com" == "s3";
  
  # Proton Drive
  proton = detectProvider "https://drive.proton.me/urls/token" == "proton-drive";
  
  # Ambiguous (should return null)
  ambiguous1 = detectProvider "https://custom.internal.com/repo" == null;
  ambiguous2 = detectProvider "http://minio:9000/bucket" == null;
};
```

### Integration Tests

- Configure repositories with mixed providers
- Run `nix flake check` → validates all URLs
- Run `just install <user> <host>` → tests activation
- Verify git repos cloned, S3 buckets synced, Proton folders synced

## References and Documentation

- **URL-PATTERN-DETECTION.md** - Detailed pattern reference with regex
- **IMPLEMENTATION-EXAMPLES.md** - Concrete code examples
- **research.md** - Research findings and design decisions
- **spec.md** - Feature specification and requirements

## Summary

The detection algorithm uses a **priority-based approach** with **4 detection stages**, falling back to explicit provider declaration when auto-detection is ambiguous. This provides:

✓ **Ease of use**: Common URLs auto-detected without configuration\
✓ **Safety**: Ambiguous cases require explicit provider (prevents misdetection)\
✓ **Extensibility**: New providers can be added by extending detection logic\
✓ **Performance**: O(1) detection, runs at evaluation time\
✓ **Debuggability**: Clear error messages guide users when detection fails
