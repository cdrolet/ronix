{
  config,
  pkgs,
  lib,
  ...
}: {
  # Starship cross-shell prompt
  # Dependencies: None (standalone prompt)

  programs.starship = {
    enable = true;

    settings = {
      # Add newline before prompt
      add_newline = true;

      # Prompt character
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      # Directory display
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };

      # Git branch indicator
      git_branch = {
        symbol = " ";
      };

      # Git status indicators
      git_status = {
        conflicted = "🏳";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "🤷";
        stashed = "📦";
        modified = "📝";
        staged = "[++($count)](green)";
        renamed = "👅";
        deleted = "🗑";
      };

      # Nix shell indicator
      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state( ($name))]($style) ";
      };

      # Disable package version display
      package.disabled = true;
    };
  };
}
