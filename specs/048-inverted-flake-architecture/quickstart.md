# Quickstart: Feature 048 — Inverted Flake Architecture

## For End Users (after feature is complete)

### Fresh install from scratch

```bash
# 1. Clone your private config repo
git clone git@github.com:cdrolet/usst ~/.config/nix-private
cd ~/.config/nix-private

# 2. Build and install — everything is self-contained
just install cdrokar home-macmini-m4
```

No need to separately clone `nix-config`. It is fetched by Nix as a flake input.

### Upgrade framework

```bash
cd ~/.config/nix-private
just update-input nix-config   # pins new nix-config commit in flake.lock
just build cdrokar home-macmini-m4
```

### Day-to-day usage

All commands are identical — just run them from `usst/` instead of `nix-config/`:

```bash
just build cdrokar home-macmini-m4
just install cdrokar home-macmini-m4
just secrets-set cdrokar email "me@example.com"
just list-users
just list-hosts
```

---

## For Framework Developers (nix-config contributors)

`nix-config` remains buildable standalone using the `config/` stub:

```bash
cd ~/project/nix-config
nix flake check         # Zero configs (stub), no error
just build              # Requires state from previous build
```

To test with real configs:
```bash
nix flake check --override-input user-host-config path:~/project/usst
```

---

## Migration from Current Setup

```bash
# In usst/:
# 1. Add flake.nix (nix-config.lib.mkOutputs)
# 2. Add justfile (delegates to nix-config)
# 3. Run nix flake lock
cd ~/project/usst
nix flake lock

# 4. Verify outputs match current
nix flake show

# 5. Test build
just build cdrokar home-macmini-m4

# 6. Push usst to remote
git add flake.nix flake.lock justfile
git commit -m "feat: inverted flake architecture (Feature 048)"
git push
```
