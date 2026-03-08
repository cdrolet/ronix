{...}: {
  # User: {{USERNAME}}
  # Template: common
  # Basic user configuration with essential applications

  user = {
    name = "{{USERNAME}}";
    email = "{{EMAIL}}";
    fullname = "{{FULLNAME}}";

    # Security configuration (passwords, SSH keys, credentials)
    security = {
      password = "<secret>";
    };

    # Locale configuration (Feature: 018-user-locale-config)
    locale = {
      languages = ["fr-CA"];
      keyboard = {
        layout = ["canadian-french" "canadian-english"];
        macStyleMappings = true;
      };
      timezone = "America/Toronto";
      format = "fr_CA.UTF-8";
    };

    # Workspace configuration (applications, dock, repositories)
    workspace = {
      # Applications - common set for everyday use
      applications = [
        "browser/*"
        "media/*"
        "productivity/*"
        "security/*"
        "terminal/*"
        "shell/*"
        # Version Control
        "git"
      ];

      # Dock configuration (Feature: 023-user-dock-config)
      # Customize to your preferences
      docked = [
        "brave"
        # email
        "proton mail"
        "geary"
        # calculator
        "calculator"
        "gnome-calculator"
        "libreoffice"
        "obsidian"
        "|"
        "ghostty"
        "system-settings"
        "gnome-control-center"
        "||"
        "/Downloads"
      ];
    };
  };
}
