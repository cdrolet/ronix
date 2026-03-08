# URL Pattern Detection Guide for Multi-Provider Repository Support

**Feature**: 038-multi-provider-repositories\
**Date**: 2026-01-04\
**Purpose**: Comprehensive reference for URL pattern matching, detection algorithms, and regex patterns

## Quick Reference: Provider Detection Algorithm

```
Input: URL string, Optional explicit provider type
↓
If explicit provider specified → Use it (skip detection)
↓
If starts with "s3://" → S3 (100% match)
If starts with "git@" → Git SSH (100% match)
If starts with "ssh://" → Git SSH (likely)
If starts with "git://" → Git protocol (100% match)
If starts with "file://" or is absolute path "/..." → Local Git
↓
If contains "github.com", "gitlab.com", "bitbucket.org" → Git (strong)
If contains "s3.amazonaws.com" or "s3-*.amazonaws.com" → AWS S3
If contains ".digitaloceanspaces.com" → DigitalOcean Spaces
If contains ".backblazeb2.com" → Backblaze B2
If contains ".wasabisys.com" → Wasabi (S3-compatible)
↓
If contains ".git" suffix → Likely Git (medium confidence)
If path looks like git repo (user/repo pattern) → Git (low confidence)
↓
Unknown → Require explicit provider field
Error: "Cannot auto-detect provider for URL: {url}. Please specify provider field."
```

## Provider Pattern Reference

### Git Repository URLs

#### Protocol-Based Detection (High Confidence)

| Format | Protocol | Confidence | Example |
|--------|----------|------------|---------|
| SSH format | `git@` prefix | 100% | `git@github.com:user/repo.git` |
| SSH protocol | `ssh://` prefix | 95% | `ssh://git@github.com/user/repo.git` |
| Git protocol | `git://` prefix | 100% | `git://github.com/user/repo.git` |
| File URL | `file://` or `/` prefix | 100% | `file:///path/to/repo.git` or `/local/repo` |
| HTTPS | `https://` + git host | 95% | `https://github.com/user/repo.git` |
| HTTP | `http://` + git host | 90% | `http://example.com/git/repo.git` |

#### Hostname-Based Detection (High Confidence)

| Hostname Pattern | Provider | Confidence | Examples |
|-----------------|----------|------------|----------|
| `github.com` | Git (GitHub) | 100% | `https://github.com/owner/repo` |
| `gitlab.com` | Git (GitLab) | 100% | `https://gitlab.com/owner/repo` |
| `bitbucket.org` | Git (Bitbucket) | 100% | `https://bitbucket.org/team/repo` |
| `*.dev` (git-focused) | Git (likely) | 85% | `https://gitea.example.dev/repo` |
| Contains "git" | Git (weak) | 70% | `https://internal-git.company.com/repo` |

#### Git URL Regex Patterns

**Comprehensive Pattern** (matches all common git formats):

```regex
^(git@|https?://|ssh://|git://|file://)([a-zA-Z0-9._-]+@)?([a-zA-Z0-9._-]+)(:[0-9]+)?(\/|:)(([a-zA-Z0-9._\/-]+?))(\.git)?(\/)?$
```

**SSH Format** (highest priority):

```regex
^git@[a-zA-Z0-9._-]+:[a-zA-Z0-9._/\-]+(\)?\.git)?/?$
```

**HTTPS/HTTP Format**:

```regex
^https?://[a-zA-Z0-9._-]+(/[a-zA-Z0-9._/\-]+)?(\)?\.git)?/?$
```

**Git Protocol**:

```regex
^git://[a-zA-Z0-9._-]+/[a-zA-Z0-9._/\-]+(\)?\.git)?/?$
```

**SSH Protocol**:

```regex
^ssh://[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:[0-9]+?/[a-zA-Z0-9._/\-]+(\)?\.git)?/?$
```

**File Protocol**:

```regex
^file:///[a-zA-Z0-9._/\-]+(\)?\.git)?/?$
```

#### Git Special Cases

| Case | Detection | Action |
|------|-----------|--------|
| `.git` suffix | Optional | Accept URLs both with and without `.git` |
| No protocol | Ambiguous | Could be local path or require explicit provider |
| Authentication in URL | `https://user:pass@host` | Valid but warn: credentials in URL are not secure |
| Relative path | `./repo` | Treat as local file (relative to home) |
| Tilde expansion | `~/path/to/repo` | Valid, bash expands during activation |

### S3 URLs and URIs

#### Protocol-Based Detection (Unambiguous)

| Format | Protocol | Confidence | Example |
|--------|----------|------------|---------|
| S3 URI | `s3://` prefix | 100% | `s3://my-bucket/path/to/data` |

#### AWS S3 Hostname Patterns

| Hostname Pattern | Format | Confidence | Examples |
|-----------------|--------|------------|----------|
| `.s3.amazonaws.com` | Virtual-hosted | 100% | `https://my-bucket.s3.amazonaws.com/key` |
| `.s3-*.amazonaws.com` | Virtual-hosted (regional, older) | 100% | `https://my-bucket.s3-us-west-2.amazonaws.com/key` |
| `s3.amazonaws.com` | Path-style (US East only) | 100% | `https://s3.amazonaws.com/my-bucket/key` |
| `s3.*.amazonaws.com` | Path-style (regional) | 100% | `https://s3.us-west-2.amazonaws.com/my-bucket/key` |
| `s3-*.amazonaws.com` | Path-style (regional, older) | 100% | `https://s3-us-west-2.amazonaws.com/my-bucket/key` |

#### S3-Compatible Service Patterns

| Service | Hostname Pattern | Examples | Confidence |
|---------|-----------------|----------|-----------|
| DigitalOcean Spaces | `.digitaloceanspaces.com` | `https://my-space.nyc3.digitaloceanspaces.com` | 100% |
| Backblaze B2 | `.backblazeb2.com` or `s3.backblazeb2.com` | `https://bucket.s3.backblazeb2.com` | 100% |
| Wasabi | `.s3.wasabisys.com` | `https://bucket.s3.wasabisys.com` | 100% |
| Hetzner | `.your-objectstorage.com` | `https://bucket.fsn1.your-objectstorage.com` | 100% |
| MinIO | Custom domain (self-hosted) | `http://minio.local:9000/bucket` | 5% (ambiguous) |

#### S3 URI Regex Patterns

**S3 URI (Native, Unambiguous)**:

```regex
^s3://[a-zA-Z0-9._-]+(\/[a-zA-Z0-9._\/-]*)?/?$
```

**AWS S3 Virtual-Hosted-Style**:

```regex
^https?://[a-zA-Z0-9._-]+\.s3[.-]([a-zA-Z0-9.-]*)\.?amazonaws\.com(\/[a-zA-Z0-9._\/-]*)?/?$
```

**AWS S3 Path-Style**:

```regex
^https?://s3[.-]([a-zA-Z0-9.-]*)\.?amazonaws\.com/[a-zA-Z0-9._-]+(\/[a-zA-Z0-9._\/-]*)?/?$
```

**DigitalOcean Spaces**:

```regex
^https?://[a-zA-Z0-9._-]+\.([a-zA-Z0-9]+)\.digitaloceanspaces\.com(\/[a-zA-Z0-9._\/-]*)?/?$
```

**Backblaze B2**:

```regex
^https?://[a-zA-Z0-9._-]+\.s3\.backblazeb2\.com(\/[a-zA-Z0-9._\/-]*)?/?$
```

**Wasabi**:

```regex
^https?://[a-zA-Z0-9._-]+\.s3\.wasabisys\.com(\/[a-zA-Z0-9._\/-]*)?/?$
```

**Hetzner Object Storage**:

```regex
^https?://[a-zA-Z0-9._-]+\.([a-zA-Z0-9]+)\.your-objectstorage\.com(\/[a-zA-Z0-9._\/-]*)?/?$
```

#### S3 Special Cases

| Case | Detection | Action |
|------|-----------|--------|
| No key/path | `s3://bucket` | Valid, defaults to bucket root |
| Region in URL | `s3.us-west-2.amazonaws.com` | Parse region from URL for appropriate endpoint |
| Legacy formats | `s3-us-west-2.amazonaws.com` | Still supported, translate to modern format |
| Website endpoints | `bucket.s3-website.region.amazonaws.com` | Not recommended for syncing, falls back to region-specific |
| Path confusion | Bucket vs key | Validate bucket name format (3-63 chars, alphanumeric + hyphens) |

### Proton Drive Share Links

#### Limitations

**Key Constraints:**

- No standardized URL protocol or format
- Share links contain unique tokens (not predictable)
- API access requires authentication (no anonymous bucket browsing like S3)
- Third-party tooling (rclone) recommended

#### Detection Strategy

| Method | Confidence | Action |
|--------|-----------|--------|
| Explicit `provider = "proton-drive"` | 100% | Use this, skip auto-detection |
| URL starts with `https://drive.proton.me/urls/` | 90% | Likely Proton Drive share link |
| URL starts with `proton-drive://` | 100% | Custom protocol, if user defines it |
| Any other Proton domain | 70% | Could be Proton Drive, require explicit provider |

#### Proton Drive URL Patterns

**Observed Share Link Format**:

```
https://drive.proton.me/urls/[TOKEN]
```

**Example with Password**:

```
https://drive.proton.me/urls/[TOKEN]#[PASSWORD_HASH]
```

**Custom Protocol** (user-defined, not standard):

```
proton-drive://[FOLDER_ID_OR_SHARE_LINK]
```

#### Proton Drive Regex Patterns

**Share Link Detection**:

```regex
^https://drive\.proton\.me/urls/[a-zA-Z0-9_-]+
```

**Custom Protocol** (optional, user-defined):

```regex
^proton-drive://[a-zA-Z0-9_/-]+
```

#### Proton Drive Special Cases

| Case | Detection | Action |
|------|-----------|--------|
| No URL prefix | `provider = "proton-drive"` required | URL can be any identifier, rclone resolves |
| Shared folder | Need folder ID/link | Sync via rclone path: `proton-drive:/folder-name` |
| Expired link | Detection at runtime | Sync fails gracefully, user corrects config |
| Password protected | Password in URL fragment | May not work, recommend user-provided password in rclone config |

## Implementation: Nix Detection Library

### Core Detection Function

```nix
{lib}: {
  # Auto-detect provider type from URL
  # Returns: "git" | "s3" | "proton-drive" | null (unknown)
  detectProvider = url:
    if builtins.isNull url || url == "" then null
    else if lib.hasPrefix "s3://" url then "s3"
    else if lib.hasPrefix "git@" url then "git"
    else if lib.hasPrefix "ssh://" url then "git"
    else if lib.hasPrefix "git://" url then "git"
    else if lib.hasPrefix "file://" url || lib.hasPrefix "/" url then "git"
    else if lib.hasPrefix "https://drive.proton.me/urls/" url then "proton-drive"
    else if lib.hasPrefix "proton-drive://" url then "proton-drive"
    else if lib.hasPrefix "https://" url || lib.hasPrefix "http://" url then
      # Check hostname patterns
      if lib.hasInfix "github.com" url then "git"
      else if lib.hasInfix "gitlab.com" url then "git"
      else if lib.hasInfix "bitbucket.org" url then "git"
      else if lib.hasInfix ".digitaloceanspaces.com" url then "s3"
      else if lib.hasInfix ".backblazeb2.com" url then "s3"
      else if lib.hasInfix ".wasabisys.com" url then "s3"
      else if lib.hasInfix ".your-objectstorage.com" url then "s3"
      else if lib.hasInfix ".amazonaws.com" url then "s3"
      else if lib.hasInfix ".s3" url && lib.hasInfix ".amazonaws.com" url then "s3"
      else if lib.hasSuffix ".git" url || lib.hasInfix "/.git/" url then "git"
      else null
    else null;

  # Validate URL format for a specific provider
  # Returns: { valid = bool; error = string | null; }
  validateUrl = provider: url: 
    if provider == "git" then
      # Basic validation: not empty, looks like a URL
      if url == "" then { valid = false; error = "Empty URL"; }
      else { valid = true; error = null; }
    else if provider == "s3" then
      if lib.hasPrefix "s3://" url then
        # Validate bucket name (first segment after s3://)
        let
          parts = lib.splitString "/" (lib.removePrefix "s3://" url);
          bucket = lib.head parts;
          bucketValid = 
            lib.stringLength bucket >= 3 &&
            lib.stringLength bucket <= 63 &&
            !(lib.hasInfix ".." bucket);
        in
        if bucketValid then { valid = true; error = null; }
        else { valid = false; error = "Invalid S3 bucket name: ${bucket}"; }
      else if lib.hasInfix ".amazonaws.com" url || 
              lib.hasInfix ".digitaloceanspaces.com" url ||
              lib.hasInfix ".wasabisys.com" url ||
              lib.hasInfix ".your-objectstorage.com" url ||
              lib.hasInfix ".backblazeb2.com" url then
        { valid = true; error = null; }
      else
        { valid = false; error = "Invalid S3 URL format"; }
    else if provider == "proton-drive" then
      # Accept any non-empty URL for Proton Drive (validation at runtime)
      if url == "" then { valid = false; error = "Empty Proton Drive URL"; }
      else { valid = true; error = null; }
    else
      { valid = false; error = "Unknown provider: ${provider}"; };

  # Extract repository name from URL
  # Used for default path generation
  repoName = url:
    if lib.hasPrefix "s3://" url then
      # S3: bucket is the name
      let
        parts = lib.splitString "/" (lib.removePrefix "s3://" url);
      in lib.head parts
    else
      # Git: last path segment
      let
        withoutGit = lib.removeSuffix ".git" url;
        parts = lib.splitString "/" withoutGit;
      in lib.last parts;

  # Parse S3 URI into components
  # Returns: { bucket = "..."; path = "..."; region = "..."; }
  parseS3Uri = uri:
    if lib.hasPrefix "s3://" uri then
      let
        withoutPrefix = lib.removePrefix "s3://" uri;
        parts = lib.splitString "/" withoutPrefix;
        bucket = lib.head parts;
        path = lib.concatStringsSep "/" (lib.tail parts);
      in {
        bucket = bucket;
        path = if path == "" then "/" else path;
        region = null;
      }
    else if lib.hasInfix ".s3." uri && lib.hasInfix ".amazonaws.com" uri then
      # Virtual-hosted or path-style, extract region
      let
        regionMatch = lib.elemAt (
          builtins.match ".*(s3[.-]([a-z0-9-]+)[.-]amazonaws)" uri
        ) 1;
      in {
        bucket = "unknown";  # Hard to extract reliably
        path = "/";
        region = if regionMatch != null then regionMatch else null;
      }
    else {
      bucket = null;
      path = null;
      region = null;
    };
}
```

### Usage Example

```nix
# In a provider handler or user config validation
let
  providerLib = import ./provider-detection.nix {inherit lib;};
  
  # Detect provider from URL
  detectedProvider = providerLib.detectProvider "s3://my-bucket/data";  # → "s3"
  
  # Validate configuration
  validation = providerLib.validateUrl "s3" "s3://my-bucket/data";  # → { valid = true; error = null; }
  
  # Get repo name for default path
  name = providerLib.repoName "git@github.com:user/my-repo.git";  # → "my-repo"
in
{ }
```

## Detection Priority Summary

### Most to Least Specific

1. **Explicit `provider` field** (highest priority)

   - User-specified provider overrides auto-detection
   - Use when URL is ambiguous

1. **Protocol prefix** (highest confidence)

   - `s3://` → S3
   - `git@` → Git SSH
   - `ssh://` → Git SSH
   - `git://` → Git protocol
   - `file://` or `/` → Local Git

1. **Known hostname** (high confidence)

   - GitHub, GitLab, Bitbucket → Git
   - `.digitaloceanspaces.com`, `.backblazeb2.com`, etc. → S3

1. **Path characteristics** (medium confidence)

   - `.git` suffix → Git
   - Bucket/key structure → S3

1. **Unknown** (lowest)

   - Require explicit `provider` field
   - Raise error during evaluation (`nix flake check`)

## Error Handling and User Guidance

### Ambiguous URL Detection

**When Auto-Detection Fails:**

```
Error: Cannot auto-detect provider type for URL:
  URL: https://internal-server.company.com/data

Please specify the provider type explicitly:
  
  {
    url = "https://internal-server.company.com/data";
    provider = "git";  # or "s3" or "proton-drive"
  }

Common patterns:
  - Git SSH: git@github.com:owner/repo.git
  - Git HTTPS: https://github.com/owner/repo.git
  - S3 URI: s3://bucket-name/path
  - S3 AWS: https://bucket-name.s3.amazonaws.com/path
```

### Known Limitations

1. **MinIO and custom S3-compatible**: Require explicit `provider = "s3"`
1. **Proton Drive**: Require explicit `provider = "proton-drive"` or URL starting with `https://drive.proton.me/urls/`
1. **Custom git servers without standard domains**: Require explicit `provider = "git"`
1. **Credentials in URLs**: Not recommended, use secrets instead

## Testing Patterns

### Git URL Test Cases

```nix
test.git = {
  case1 = providerLib.detectProvider "git@github.com:user/repo.git" == "git";
  case2 = providerLib.detectProvider "https://github.com/user/repo" == "git";
  case3 = providerLib.detectProvider "https://gitlab.com/org/repo.git" == "git";
  case4 = providerLib.detectProvider "ssh://git@example.com/repo" == "git";
  case5 = providerLib.detectProvider "git://github.com/user/repo.git" == "git";
  case6 = providerLib.detectProvider "/local/path/to/repo" == "git";
};
```

### S3 URL Test Cases

```nix
test.s3 = {
  case1 = providerLib.detectProvider "s3://my-bucket/data" == "s3";
  case2 = providerLib.detectProvider "https://my-bucket.s3.amazonaws.com/key" == "s3";
  case3 = providerLib.detectProvider "https://my-bucket.s3.us-west-2.amazonaws.com/key" == "s3";
  case4 = providerLib.detectProvider "https://my-space.nyc3.digitaloceanspaces.com" == "s3";
  case5 = providerLib.detectProvider "https://bucket.s3.backblazeb2.com" == "s3";
  case6 = providerLib.detectProvider "https://bucket.fsn1.your-objectstorage.com" == "s3";
  case7 = providerLib.detectProvider "https://bucket.nbg1.your-objectstorage.com/path" == "s3";
};
```

### Proton Drive Test Cases

```nix
test.protonDrive = {
  case1 = providerLib.detectProvider "https://drive.proton.me/urls/abc123" == "proton-drive";
  case2 = providerLib.detectProvider "proton-drive://shared-folder" == "proton-drive";
};
```

### Ambiguous URL Test Cases

```nix
test.ambiguous = {
  case1 = providerLib.detectProvider "https://custom-server.company.com/data" == null;  # Ambiguous
  case2 = providerLib.detectProvider "http://localhost:8080/minio" == null;  # Could be MinIO
  case3 = providerLib.detectProvider "https://my-service.io/files" == null;  # Unknown
};
```

## References

- [Git Clone Documentation](https://git-scm.com/docs/git-clone)
- [AWS S3 Virtual Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html)
- [DigitalOcean Spaces S3 Compatibility](https://docs.digitalocean.com/products/spaces/reference/s3-compatibility/)
- [Proton Drive Share Links](https://proton.me/support/drive-shareable-link)
- [rclone Proton Drive Backend](https://rclone.org/protondrive/)
