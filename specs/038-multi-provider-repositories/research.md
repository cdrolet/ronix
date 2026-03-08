# Research: Multi-Provider Repository Support - URL Pattern Detection

**Feature**: 038-multi-provider-repositories\
**Date**: 2026-01-04\
**Status**: Complete\
**Focus**: URL pattern detection for automatic provider identification

## Overview

This document captures research findings and design decisions for implementing URL pattern detection to automatically identify repository providers (git, S3, Proton Drive, etc.) in the user.repositories configuration. The system should detect provider type from URL/URI patterns and allow explicit override when needed.

## Key Research Areas

### 1. Git URL Patterns and Detection

#### Standard Git URL Formats

**HTTPS Formats:**

- `https://github.com/username/repository.git`
- `https://github.com/username/repository` (without .git suffix - optional)
- `https://gitlab.com/your-org/repository.git`
- `https://gitlab.com/your-org/repository`
- `https://bitbucket.org/your-team/repository.git`
- `https://bitbucket.org/your-team/repository`
- `https://custom-git-host.com/path/to/repo.git`

**SSH Formats:**

- `git@github.com:username/repository.git`
- `git@github.com:username/repository`
- `git@gitlab.com:your-org/repository.git`
- `git@bitbucket.org:your-team/repository.git`
- `ssh://git@github.com:22/username/repository.git` (less common)
- `ssh://git@bitbucket.org/your-team/repository` (explicit SSH)

**Git Protocol (Legacy):**

- `git://github.com/username/repository.git`
- `git://git.example.com/path/to/repo`

**File Protocol (Local):**

- `file:///path/to/local/repo.git`
- `/path/to/local/repo.git` (bare path)

#### .git Suffix Behavior

**Key Finding**: The `.git` suffix is **optional** but conventional.

- Git accepts URLs both with and without `.git`
- Convention: use `.git` for bare repositories and clone URLs
- Most platforms (GitHub, GitLab, Gitea) include `.git` in their URLs
- Local clones are typically directories without `.git` suffix
- Repository name extraction should handle both cases

**Detection Strategy**: Do NOT require `.git` suffix. Accept both formats equally.

#### Git URL Detection Patterns

**Regex Pattern - Comprehensive:**

```regex
^((https?|git|ssh|file)?(:\/\/)?)([a-zA-Z0-9._-]+@)?([a-zA-Z0-9._-]+)(:[0-9]+)?(\/|:)([a-zA-Z0-9._\/-]+?)(\/?\.git)?(\/)?$
```

**Simplified Detection Logic (Priority Order):**

1. Starts with `git@` → SSH format
1. Starts with `ssh://` → SSH protocol
1. Starts with `https://` or `http://` → HTTPS format
1. Starts with `git://` → Git protocol
1. Starts with `file://` or is absolute path `/` → File protocol
1. Contains `github.com`, `gitlab.com`, `bitbucket.org`, or similar hosts → Git

**Special Cases:**

- SSH format: `git@HOST:PATH/TO/REPO` or `git@HOST:PATH/TO/REPO.git`
- Path-style file URLs with line endings or comment markers (should validate)
- URLs with authentication: `https://user:pass@github.com/repo.git` (may contain secrets - warn user)
- Custom git hosts with non-standard domains

#### Repository Name Extraction

**Logic:**

1. Remove trailing `.git` if present
1. Split by `/`
1. Take last segment
1. This is the repository name (used for default clone path)

**Examples:**

- `git@github.com:user/my-repo.git` → `my-repo`
- `https://github.com/user/my-repo` → `my-repo`
- `https://gitlab.com/org/group/project.git` → `project`
- `/Users/local/my-repo` → `my-repo`

### 2. S3 URL and URI Patterns

#### Standard S3 URI Formats

**S3 URI (Native Format):**

- `s3://bucket-name/key-path`
- `s3://bucket-name/path/to/object.zip`

**Path-Style URLs:**

- `https://s3.amazonaws.com/bucket-name/key` (legacy, US East N. Virginia only)
- `https://s3.us-west-2.amazonaws.com/bucket-name/key` (regional)
- `https://s3-us-west-2.amazonaws.com/bucket-name/key` (older format with dash)

**Virtual-Hosted-Style URLs:**

- `https://bucket-name.s3.amazonaws.com/key`
- `https://bucket-name.s3.us-west-2.amazonaws.com/key` (regional)
- `https://bucket-name.s3-us-west-2.amazonaws.com/key` (older format)

**S3 Website Endpoints:**

- `http://bucket-name.s3-website-us-west-2.amazonaws.com` (older format)
- `http://bucket-name.s3-website.us-west-2.amazonaws.com` (current format)

#### S3-Compatible Services

**DigitalOcean Spaces:**

- `https://my-space.nyc3.digitaloceanspaces.com/object-name`
- `https://nyc3.digitaloceanspaces.com/my-space/object-name`
- Endpoint: `${REGION}.digitaloceanspaces.com`
- Supported regions: nyc3, sfo3, sgp1, ams3, fra1, blr1

**MinIO (Self-Hosted):**

- `http://127.0.0.1:9000/bucket-name/key`
- `http://minio-server:9000/bucket-name/key`
- Configurable endpoint, default port 9000
- Supports both path-style and virtual-hosted-style

**Backblaze B2:**

- `s3://bucket-name/key` (S3-compatible API)
- Endpoint: `s3.backblazeb2.com` or `s3.us-west-001.backblazeb2.com`

**Wasabi (Hot Cloud Storage):**

- `s3://bucket-name/key`
- `https://bucket-name.s3.wasabisys.com/key`
- Regional endpoints vary

#### S3 URL Detection Strategy

**Key Characteristics:**

- Starts with `s3://` → Definitive S3 URI
- Hostname contains `s3.amazonaws.com` or `s3-*.amazonaws.com` → AWS S3
- Hostname ends with `digitaloceanspaces.com` → DigitalOcean Spaces
- Hostname contains `backblazeb2.com` → Backblaze B2
- Hostname contains `wasabisys.com` → Wasabi
- Hostname is custom/local with s3cmd or boto3 config → MinIO or custom S3-compatible

**Detection Pattern:**

```regex
^s3://[a-zA-Z0-9._-]+(/.*)?$
```

**Extended Pattern for HTTP(S) URLs:**

```regex
^https?://[a-zA-Z0-9._-]*\.?s3[.-]([a-zA-Z0-9-]*\.)?amazonaws\.com.*
^https?://[a-zA-Z0-9._-]*\.?digitaloceanspaces\.com.*
^https?://[a-zA-Z0-9._-]*\.?backblazeb2\.com.*
^https?://[a-zA-Z0-9._-]*\.?wasabisys\.com.*
```

#### S3 Authentication and Credentials

**Credential Methods:**

1. AWS credentials in `~/.aws/credentials` (default for AWS CLI, boto3)
1. Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
1. IAM roles (EC2, ECS, Lambda)
1. Secrets via agenix: `sshKeys.s3` containing AWS key pair or access token
1. Service-specific tokens (B2, Wasabi, DO Spaces)

**Integration Pattern:**

```nix
user.sshKeys = {
  # AWS credentials (key format: "AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
  s3 = "<secret>";
  
  # Or region-specific for multiple AWS accounts
  s3-prod = "<secret>";
  s3-dev = "<secret>";
};
```

### 3. Proton Drive URL Patterns

#### Proton Drive Share Link Formats

**Web Share Links:**

- Share links are generated by Proton Drive with unique tokens
- Format: `https://drive.proton.me/urls/XXXXXXXXXXXX` (observed pattern)
- Links can include password protection (password not in URL)
- Links can have expiration dates

**Security Model:**

- URL contains token/key for accessing encrypted content
- Password is either:
  - Randomly generated by client (can be included in URL)
  - User-specified (must be communicated separately)
- Password not stored on Proton servers when randomly generated
- Entire payload encrypted, only decryptable with correct password

**API Endpoint:**

- Base API: `https://mail.protonmail.com/api`
- Session-based authentication required
- No public S3-like protocol for generic file access

#### Proton Drive Detection Challenges

**Current Limitations:**

1. No standardized `proton-drive://` protocol specification
1. Share links are custom tokens, not predictable format
1. No published API documentation from Proton
1. All access goes through web browser or proprietary client

**Detection Strategies:**

1. **URL Pattern Match:**

   - `https://drive.proton.me/urls/` prefix
   - Custom `proton-drive://` protocol (user-specified, not standard)

1. **Explicit Provider Declaration:**

   - User must specify `provider = "proton-drive"` in config
   - URL can be share link or folder identifier
   - Credentials via `user.sshKeys.protonDrive` or `user.credentials.protonDrive`

1. **Authentication:**

   - Proton Drive credentials (email + password or session token)
   - ProtonMail API authentication
   - Third-party CLI tools (rclone, Proton SDK)

#### Proton Drive Tooling Options

**Available Tools:**

1. **rclone** (recommended for automation)

   - Supports Proton Drive as storage backend
   - Configuration via rclone config or environment variables
   - Can sync/copy files in activation scripts
   - Well-tested in Linux/macOS environments

1. **Proton Drive SDK** (C# and JavaScript)

   - Developing, not production-ready yet
   - Supports basic operations (upload, download, rename, move, delete)
   - End-to-end encryption built-in

1. **ProtonMail API Bridge** (third-party, community-maintained)

   - Reverse-engineered API implementation
   - May break with Proton updates

**Recommended Approach:** Use rclone as provider handler.

```bash
# Example rclone sync command
rclone sync --update proton-drive:shared-folder ~/shared-docs
```

### 4. Detection Algorithm and Priority Order

#### Challenge: Handling Ambiguous URLs

**Ambiguous Cases:**

- Custom domain URLs could be git or S3-compatible
- HTTPS URLs need deep inspection to disambiguate
- URL path structure varies by provider

#### Recommended Detection Order

**Priority (Most Specific to Least Specific):**

1. **Protocol-Based (Strongest Signal):**

   - `s3://` → S3 (unambiguous)
   - `git://` → Git
   - `git@` → SSH Git (unambiguous)
   - `proton-drive://` → Proton Drive (if user specifies)
   - `file://` → Local file path

1. **Hostname-Based (Strong Signal):**

   - `github.com`, `gitlab.com`, `bitbucket.org` → Git
   - `s3.amazonaws.com`, `s3-*.amazonaws.com` → AWS S3
   - `.digitaloceanspaces.com` → DigitalOcean Spaces
   - `.backblazeb2.com` → Backblaze B2
   - `.wasabisys.com` → Wasabi
   - `.s3.wasabisys.com` → Wasabi S3
   - `minio.example.com` or custom → Could be MinIO (ambiguous)

1. **Path Structure (Weak Signal):**

   - Contains `.git` suffix → Git
   - Has git-like path structure → Git
   - Bucket/key structure → S3

1. **Explicit Override (Final):**

   - `provider = "git"` / `provider = "s3"` / `provider = "proton-drive"` → Use as specified

#### Default Behavior for Ambiguous URLs

**Strategy:**

- **Conservative Approach**: Require explicit `provider` field for ambiguous URLs
- **User Guidance**: Document common patterns and examples
- **Error Messages**: Clear indication when provider cannot be auto-detected

**Example Configuration:**

```nix
repositories = [
  # Unambiguous - auto-detected as git
  "git@github.com:user/repo.git"
  
  # Unambiguous - auto-detected as S3
  "s3://my-bucket/data"
  
  # Ambiguous - requires explicit provider
  {
    url = "https://custom-server.com/data";
    provider = "s3";  # Or "git" or "proton-drive"
  }
];
```

### 5. Fallback and Error Handling

#### When Auto-Detection Fails

**Strategy:**

1. Try to detect based on protocol and hostname
1. If detection uncertain, require explicit `provider` field
1. Validate that detected/explicit provider can handle the URL format
1. Log clear error during evaluation (at `nix flake check` time, not activation)

#### Validation Requirements

**Per Provider:**

**Git:**

- Must be git-compatible URL (HTTPS, SSH, git://, file://)
- Optional: can validate remote accessibility via `git ls-remote` (expensive, skip)

**S3:**

- Must be `s3://` URI OR valid S3 HTTP(S) URL
- Bucket name validation: alphanumeric + hyphens, 3-63 chars
- Key path validation: must be present or default to root

**Proton Drive:**

- Must be share link URL or user-specified format
- Requires explicit `provider = "proton-drive"`
- Credentials must be configured via `sshKeys` or `credentials`

### 6. Repository Schema Extension

#### Current Schema (Feature 032)

```nix
# Per-repo specification
{
  url = "git@github.com:user/repo.git";
  path = "~/projects/repo";  # Optional custom path
}

# Or simple string
"git@github.com:user/repo.git"
```

#### Proposed Extended Schema (Feature 038)

```nix
# Provider-agnostic repository definition
{
  url = "s3://bucket/prefix";  # or git URL or proton-drive link
  path = "~/data";  # Local destination path (all providers)
  provider = "s3";  # Optional: explicit provider (auto-detected if omitted)
  
  # Provider-specific options (optional, extensible)
  options = {
    # Git-specific
    branch = "main";
    depth = 1;  # Shallow clone
    submodules = true;
    
    # S3-specific
    region = "us-west-2";
    sync = "update";  # or "clone-once", "bidirectional"
    exclude = ["*.tmp" "*.log"];  # Patterns to exclude
    
    # Proton Drive-specific
    shared = true;  # Is this a shared folder?
    
    # Generic
    checkLocal = true;  # Check for local changes before update (git)
  };
  
  # Authentication reference (if needed)
  auth = {
    field = "sshKeys.git";  # Reference to secret field
    method = "env";  # or "file", "inline"
  };
}
```

#### Backward Compatibility

**Consideration**: Feature 032 already defines `user.repositories` for git only.

**Strategy for Feature 038:**

- Migrate schema to provider-agnostic `user.repositories`
- Maintain backward compatibility: auto-detect provider as `git` if not specified
- Existing git-only configs continue to work
- New providers are opt-in via explicit `provider` field or auto-detection

#### Type Validation

```nix
# In user-schema.nix
user.repositories = lib.mkOption {
  type = lib.types.nullOr (lib.types.submodule {
    options = {
      rootPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
      };
      
      repos = lib.mkOption {
        type = lib.types.listOf (
          lib.types.either lib.types.str (lib.types.submodule {
            options = {
              url = lib.mkOption { type = lib.types.str; };
              path = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
              provider = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum ["git" "s3" "proton-drive"]);
                default = null;  # Auto-detect if null
              };
              options = lib.mkOption {
                type = lib.types.attrs;
                default = {};
              };
            };
          })
        );
      };
    };
  });
};
```

## Design Decisions

### Decision 1: Auto-Detection as Default

**Chosen**: Auto-detect provider type from URL pattern when `provider` field not specified.

**Rationale**:

- Reduces configuration verbosity for common cases
- Most users will use standard git URLs or S3 URIs
- Explicit override available for ambiguous/custom URLs
- Matches principle of convention-over-configuration

### Decision 2: Require Explicit Provider for Ambiguous URLs

**Chosen**: Require explicit `provider` field for URLs that don't match known patterns.

**Rationale**:

- Prevents misdetection of custom servers
- Clear error messages guide users
- Safer than guessing and failing at activation time
- Example: custom domain could be git or S3-compatible

### Decision 3: .git Suffix Optional

**Chosen**: Accept git URLs both with and without `.git` suffix.

**Rationale**:

- Git itself doesn't require `.git`
- Many git servers support both formats
- More flexible for user input
- Don't validate suffix presence/absence

### Decision 4: Provider Handlers Filter by Type

**Chosen**: Each provider handler (git-repos.nix, s3-repos.nix, proton-drive-repos.nix) filters repositories by provider type at activation time.

**Rationale**:

- Single repository schema for all providers
- Handlers are independent, can be implemented separately
- Easy to add new providers without changing core logic
- Clear separation of concerns

**Implementation**:

```bash
# In git-repos activation script
# Only process repositories with provider="git" or auto-detected as git
filtered_repos=$(jq '.repos[] | select(.provider == "git" or (.provider == null and ..detected_as_git))' <<< "$repos")
```

### Decision 5: Activation Ordering

**Chosen**: Provider handlers run in sequence during home-manager activation, after `writeBoundary` and credential deployment (`agenixInstall`).

**Rationale**:

- Ensures all credentials available before sync
- Proven pattern from Feature 030 (font repos)
- Non-blocking failures per provider
- Clear ordering prevents race conditions

## Technical Constraints

### 1. URL Parsing in Nix

**Constraint**: Nix is a functional language without native URL parsing libraries.

**Solution**:

- Use string operations (lib.splitString, lib.hasPrefix, etc.)
- Implement detection in Nix (evaluation time)
- Keep regex patterns simple and maintainable

### 2. Provider Tool Availability

**Constraint**: Each provider needs specific tools (git, aws-cli/s3cmd, rclone, etc.).

**Solution**:

- Include tools in nixpkgs inputs
- Make tool installation optional per provider
- Graceful skip if tool not available
- Document tool requirements per provider

### 3. Authentication Complexity

**Constraint**: Different providers have different auth models (SSH keys, API tokens, passwords, sessions).

**Solution**:

- Unify under `user.sshKeys.*` and `user.credentials.*` (future)
- Each provider handler knows how to use its auth method
- agenix integration for secret storage
- Environment variable injection during activation

### 4. Proton Drive Limitations

**Constraint**: No standard protocol, reverse-engineered API, unofficial SDKs.

**Solution**:

- Use rclone as abstraction layer (stable, well-maintained)
- Require explicit `provider = "proton-drive"`
- Document that this is less stable than git/S3
- Could upgrade to official API if Proton releases one

## Integration Points

### 1. User Schema Update

**Location**: `user/shared/lib/user-schema.nix`

Add provider-agnostic `user.repositories` section:

```nix
user.repositories = lib.mkOption {
  # Extended schema with provider field
};
```

### 2. Provider Detection Library

**Location**: `system/shared/lib/provider-detection.nix` (NEW)

```nix
{lib}: {
  # Detect provider from URL
  detectProvider = url: { ... };
  
  # Validate provider-specific URL format
  validateUrl = provider: url: { ... };
  
  # Extract bucket/path info
  parseS3Uri = uri: { ... };
}
```

### 3. Provider Handlers

**Locations**:

- `system/shared/settings/git-repos.nix` (MODIFIED)
- `system/shared/settings/s3-repos.nix` (NEW)
- `system/shared/settings/proton-drive-repos.nix` (NEW)

Each handler:

1. Filters repositories by provider type
1. Validates configuration
1. Generates activation script
1. Handles auth/credentials
1. Logs progress and errors

### 4. Home Manager Integration

All provider handlers use identical activation pattern:

```nix
home.activation.<provider>Repos = lib.mkIf (hasRepos && hasRelevantTool) (
  lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"] ''
    # Provider-specific sync logic
  ''
);
```

## Research References

### Git URL Patterns and Validation

- [How to validate git repository url - LabEx](https://labex.io/tutorials/git-how-to-validate-git-repository-url-434201)
- [Validate GIT Repository using Regular Expression - GeeksforGeeks](https://www.geeksforgeeks.org/dsa/validate-git-repository-using-regular-expression/)
- [GitHub is-git-url - Regex validation](https://github.com/jonschlinkert/is-git-url)
- [Git Clone Documentation - git-scm.com](https://git-scm.com/docs/git-clone)
- [Git Repository URL Suffix - Antora Docs](https://docs.antora.org/antora/latest/playbook/git-suffix/)

### S3 URL Patterns

- [Virtual hosting of general purpose buckets - AWS S3 Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html)
- [AWS S3 URL Styles](http://www.wryway.com/blog/aws-s3-url-styles/)
- [Format and Parse Amazon S3 URLs - AWS Builder](https://builder.aws.amazon.com/content/2biM1C0TkMkvJ2BLICiff8MKXS9/format-and-parse-amazon-s3-urls)
- [Website endpoints - AWS S3 Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html)

### S3-Compatible Services

- [DigitalOcean Spaces with AWS S3 SDKs](https://docs.digitalocean.com/products/spaces/how-to/use-aws-sdks/)
- [Spaces S3 Compatibility - DigitalOcean](https://docs.digitalocean.com/products/spaces/reference/s3-compatibility/)
- [Using DigitalOcean Spaces and MinIO - GitHub Discussions](https://github.com/taylorfinnell/awscr-s3/issues/14)
- [S3 Compatible Storage with MinIO - DigitalOcean Blog](https://deliciousbrains.com/s3-compatible-storage-provider-minio/)

### Proton Drive

- [How to create a shareable link in Proton Drive - Proton Support](https://proton.me/support/drive-shareable-link)
- [Proton Drive rclone integration](https://rclone.org/protondrive/)
- [Proton Drive SDK preview - Proton Blog](https://proton.me/blog/proton-drive-sdk-preview)
- [The Proton Drive security model - Proton Blog](https://proton.me/blog/protondrive-security)
- [Proton Drive GitHub](https://github.com/ProtonMail/proton-drive)

### URL Pattern Matching Algorithms

- [Rules matching algorithm - Algolia](https://www.algolia.com/doc/guides/managing-results/rules/rules-overview/in-depth/rule-matching-algorithm)
- [Multi-pattern hash-binary hybrid URL matching - PLOS One](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0175500)
- [Types of URL patterns and priority - Hitachi Documentation](https://itpfdoc.hitachi.co.jp/manuals/3020/30203Y0510e/EY050165.HTM)
- [URL Pattern Standard - WHATWG](https://urlpattern.spec.whatwg.org/)

## Next Steps

1. **Phase 1**: Define extended repository schema in contracts/
1. **Phase 1**: Implement provider detection library
1. **Phase 2**: Refactor git-repos.nix to use detection and filtering
1. **Phase 2**: Implement s3-repos.nix provider handler
1. **Phase 3**: Implement proton-drive-repos.nix provider handler
1. **Phase 3**: Update user-schema.nix with new provider field
1. **Phase 4**: Integration testing across all providers
1. **Phase 4**: Documentation and examples

## Open Questions

1. Should provider detection be case-insensitive? (Recommendation: yes)
1. Should we validate git URLs by attempting `git ls-remote`? (Recommendation: no, expensive)
1. Should S3 bucket names be validated for AWS compliance? (Recommendation: yes, simple validation)
1. Should we support git submodules? (Recommendation: yes, add to options)
1. Should bidirectional sync be supported for S3? (Recommendation: future enhancement, recommend sync direction)
1. What happens if user has both git and s3-repos configured with overlapping paths? (Recommendation: allow, user responsibility)
