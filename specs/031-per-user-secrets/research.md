# Research: Per-User Secret Management

**Feature**: 031-per-user-secrets
**Date**: 2025-12-29
**Status**: Draft

## Executive Summary

This research evaluates transitioning from the current shared-key model (Feature 027) to per-user keypairs for enhanced security isolation. Key findings:

1. **Per-user keys provide security benefits** but add complexity
1. **Hybrid approach recommended**: Shared key by default, opt-in per-user keys for sensitive users
1. **User creation workflow** should handle both templating and key generation
1. **Git automation** should be interactive with user confirmation
1. **Backward compatibility** is achievable with gradual migration path

______________________________________________________________________

## Topic 1: Age Encryption - Per-User Keys vs Shared Key

### Decision: Hybrid Model (Shared by Default, Per-User Optional)

**Recommendation**: Keep shared key as default, add support for per-user keys as an opt-in security enhancement.

### Rationale

**Current Shared Key Model (Feature 027)**:

- ✅ Simple: One keypair for entire repository
- ✅ Easy distribution: Same key on all machines
- ✅ No registry needed: No central secrets.nix to maintain
- ❌ No per-user revocation: Must rotate all secrets if one user compromised
- ❌ All-or-nothing access: Anyone with key accesses everything

**Per-User Key Benefits**:

- ✅ Security isolation: Each user has separate encryption key
- ✅ Granular revocation: Revoke individual user without affecting others
- ✅ Audit trail: Know which key encrypted which secret
- ✅ Least privilege: Users only decrypt their own secrets

**Per-User Key Drawbacks**:

- ❌ Increased complexity: N keypairs to manage instead of 1
- ❌ Requires registry: Must track user→public key mapping
- ❌ More distribution overhead: Each user needs their specific private key
- ❌ Multi-machine complexity: Same user needs same key on multiple machines

### Industry Best Practices (2025)

Based on web research, current encryption key management trends indicate:

**From [Secure Key Management 2025](https://www.onlinehashcrack.com/guides/cryptography-algorithms/secure-key-management-2025-developer-best-practices.php)**:

- Manual shared key distribution using Key Encryption Keys (KEKs) is secure but labor-intensive and doesn't scale well
- For larger deployments, asymmetric key distribution techniques are more feasible
- Trend is moving toward per-user asymmetric key approaches for scalability

**From [age encryption documentation](https://github.com/FiloSottile/age)**:

- age supports multiple identities and multiple recipients
- Any single recipient can decrypt a file encrypted for multiple recipients
- age handles integrity and confidentiality, not authentication

**From [agenix documentation](https://github.com/ryantm/agenix)**:

- Agenix supports encrypting a secret for multiple SSH public keys
- Each secret can specify which public keys can decrypt it
- Home-manager module scopes secrets to individual users

### Recommended Hybrid Approach

```
# Default: Shared key (unchanged from Feature 027)
public.age                           # Shared public key at repo root
~/.config/agenix/key.txt             # Shared private key

user/
  cdrokar/
    secrets.age                      # Encrypted with shared key
  cdrolet/
    secrets.age                      # Encrypted with shared key

# Optional: Per-user keys (new in Feature 031)
user/
  cdronix/
    public.age                       # User-specific public key
    secrets.age                      # Encrypted with user's key ONLY
```

**Migration Path**:

1. Existing users continue with shared key (no breaking changes)
1. New users can opt into per-user keys during creation
1. Existing users can migrate to per-user keys on-demand
1. System checks for `user/{name}/public.age` first, falls back to repo root `public.age`

**Configuration Pattern**:

```nix
# In flake.nix or platform lib
getUserPublicKey = username:
  let
    userKey = ../user/${username}/public.age;
    sharedKey = ../public.age;
  in
    if builtins.pathExists userKey
    then builtins.readFile userKey
    else builtins.readFile sharedKey;
```

### Alternatives Considered

**Alternative 1: Full migration to per-user keys**

- ❌ Rejected: Breaking change for existing users
- ❌ Increases complexity for all users, even single-user repos
- ❌ No backward compatibility path

**Alternative 2: Keep shared key only**

- ❌ Rejected: Doesn't address security isolation requirements
- ❌ No revocation capabilities for multi-user scenarios
- ✅ But valid for single-user or trusted-team repositories

**Alternative 3: Always encrypt for all users**

- Each secret encrypted with all user keys
- ❌ Rejected: Requires maintaining user registry
- ❌ Adds/removes require re-encrypting all secrets
- ❌ Conflicts with "no central secrets.nix" design goal

### Trade-offs

| Aspect | Shared Key | Per-User Key | Hybrid |
|--------|-----------|--------------|--------|
| Setup complexity | Low | Medium | Medium |
| Key distribution | Simple | Complex | Flexible |
| Security isolation | None | Full | Opt-in |
| Revocation | None | Granular | Per-user |
| Maintenance burden | Low | High | Medium |
| Breaking changes | N/A | High | None |

### Implementation Considerations

**For justfile commands**:

- `secrets-init`: Create shared key (current behavior) OR per-user key (with --user flag)
- `secrets-set <user>`: Auto-detect which key to use based on file presence
- `secrets-migrate <user>`: Convert user from shared to per-user key

**For platform libs**:

- Update agenix registration to check for user-specific key first
- Fall back to shared key if user key not found
- No changes needed for apps (they reference `config.age.secrets.*` paths)

**For documentation**:

- Document when to use per-user keys (untrusted users, compliance, revocation needs)
- Provide migration guide for shared→per-user transition
- Document key backup and recovery procedures

______________________________________________________________________

## Topic 2: Key Management - Storage Patterns

### Decision: Per-User public.age in User Directories

**Recommendation**: Store per-user public keys as `user/{name}/public.age`, keep shared key at repo root.

### Rationale

**Per-User Key Location**:

```
user/
  cdrokar/
    default.nix
    secrets.age
    public.age        # User's public key (committed)
```

**Benefits**:

- ✅ Colocated with user config (consistent with Feature 027)
- ✅ Self-documenting: "This user has their own key"
- ✅ Easy discovery: Check if file exists
- ✅ No central registry needed

**Shared Key Location** (unchanged):

```
public.age            # Shared public key (repo root, committed)
```

**Private Key Location** (both models):

```
~/.config/agenix/key.txt     # Local machine, not committed
```

### Alternatives Considered

**Alternative 1: Central registry file**

```nix
# secrets/public-keys.nix
{
  cdrokar = "age1...";
  cdrolet = "age1...";
  cdronix = "age1...";
}
```

- ❌ Rejected: Violates "no central registry" design goal from Feature 027
- ❌ Requires editing central file for every user add/remove
- ❌ Merge conflicts when multiple people add users

**Alternative 2: Keys in .nix files**

```nix
# user/cdrokar/default.nix
{
  user = {
    publicKey = "age1...";  # Inline in user config
  };
}
```

- ❌ Rejected: Mixes configuration with key material
- ❌ Makes config files harder to read
- ✅ But could work for auto-generated user creation

**Alternative 3: Separate keys/ directory**

```
keys/
  cdrokar.age
  cdrolet.age
```

- ❌ Rejected: Creates parallel directory structure (same issue as old secrets/ design)
- ❌ Not colocated with user configs

### Trade-offs

| Aspect | Colocated (Recommended) | Central Registry | Inline Config |
|--------|------------------------|------------------|---------------|
| Discoverability | High | Medium | Low |
| Maintenance | Low | High | Low |
| Colocation | Yes | No | Yes |
| Registry needed | No | Yes | No |
| Merge conflicts | Rare | Common | Rare |

### Implementation Considerations

**Key Discovery Logic**:

```bash
# In justfile secrets commands
get_public_key() {
  local user=$1
  local user_key="user/$user/public.age"
  local shared_key="public.age"
  
  if [ -f "$user_key" ]; then
    cat "$user_key"
  elif [ -f "$shared_key" ]; then
    cat "$shared_key"
  else
    echo "Error: No public key found for $user"
    exit 1
  fi
}
```

**Nix Discovery**:

```nix
getUserPublicKey = username:
  let
    userKeyPath = ../user/${username}/public.age;
    sharedKeyPath = ../public.age;
  in
    if builtins.pathExists userKeyPath
    then builtins.readFile userKeyPath
    else if builtins.pathExists sharedKeyPath
    then builtins.readFile sharedKeyPath
    else throw "No public key found for user ${username}";
```

______________________________________________________________________

## Topic 3: User Creation Workflow

### Decision: Interactive Justfile Command with Templates

**Recommendation**: Add `just user-create <username>` that prompts for required fields, offers template selection, and optionally generates per-user keys.

### Rationale

**Interactive Creation Benefits**:

- ✅ Guides user through required fields (name, email)
- ✅ Prevents missing mandatory configuration
- ✅ Reduces errors vs manual file creation
- ✅ Consistent structure across all users

**Template System Benefits**:

- ✅ Quick start for common patterns (developer, minimal, full-featured)
- ✅ Reduces boilerplate duplication
- ✅ Demonstrates best practices to new users
- ✅ Optional: Users can still decline and create minimal config

### Recommended Workflow

```bash
just user-create <username>
```

**Interactive Prompts**:

1. Email address: (required, validates email format)
1. Full name: (optional, defaults to empty)
1. Use template? (yes/no, default: yes)
   - If yes: Select template (shared/minimal, shared/developer, shared/full)
   - If no: Create minimal config with just name/email
1. Use per-user encryption key? (yes/no, default: no - shared key)
   - If yes: Generate keypair, save to user/{name}/public.age
   - If no: Use shared key (public.age at repo root)
1. Save private key to SSH key repository? (yes/no, default: no)
   - If yes: Prompt for repository URL and commit
   - If no: Display private key and manual save instructions
1. Commit changes to git? (yes/no, default: yes)
   - If yes: Create commit with message "feat(user): add {username}"
   - If no: Leave changes staged for manual review

**Template Structure**:

```
user/shared/templates/
  minimal.nix          # Just name, email, applications = []
  developer.nix        # Common dev tools (git, zsh, helix)
  full.nix             # All available apps, extensive config
```

### Industry Best Practices

**From [Infrastructure as Code Workflow Automation](https://www.harness.io/harness-devops-academy/iac-workflow-automation)**:

- Modular code structure: Breaking definitions into reusable modules/templates
- Automation and CI/CD integration: Automating workflows for consistency
- Testing and validation: Checking for syntax errors early

**From [Nix Configuration Templates](https://github.com/Misterio77/nix-starter-configs)**:

- Templates ship with tutorials (README.md) explaining usage
- Simple, documented templates help newcomers learn Nix
- Templates demonstrate best practices and common patterns

### Template Example

```nix
# user/shared/templates/developer.nix
# Template: Developer workstation with common tools
# Created: 2025-12-29
#
# Usage: Copy to user/{username}/default.nix and customize
{...}: {
  user = {
    name = "REPLACE_USERNAME";
    email = "REPLACE_EMAIL";
    fullName = "REPLACE_FULLNAME";  # Optional
    
    # Locale defaults (customize as needed)
    languages = ["en-CA"];
    timezone = "America/Toronto";
    locale = "en_CA.UTF-8";
    
    # Common developer applications
    applications = [
      # Version control
      "git"
      
      # Shell
      "zsh"
      
      # Editor
      "helix"
      
      # Terminal
      "ghostty"
      
      # Add more apps as needed
    ];
    
    # Optional: Configure dock layout
    # docked = [
    #   "zed"
    #   "ghostty"
    #   "|"
    #   "/Downloads"
    # ];
    
    # Optional: Configure fonts
    # fonts = {
    #   defaults = {
    #     monospace = {
    #       families = ["Fira Code"];
    #       size = 12;
    #     };
    #   };
    # };
  };
}
```

### Alternatives Considered

**Alternative 1: Non-interactive command with flags**

```bash
just user-create myuser --email me@example.com --fullname "My Name" --template developer
```

- ❌ Rejected: Error-prone (missing flags), verbose
- ❌ Doesn't guide user through options
- ✅ Could work for CI/automation scenarios (add later if needed)

**Alternative 2: Manual file creation only**

- ❌ Rejected: Inconsistent user experience
- ❌ New users don't know what fields are required
- ❌ No validation until build time

**Alternative 3: Web-based configurator**

- ❌ Rejected: Over-engineered for this use case
- ❌ Adds external dependency
- ❌ CLI workflow preferred for Nix users

### Trade-offs

| Aspect | Interactive CLI | Flags-based | Manual | Web UI |
|--------|----------------|-------------|--------|--------|
| User guidance | High | Low | None | High |
| Automation | Medium | High | N/A | Low |
| Complexity | Medium | Low | None | High |
| Validation | Immediate | Immediate | Delayed | Immediate |
| Nix community fit | High | High | High | Low |

### Implementation Considerations

**Justfile recipe structure**:

```makefile
# Create a new user with interactive prompts
user-create username:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    USER_DIR="user/$USERNAME"
    
    # Validate username doesn't exist
    if [ -d "$USER_DIR" ]; then
      echo "Error: User $USERNAME already exists"
      exit 1
    fi
    
    # Prompt for email (required)
    read -p "Email address: " EMAIL
    # TODO: Validate email format
    
    # Prompt for full name (optional)
    read -p "Full name (optional): " FULLNAME
    
    # Prompt for template
    echo "Available templates:"
    echo "  1) minimal - Just name/email"
    echo "  2) developer - Common dev tools"
    echo "  3) full - All available apps"
    read -p "Use template? (1/2/3/n): " TEMPLATE_CHOICE
    
    # Prompt for encryption key type
    echo ""
    echo "Encryption key options:"
    echo "  shared - Use repository shared key (simpler)"
    echo "  per-user - Generate user-specific key (more secure)"
    read -p "Key type (shared/per-user) [shared]: " KEY_TYPE
    KEY_TYPE=${KEY_TYPE:-shared}
    
    # Create user directory and config
    mkdir -p "$USER_DIR"
    
    # Generate config from template
    # ... (template processing logic)
    
    # Generate per-user key if requested
    if [ "$KEY_TYPE" = "per-user" ]; then
      just secrets-init-user "$USERNAME"
    fi
    
    # Offer to commit
    read -p "Commit changes? (y/n) [y]: " COMMIT
    if [ "${COMMIT:-y}" = "y" ]; then
      git add "$USER_DIR"
      git commit -m "feat(user): add $USERNAME"
    fi
```

**Template processing**:

- Use `sed` or `envsubst` to replace placeholders
- Validate generated config with `nix flake check` before commit
- Optionally run formatter (`just fmt`) on generated file

**Key generation helper**:

```makefile
# Initialize per-user keypair (internal helper)
secrets-init-user username:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    USER_DIR="user/$USERNAME"
    PUBLIC_KEY_PATH="$USER_DIR/public.age"
    PRIVATE_KEY_PATH="$HOME/.config/agenix/key-$USERNAME.txt"
    
    # Generate keypair
    mkdir -p "$(dirname "$PRIVATE_KEY_PATH")"
    nix shell nixpkgs#age -c age-keygen -o "$PRIVATE_KEY_PATH" 2>&1 | \
      grep "Public key:" | cut -d: -f2 | tr -d ' ' > "$PUBLIC_KEY_PATH"
    
    echo "Generated per-user keypair:"
    echo "  Public:  $PUBLIC_KEY_PATH (commit this)"
    echo "  Private: $PRIVATE_KEY_PATH (keep secret)"
    echo ""
    echo "IMPORTANT: Save the private key somewhere safe!"
    echo "Copy to other machines that need to decrypt $USERNAME secrets."
```

______________________________________________________________________

## Topic 4: Default Configuration Templates

### Decision: Shared Templates with Placeholder Substitution

**Recommendation**: Store templates in `user/shared/templates/` with placeholder syntax for variable substitution.

### Rationale

**Colocated Templates**:

```
user/shared/
  lib/              # Existing user libraries
  templates/        # New: User config templates
    minimal.nix
    developer.nix
    full.nix
    README.md       # Template documentation
```

**Benefits**:

- ✅ Discoverable: Same location as other user shared code
- ✅ Versioned: Templates evolve with repository
- ✅ Self-documenting: Users can read templates directly
- ✅ No external dependency: Part of repository structure

**Placeholder Syntax**:

- Use `REPLACE_USERNAME`, `REPLACE_EMAIL`, `REPLACE_FULLNAME` markers
- Simple `sed` substitution during user creation
- Validate substitution completed (no REPLACE\_ markers remain)

### Template Types

**1. Common Template** (default):

- Name, email, locale defaults
- Essential apps: git, zsh
- Minimal configuration
- **Use case**: Most users, simple setup

**2. Developer Template**:

- Name, email, locale defaults
- Developer apps: git, zsh, helix, ghostty
- Dock layout and font configuration
- **Use case**: Software developers

### Alternatives Considered

**Alternative 1: Nix function generators**

```nix
# user/shared/lib/user-template.nix
{ name, email, fullName ? "", ... }:
{
  user = {
    inherit name email fullName;
    # ...
  };
}
```

- ❌ Rejected: Requires Nix knowledge to use
- ❌ Less transparent than static files
- ❌ Harder for beginners to customize
- ✅ But more type-safe (could add as advanced option)

**Alternative 2: JSON/YAML templates**

- ❌ Rejected: Nix-native syntax preferred
- ❌ Conversion complexity
- ❌ Loses Nix language features (comments, etc.)

**Alternative 3: No templates, manual creation**

- ❌ Rejected: Inconsistent results
- ❌ Users miss best practices
- ❌ No guided workflow

### Trade-offs

| Aspect | Static Templates | Nix Functions | No Templates |
|--------|-----------------|---------------|--------------|
| Ease of use | High | Medium | Low |
| Flexibility | Medium | High | High |
| Discoverability | High | Medium | N/A |
| Type safety | None | High | None |
| Beginner friendly | High | Low | Low |

### Implementation Considerations

**Template validation**:

```bash
# After substitution, validate template
validate_template() {
  local file=$1
  
  # Check no REPLACE_ markers remain
  if grep -q "REPLACE_" "$file"; then
    echo "Error: Template substitution incomplete"
    grep "REPLACE_" "$file"
    return 1
  fi
  
  # Validate Nix syntax
  nix-instantiate --parse "$file" > /dev/null
}
```

**Template selection logic**:

```bash
apply_template() {
  local template=$1
  local output=$2
  local username=$3
  local email=$4
  local fullname=$5
  
  cp "user/shared/templates/${template}.nix" "$output"
  
  sed -i "s/REPLACE_USERNAME/$username/g" "$output"
  sed -i "s/REPLACE_EMAIL/$email/g" "$output"
  sed -i "s/REPLACE_FULLNAME/$fullname/g" "$output"
  
  validate_template "$output"
}
```

**Documentation**:

```markdown
# user/shared/templates/README.md

# User Configuration Templates

Templates for creating new users quickly with best-practice defaults.

## Available Templates

### minimal.nix
- Just name and email fields
- Empty applications list
- Use when: You want full control from scratch

### developer.nix
- Common development tools (git, zsh, helix)
- Basic locale configuration
- Use when: Adding a software developer

### full.nix
- All available configuration options demonstrated
- Applications = ["*"] (everything enabled)
- Use when: Learning the system or power user setup

## Usage

Templates are used automatically by `just user-create <username>`.

For manual use:
1. Copy template to `user/<username>/default.nix`
2. Replace REPLACE_* placeholders with actual values
3. Customize as needed
```

______________________________________________________________________

## Topic 5: Git Workflow Automation

### Decision: Interactive Commit Prompt with Manual Push

**Recommendation**: Offer to commit after user creation, but always require manual push. No automatic push to main.

### Rationale

**Interactive Commit**:

- ✅ Convenient: User doesn't need to remember git commands
- ✅ Consistent: Standardized commit messages
- ✅ Safe: User can decline and review changes first
- ✅ Atomic: All user creation files committed together

**Manual Push Only**:

- ✅ Safety: User reviews commit before pushing
- ✅ Flexibility: Can amend, squash, or modify before push
- ✅ Branch awareness: User controls target branch
- ❌ Less automated, but more control

### Industry Best Practices

**From [Git Workflow Automation Best Practices](https://statamic.dev/git-automation)**:

- Automation should enhance code quality while maintaining efficiency
- Smart automation eliminates repetitive work and human mistakes
- Keep automation scripts simple and transparent

**From [Git Hooks Best Practices](https://devtoolhub.com/git-hooks-automate-workflow-examples/)**:

- Pre-commit hooks for validation, not deployment
- Keep hooks fast and focused
- Share hooks across teams for consistency
- Use hooks for validation, not automatic deployment

**From [Git Workflow Best Practices](https://articles.mergify.com/git-workflow-best-practices/)**:

- Clear commit messages following conventions
- Avoid automating pushes to main branch
- Use automation for repetitive tasks, not critical decisions

### Recommended Workflow

```bash
just user-create myuser
# ... interactive prompts ...

# After user creation:
Changes staged:
  user/myuser/default.nix
  user/myuser/public.age (if per-user key)

Commit message:
  feat(user): add myuser

Commit changes? (y/n) [y]: y
✓ Changes committed: a1b2c3d

Next steps:
  1. Review commit: git show HEAD
  2. Push when ready: git push origin main
```

**No automatic push because**:

- User might want to review the commit
- User might be working on a feature branch
- User might want to amend or squash commits
- Safer to be explicit about remote operations

### Alternatives Considered

**Alternative 1: Automatic commit + push**

```bash
# After creation, automatically:
git add user/myuser/
git commit -m "feat(user): add myuser"
git push origin main
```

- ❌ Rejected: Too aggressive, no review opportunity
- ❌ Assumes main branch is current and up-to-date
- ❌ Risk of pushing broken commits

**Alternative 2: No git automation**

```bash
# User must manually:
git add user/myuser/
git commit -m "..."
git push
```

- ❌ Rejected: Inconsistent commit messages
- ❌ User might forget to commit
- ❌ Misses opportunity for helpful automation

**Alternative 3: Git hooks for validation only**

- Pre-commit: Validate user config syntax
- Pre-push: Run tests
- ❌ Not alternative to commit automation, complementary
- ✅ Could add later for enhanced validation

### Trade-offs

| Aspect | Auto-commit + Manual Push | Auto-commit + Auto-push | No Automation |
|--------|---------------------------|-------------------------|---------------|
| Safety | High | Low | Medium |
| Convenience | High | Highest | Low |
| Control | High | Low | Highest |
| Error risk | Low | High | Medium |
| Best practice | Yes | No | Acceptable |

### Implementation Considerations

**Commit automation**:

```bash
# In user-create recipe
commit_changes() {
  local username=$1
  local files="$2"
  
  echo ""
  echo "Changes to commit:"
  git status --short $files
  
  echo ""
  echo "Commit message:"
  echo "  feat(user): add $username"
  echo ""
  
  read -p "Commit changes? (y/n) [y]: " COMMIT
  if [ "${COMMIT:-y}" = "y" ]; then
    git add $files
    git commit -m "feat(user): add $username"
    COMMIT_HASH=$(git rev-parse --short HEAD)
    echo "✓ Changes committed: $COMMIT_HASH"
    echo ""
    echo "Next steps:"
    echo "  1. Review: git show HEAD"
    echo "  2. Push when ready: git push origin main"
  else
    echo "Changes staged but not committed."
    echo "Review with: git diff --cached"
  fi
}
```

**Validation before commit**:

```bash
# Validate config builds before offering to commit
if ! nix flake check 2>/dev/null; then
  echo "Warning: Configuration has errors"
  nix flake check  # Show errors
  echo ""
  read -p "Commit anyway? (y/n) [n]: " FORCE_COMMIT
  [ "${FORCE_COMMIT:-n}" = "y" ] || return 1
fi
```

**Conventional commits**:

- Format: `feat(user): add {username}`
- Consistent with repository convention
- Enables changelog generation
- Clear intent in git history

______________________________________________________________________

## Topic 6: Security Implications

### Decision: Documented Security Model with Migration Guide

**Recommendation**: Clearly document security trade-offs for both models, provide migration tools, and default to shared key for simplicity.

### Security Comparison

**Shared Key Model** (Feature 027, Current):

| Security Aspect | Rating | Details |
|----------------|--------|---------|
| Encryption strength | High | Age encryption (ChaCha20-Poly1305) |
| Access control | None | Anyone with key accesses all secrets |
| Revocation capability | None | Must rotate key and re-encrypt all secrets |
| Audit trail | Low | Can't track who decrypted what |
| Compromise impact | High | All secrets exposed if key leaked |
| Key distribution | Simple | Same key on all machines |
| Appropriate for | Trusted users | Single person, family, close team |

**Per-User Key Model** (Feature 031, Proposed):

| Security Aspect | Rating | Details |
|----------------|--------|---------|
| Encryption strength | High | Same age encryption |
| Access control | Granular | Each user only decrypts their secrets |
| Revocation capability | Granular | Revoke individual user key |
| Audit trail | Medium | Know which key encrypted which file |
| Compromise impact | Low | Only one user's secrets exposed |
| Key distribution | Complex | Each user needs their specific key |
| Appropriate for | Untrusted users | Multi-tenant, compliance requirements |

### Threat Model Analysis

**Threats Mitigated by Per-User Keys**:

1. **Insider threat**: Malicious user can't access other users' secrets
1. **Key leakage**: Compromised key only exposes one user
1. **Privilege escalation**: User can't elevate to access others' credentials
1. **Compliance**: Audit requirements for secret access separation

**Threats NOT Mitigated**:

1. **Repository access**: Anyone with repo read access sees encrypted files
1. **Build-time exposure**: Secrets decrypted during activation are in memory
1. **Machine compromise**: Root on target machine can read decrypted secrets
1. **Side channels**: Timing attacks, memory dumps (general encryption limitations)

### Security Best Practices (2025)

**From [Encryption Best Practices 2025](https://trainingcamp.com/articles/encryption-best-practices-2025-complete-guide-to-data-protection-standards-and-implementation/)**:

- Key rotation: Rotate keys on fixed schedule (e.g., every 90 days)
- Key storage: Encrypt keys at rest using master key in HSM/KMS
- Access control: Restrict permissions using OS-level security
- Least privilege: Limit access rights to minimum necessary

**From [Cryptographic Key Lifecycle](https://www.cryptomathic.com/blog/exploring-the-lifecycle-of-a-cryptographic-key-)**:

- Generation: Use cryptographically secure random number generators
- Distribution: Secure channel for key transmission
- Storage: Protected storage with access controls
- Rotation: Regular rotation to limit exposure window
- Revocation: Capability to invalidate compromised keys
- Destruction: Secure deletion when key no longer needed

### Recommended Security Documentation

**For user-facing docs**:

```markdown
## Security Model

### Shared Key (Default)

**Use when:**
- Single user with multiple machines
- Family repository (trusted users)
- Small trusted team

**Security properties:**
- ✓ Strong encryption (age/ChaCha20-Poly1305)
- ✗ No per-user access control
- ✗ No revocation without re-encrypting all secrets

**If compromised:**
1. Rotate shared key: `just secrets-rotate-shared`
2. Re-encrypt all user secrets
3. Distribute new key to all machines

### Per-User Keys

**Use when:**
- Multiple independent users
- Compliance requirements for access separation
- Need granular revocation capability

**Security properties:**
- ✓ Strong encryption (age/ChaCha20-Poly1305)
- ✓ Per-user access control
- ✓ Granular revocation

**If compromised:**
1. Revoke user's key
2. Re-encrypt only that user's secrets
3. Other users unaffected

## Threat Model

**Protected against:**
- Secret exposure in git history (encrypted at rest)
- Unauthorized access with proper key management
- Accidental commits of plain-text secrets

**NOT protected against:**
- Root access on target machines (secrets decrypted at runtime)
- Compromised build/activation process
- Repository read access (encrypted files visible)

## Key Management

**Private key storage:**
- Location: `~/.config/agenix/key.txt` (shared) or `~/.config/agenix/key-{user}.txt` (per-user)
- Permissions: 0600 (read/write owner only)
- Backup: Store securely offline (encrypted USB, password manager)
- Distribution: Secure channel only (SSH, encrypted email)

**Public key storage:**
- Shared: `public.age` (repo root, committed)
- Per-user: `user/{name}/public.age` (committed)
- Safe to commit: Public keys are not sensitive

**Key rotation schedule:**
- Shared key: Annually or on suspected compromise
- Per-user key: When user leaves or key compromised
- Emergency rotation: Immediately on confirmed compromise
```

### Migration Security Considerations

**Shared → Per-User Migration**:

1. Generate per-user keypair
1. Decrypt secrets with shared key
1. Re-encrypt with per-user key
1. Rotate shared key (to prevent future use)
1. Update automation to use per-user key

**Security during migration**:

- Both keys temporarily valid (decrypt with old, encrypt with new)
- Cleanup: Delete old encrypted files after verification
- Audit: Log which secrets migrated when

### Implementation Considerations

**Key rotation helper**:

```bash
# Rotate shared key (all users must re-encrypt)
just secrets-rotate-shared
  # 1. Generate new shared keypair
  # 2. Prompt for re-encryption of all user secrets
  # 3. Update public.age
  # 4. Warn: distribute new private key to all machines

# Migrate user to per-user key
just secrets-migrate-user <username>
  # 1. Generate per-user keypair
  # 2. Decrypt with shared key
  # 3. Re-encrypt with per-user key
  # 4. Save to user/{name}/public.age
  # 5. Instruct: distribute private key to user's machines
```

**Compromise response**:

```markdown
## If Private Key Compromised

### Shared Key Compromised

1. **Immediate**: Revoke key access (delete from machines)
2. **Rotate**: `just secrets-rotate-shared`
3. **Re-encrypt**: All users must re-encrypt secrets
4. **Distribute**: New private key to authorized machines only
5. **Audit**: Review git history for unauthorized secret changes

### Per-User Key Compromised

1. **Immediate**: Revoke user's key access
2. **Rotate**: `just secrets-rotate-user <username>`
3. **Re-encrypt**: Only affected user's secrets
4. **Distribute**: New key to that user's machines
5. **No impact**: Other users continue unaffected
```

______________________________________________________________________

## Topic 7: Backward Compatibility

### Decision: Hybrid Model with Graceful Fallback

**Recommendation**: Support both shared and per-user keys simultaneously with automatic detection and zero breaking changes.

### Migration Strategy

**Phase 1: Add Per-User Support** (Feature 031)

- Keep all existing shared key functionality
- Add per-user key detection logic
- Add `just user-create` with key type choice
- Add `just secrets-migrate-user` for opt-in migration
- **Breaking changes**: None (shared key continues to work)

**Phase 2: Gradual Migration** (user-initiated)

- Users migrate to per-user keys when needed
- Both models coexist in same repository
- Tools detect and use appropriate key
- **Breaking changes**: None (voluntary migration)

**Phase 3: Future Deprecation** (optional, not required)

- If/when repository decides to go per-user only
- Provide migration script: `just secrets-migrate-all`
- Document migration timeline
- **Breaking changes**: Only if repository chooses to deprecate shared key

### Compatibility Matrix

| Scenario | Supported | Notes |
|----------|-----------|-------|
| All users use shared key | ✅ Yes | Current state, unchanged |
| All users use per-user keys | ✅ Yes | New capability |
| Mixed (some shared, some per-user) | ✅ Yes | Detection logic handles both |
| User switches shared → per-user | ✅ Yes | Migration helper provided |
| User switches per-user → shared | ✅ Yes | Reverse migration possible |
| Repository without public.age | ❌ No | Must run `just secrets-init` |

### Detection Logic

**Key Selection Priority**:

1. Check for `user/{name}/public.age` (per-user key)
1. Fall back to `public.age` at repo root (shared key)
1. Error if neither exists

**Nix Implementation**:

```nix
# In secrets-module.nix
getUserPublicKey = username:
  let
    userKeyPath = repoRoot + "/user/${username}/public.age";
    sharedKeyPath = repoRoot + "/public.age";
  in
    if builtins.pathExists userKeyPath
    then {
      path = userKeyPath;
      type = "per-user";
      key = builtins.readFile userKeyPath;
    }
    else if builtins.pathExists sharedKeyPath
    then {
      path = sharedKeyPath;
      type = "shared";
      key = builtins.readFile sharedKeyPath;
    }
    else throw ''
      No encryption key found for user ${username}
      
      Initialize keys with:
        Shared key:    just secrets-init
        Per-user key:  just secrets-init-user ${username}
    '';
```

**Bash Implementation**:

```bash
# In justfile secrets commands
get_public_key() {
  local user=$1
  local user_key="user/$user/public.age"
  local shared_key="public.age"
  
  if [ -f "$user_key" ]; then
    echo "Using per-user key for $user"
    cat "$user_key"
  elif [ -f "$shared_key" ]; then
    echo "Using shared key for $user"
    cat "$shared_key"
  else
    echo "Error: No public key found"
    echo ""
    echo "Initialize keys:"
    echo "  Shared:    just secrets-init"
    echo "  Per-user:  just secrets-init-user $user"
    exit 1
  fi
}
```

### Migration Helpers

**Migrate User to Per-User Key**:

```bash
just secrets-migrate-user <username>
```

**Implementation**:

```bash
secrets-migrate-user username:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    USER_DIR="user/$USERNAME"
    SECRET_FILE="$USER_DIR/secrets.age"
    SHARED_KEY="$HOME/.config/agenix/key.txt"
    
    # Validate user exists and has secrets
    if [ ! -f "$SECRET_FILE" ]; then
      echo "Error: $USERNAME has no secrets file"
      exit 1
    fi
    
    # Validate shared key exists
    if [ ! -f "$SHARED_KEY" ]; then
      echo "Error: Shared private key not found"
      exit 1
    fi
    
    # Check if already using per-user key
    if [ -f "$USER_DIR/public.age" ]; then
      echo "$USERNAME already uses per-user key"
      exit 0
    fi
    
    echo "Migrating $USERNAME to per-user encryption key..."
    
    # 1. Decrypt current secrets
    echo "1. Decrypting current secrets..."
    SECRETS=$(nix shell nixpkgs#age -c age -d -i "$SHARED_KEY" "$SECRET_FILE")
    
    # 2. Generate new per-user keypair
    echo "2. Generating per-user keypair..."
    just secrets-init-user "$USERNAME"
    
    # 3. Re-encrypt with new key
    echo "3. Re-encrypting with new key..."
    PUBKEY=$(cat "$USER_DIR/public.age")
    echo "$SECRETS" | nix shell nixpkgs#age -c age -r "$PUBKEY" -o "$SECRET_FILE"
    
    echo ""
    echo "✓ Migration complete!"
    echo ""
    echo "IMPORTANT: Save private key from ~/.config/agenix/key-$USERNAME.txt"
    echo "This key is needed to decrypt $USERNAME secrets."
    echo ""
    echo "Commit changes:"
    echo "  git add $USER_DIR/public.age $SECRET_FILE"
    echo "  git commit -m 'feat(secrets): migrate $USERNAME to per-user key'"
```

**Migrate All Users**:

```bash
just secrets-migrate-all
```

**Implementation**:

```bash
secrets-migrate-all:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Migrating all users to per-user keys..."
    echo ""
    
    USERS=$(just _discover-users)
    for user in $USERS; do
      echo "Processing $user..."
      just secrets-migrate-user "$user" || {
        echo "Warning: Failed to migrate $user"
      }
      echo ""
    done
    
    echo "Migration complete!"
    echo ""
    echo "Review changes with: git diff"
    echo "Commit with: git add user/"
    echo "             git commit -m 'feat(secrets): migrate all users to per-user keys'"
```

### Rollback Procedure

**If migration causes issues**:

```bash
# Rollback user to shared key
just secrets-rollback-user <username>
```

**Implementation**:

```bash
secrets-rollback-user username:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    USER_DIR="user/$USERNAME"
    SECRET_FILE="$USER_DIR/secrets.age"
    USER_KEY="$HOME/.config/agenix/key-$USERNAME.txt"
    SHARED_KEY="$HOME/.config/agenix/key.txt"
    
    if [ ! -f "$USER_DIR/public.age" ]; then
      echo "$USERNAME already uses shared key"
      exit 0
    fi
    
    echo "Rolling back $USERNAME to shared key..."
    
    # 1. Decrypt with per-user key
    SECRETS=$(nix shell nixpkgs#age -c age -d -i "$USER_KEY" "$SECRET_FILE")
    
    # 2. Re-encrypt with shared key
    PUBKEY=$(cat public.age)
    echo "$SECRETS" | nix shell nixpkgs#age -c age -r "$PUBKEY" -o "$SECRET_FILE"
    
    # 3. Remove per-user public key
    rm "$USER_DIR/public.age"
    
    echo "✓ Rollback complete"
    echo "User now uses shared key"
```

### Validation and Testing

**Test scenarios**:

1. ✅ New user with shared key (default path)
1. ✅ New user with per-user key
1. ✅ Existing shared key user (no changes)
1. ✅ Mixed repository (some shared, some per-user)
1. ✅ Migration shared → per-user
1. ✅ Rollback per-user → shared
1. ✅ Secret operations work with both key types

**Validation script**:

```bash
# Test backward compatibility
test-key-compatibility:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Testing key compatibility..."
    
    # Test 1: Shared key user
    just secrets-set testuser1 email "test1@example.com"
    if ! just secrets-edit testuser1; then
      echo "❌ Shared key test failed"
      exit 1
    fi
    echo "✓ Shared key works"
    
    # Test 2: Per-user key
    just user-create testuser2  # Choose per-user key
    just secrets-set testuser2 email "test2@example.com"
    if ! just secrets-edit testuser2; then
      echo "❌ Per-user key test failed"
      exit 1
    fi
    echo "✓ Per-user key works"
    
    # Test 3: Both users can build
    nix build ".#darwinConfigurations.testuser1-testhost.system"
    nix build ".#darwinConfigurations.testuser2-testhost.system"
    echo "✓ Both key types build successfully"
    
    echo ""
    echo "All compatibility tests passed!"
```

______________________________________________________________________

## Topic 8: Key Distribution Patterns

### Decision: Manual Distribution with Documented Options

**Recommendation**: Provide multiple secure distribution methods, let users choose based on their security requirements. No automatic distribution.

### Distribution Methods

**Method 1: SSH Copy (Most Secure)**

```bash
# From machine with private key
scp ~/.config/agenix/key.txt user@newmachine:~/.config/agenix/

# Or per-user key
scp ~/.config/agenix/key-cdrokar.txt user@newmachine:~/.config/agenix/
```

**Benefits**:

- ✅ Encrypted channel (SSH)
- ✅ Direct machine-to-machine
- ✅ No intermediate storage

**Drawbacks**:

- ❌ Requires SSH access to target
- ❌ Manual process per machine

**Method 2: Password Manager (Recommended)**

```bash
# Copy key content to password manager
cat ~/.config/agenix/key.txt | pbcopy  # macOS
cat ~/.config/agenix/key.txt | xclip -selection clipboard  # Linux

# On new machine: retrieve from password manager
# Paste into ~/.config/agenix/key.txt
```

**Benefits**:

- ✅ Centralized secure storage
- ✅ Multi-device sync
- ✅ Backup included

**Drawbacks**:

- ❌ Requires password manager
- ❌ Manual copy/paste

**Method 3: Encrypted USB (Air-gapped)**

```bash
# Encrypt key for USB transport
age -p -o key.txt.age ~/.config/agenix/key.txt
# Copy key.txt.age to USB

# On new machine
age -d key.txt.age > ~/.config/agenix/key.txt
```

**Benefits**:

- ✅ Offline transport
- ✅ Encrypted in transit
- ✅ No network dependency

**Drawbacks**:

- ❌ Physical media required
- ❌ Extra encryption step

**Method 4: Encrypted USB (Air-gapped)**

```bash
# Encrypt key for USB transport
age -p -o key.txt.age ~/.config/agenix/key.txt
# Copy key.txt.age to USB

# On new machine
age -d key.txt.age > ~/.config/agenix/key.txt
chmod 600 ~/.config/agenix/key.txt
```

**Benefits**:

- ✅ Offline transport
- ✅ Encrypted in transit
- ✅ No network dependency
- ✅ Physical control

**Drawbacks**:

- ❌ Physical media required
- ❌ Extra encryption step
- ❌ Can be lost/damaged

**Why NOT Git Repository?**
Storing private keys in git (even private repos) is **NOT recommended**:

- ❌ Keys persist in git history forever (even if deleted)
- ❌ GitHub account compromise exposes all keys
- ❌ Risk of accidentally making repo public
- ❌ Against security best practices (NIST, OWASP)
- ❌ More attack surface than password manager

**Method 5: QR Code (Mobile → Desktop)**

```bash
# Generate QR code
qrencode -t ansiutf8 < ~/.config/agenix/key.txt

# Scan with phone camera
# Manually type on new machine (error-prone, not recommended)
```

**Drawbacks**:

- ❌ Error-prone manual typing
- ❌ Not suitable for long keys
- ❌ Security risk (QR displayed on screen)

### Recommended Workflow

**For user creation with private key repository**:

```bash
just user-create myuser
# ... prompts ...
# Use per-user encryption key? yes
# Keypair generated

Save private key to SSH repository? (y/n) [n]: y
SSH repository URL: git@github.com:myuser/ssh-keys-private.git
Repository path [~/ssh-keys]: 

# Tool clones repo, adds key, commits, prompts for push
Changes committed to ~/ssh-keys:
  + agenix-key-myuser.txt

Push to remote? (y/n) [n]: y
✓ Pushed to git@github.com:myuser/ssh-keys-private.git

Setup complete! On other machines:
  git clone git@github.com:myuser/ssh-keys-private.git ~/ssh-keys
  cp ~/ssh-keys/agenix-key-myuser.txt ~/.config/agenix/key-myuser.txt
  chmod 600 ~/.config/agenix/key-myuser.txt
```

**Important**: Private key repository must be:

- Private (not public)
- Access controlled (only user's SSH key)
- Optionally encrypted (git-crypt, age, etc.)

### Security Considerations

**Never do**:

- ❌ Commit private keys to nix-config repository
- ❌ Send keys via unencrypted email
- ❌ Store in cloud sync (Dropbox, iCloud) without encryption
- ❌ Share via messaging apps

**Always do**:

- ✅ Use encrypted channel (SSH, age, password manager)
- ✅ Set correct permissions (chmod 600)
- ✅ Verify key after transfer
- ✅ Delete from intermediate locations

### Implementation Considerations

**Key repository helper** (optional feature):

```bash
# Save private key to SSH repository
secrets-save-to-repo username repo_url:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    REPO_URL="{{repo_url}}"
    KEY_FILE="$HOME/.config/agenix/key-$USERNAME.txt"
    REPO_DIR="${REPO_DIR:-$HOME/ssh-keys}"
    
    # Validate key exists
    if [ ! -f "$KEY_FILE" ]; then
      echo "Error: Private key not found"
      exit 1
    fi
    
    # Clone or update repository
    if [ ! -d "$REPO_DIR" ]; then
      echo "Cloning repository..."
      git clone "$REPO_URL" "$REPO_DIR"
    else
      echo "Updating repository..."
      cd "$REPO_DIR" && git pull
    fi
    
    # Copy key
    cp "$KEY_FILE" "$REPO_DIR/agenix-key-$USERNAME.txt"
    chmod 600 "$REPO_DIR/agenix-key-$USERNAME.txt"
    
    # Commit
    cd "$REPO_DIR"
    git add "agenix-key-$USERNAME.txt"
    git commit -m "Add agenix key for $USERNAME"
    
    echo ""
    echo "Key saved to repository"
    echo "Push with: cd $REPO_DIR && git push"
```

**Retrieval instructions**:

```bash
# Retrieve private key from SSH repository
secrets-retrieve-from-repo username repo_url:
    #!/usr/bin/env bash
    set -euo pipefail
    
    USERNAME="{{username}}"
    REPO_URL="{{repo_url}}"
    REPO_DIR="${REPO_DIR:-$HOME/ssh-keys}"
    KEY_FILE="$HOME/.config/agenix/key-$USERNAME.txt"
    
    # Clone repository if needed
    if [ ! -d "$REPO_DIR" ]; then
      git clone "$REPO_URL" "$REPO_DIR"
    fi
    
    # Copy key
    if [ ! -f "$REPO_DIR/agenix-key-$USERNAME.txt" ]; then
      echo "Error: Key not found in repository"
      exit 1
    fi
    
    mkdir -p "$(dirname "$KEY_FILE")"
    cp "$REPO_DIR/agenix-key-$USERNAME.txt" "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    
    echo "✓ Key retrieved and installed"
    echo "Location: $KEY_FILE"
```

______________________________________________________________________

## Summary of Recommendations

| Topic | Decision | Rationale |
|-------|----------|-----------|
| **1. Per-User Keys** | Hybrid model (shared default, per-user opt-in) | Balance simplicity and security |
| **2. Key Storage** | Per-user: `user/{name}/public.age`<br>Shared: `public.age` (root) | Colocated, discoverable, no registry |
| **3. User Creation** | Interactive `just user-create` command | Guided workflow, reduces errors |
| **4. Templates** | `user/shared/templates/` with placeholders | Versioned, discoverable, beginner-friendly |
| **5. Git Automation** | Interactive commit, manual push | Safe, flexible, follows best practices |
| **6. Security** | Document both models, provide migration | Informed choice based on threat model |
| **7. Compatibility** | Zero breaking changes, graceful fallback | Existing users unaffected |
| **8. Key Distribution** | Manual with multiple methods | User chooses based on security needs |

______________________________________________________________________

## Implementation Priority

1. **P1 - Core Infrastructure**:

   - Add per-user key detection to secrets-module.nix
   - Add `just secrets-init-user <username>` command
   - Update secrets-set/edit to auto-detect key type

1. **P2 - User Creation Workflow**:

   - Add `user/shared/templates/` with minimal/developer/full
   - Implement `just user-create <username>` with interactive prompts
   - Add template validation and substitution

1. **P3 - Migration Tools**:

   - Add `just secrets-migrate-user <username>`
   - Add `just secrets-migrate-all`
   - Add rollback helpers

1. **P4 - Documentation**:

   - Security model comparison
   - Migration guide
   - Key distribution best practices
   - Template usage guide

1. **P5 - Optional Enhancements**:

   - Git repository helpers for key storage
   - Key rotation automation
   - Pre-commit validation hooks

______________________________________________________________________

## Sources

- [Secure Key Management 2025: Developer Best Practices](https://www.onlinehashcrack.com/guides/cryptography-algorithms/secure-key-management-2025-developer-best-practices.php)
- [GitHub - FiloSottile/age: A simple, modern and secure encryption tool](https://github.com/FiloSottile/age)
- [age and Authenticated Encryption](https://words.filippo.io/dispatches/age-authentication/)
- [GitHub - ryantm/agenix: age-encrypted secrets for NixOS and Home manager](https://github.com/ryantm/agenix)
- [Agenix - Official NixOS Wiki](https://wiki.nixos.org/w/index.php?title=Agenix&mobileaction=toggle_view_desktop)
- [Handling Secrets in NixOS: An Overview](https://discourse.nixos.org/t/handling-secrets-in-nixos-an-overview-git-crypt-agenix-sops-nix-and-when-to-use-them/35462)
- [Infrastructure as Code: Best Practices, Benefits & Examples](https://spacelift.io/blog/infrastructure-as-code)
- [IaC Workflow Automation](https://www.harness.io/harness-devops-academy/iac-workflow-automation)
- [GitHub - Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)
- [GitHub - NixOS/templates: Flake templates](https://github.com/NixOS/templates)
- [Git Workflow Best Practices: A Complete Guide](https://articles.mergify.com/git-workflow-best-practices/)
- [Git Hooks Explained: Automate Your Workflow](https://devtoolhub.com/git-hooks-automate-workflow-examples/)
- [Encryption Best Practices 2025: Guide to Data Protection](https://trainingcamp.com/articles/encryption-best-practices-2025-complete-guide-to-data-protection-standards-and-implementation/)
- [Lifecycle of a Cryptographic Key: A Detailed Overview](https://www.cryptomathic.com/blog/exploring-the-lifecycle-of-a-cryptographic-key-)
