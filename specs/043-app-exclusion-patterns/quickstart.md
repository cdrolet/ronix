# Quickstart: App Exclusion Patterns

## Usage

Add `"!"` prefix to any app name or category wildcard in your `user.applications` array to exclude it from wildcard results.

### Exclude a specific app

```nix
# Install everything except docker
applications = [ "*" "!docker" ];
```

### Exclude an entire category

```nix
# Install everything except AI tools
applications = [ "*" "!ai/*" ];
```

### Exclude multiple patterns

```nix
# Install everything except AI tools and games
applications = [ "*" "!ai/*" "!games/*" ];
```

### Re-include after exclusion

```nix
# Install everything, exclude AI category, but keep chatgpt
applications = [ "*" "!ai/*" "chatgpt" ];
```

### Combine with category wildcards

```nix
# Install all dev tools except docker, plus all browsers
applications = [ "dev/*" "!docker" "browser/*" ];
```

## Rules

1. Exclusions only subtract from wildcard results — `["!docker"]` alone installs nothing
1. Explicit app names always win over exclusions — `["*", "!docker", "docker"]` installs docker
1. Only single-level category exclusions supported — `"!ai/*"` works, `"!ai/chat/*"` does not
1. Non-matching exclusions are silently ignored
