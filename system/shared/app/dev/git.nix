{
  config,
  pkgs,
  lib,
  ...
}: let
  # Import secrets helper
  secrets = import ../../../../user/lib/secrets.nix {inherit lib pkgs;};
in {
  # Git version control system with delta for diffs and lazygit for TUI
  # Dependencies: delta.nix (optional but recommended)

  programs.git = {
    enable = true;

    # Git settings
    # User identity (email/name) is written to ~/.config/git/secret-identity
    # at activation time and included here, so secrets don't end up in the
    # read-only Nix store config file.
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      include.path = "~/.config/git/secret-identity";
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      "*.swo"
      "*~"
      ".direnv/"
      "result"
      "result-*"
    ];
  };

  # Feature 027: Resolve git secrets at activation time
  # Writes to ~/.config/git/secret-identity (included by programs.git)
  # instead of git config --global, which would fail on the read-only
  # Nix store config file.
  home.activation.applyGitSecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "git";
    fields = {
      email = ''
        mkdir -p "$HOME/.config/git"
        printf '[user]\n\temail = %s\n' "$EMAIL" > "$HOME/.config/git/secret-identity"
      '';
    };
  };

  # Delta: syntax-highlighting pager for git
  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
    };
  };

  # Lazygit: terminal UI for git commands
  programs.lazygit = {
    enable = true;

    settings = {
      git = {
        paging = {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        };
      };
    };
  };

  # Shell aliases for git
  home.shellAliases = {
    g = "git";
    gst = "git status";
    gco = "git checkout";
    gbr = "git branch";
    gci = "git commit";
    gcm = "git commit -m";
    gp = "git push";
    gpl = "git pull";
    ga = "git add";
    gaa = "git add --all";
    gd = "git diff";
    gds = "git diff --staged";
    gunstage = "git reset HEAD --";
    glast = "git log -1 HEAD";
    glog = "git log --graph --oneline --all";
    gvisual = "git log --graph --oneline --all";
    lg = "lazygit";
  };
}
