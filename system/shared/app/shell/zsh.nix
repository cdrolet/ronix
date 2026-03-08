{
  config,
  pkgs,
  lib,
  ...
}: {
  # Zsh shell with modern enhancements
  # Dependencies: starship.nix (optional for prompt), fzf (optional for fuzzy finding)

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # History substring search (arrow up/down for prefix matching)
    historySubstringSearch = {
      enable = true;
      searchUpKey = ["^[[A" "$terminfo[kcuu1]"];
      searchDownKey = ["^[[B" "$terminfo[kcud1]"];
    };

    # History configuration
    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
      expireDuplicatesFirst = true;
    };

    # Default keymap (emacs-style bindings)
    defaultKeymap = "emacs";

    # ZSH options and completion configuration
    initContent = ''
      # Extended globbing and safer operations
      setopt EXTENDED_GLOB NO_CLOBBER BRACE_CCL COMBINING_CHARS RC_QUOTES
      unsetopt MAIL_WARNING

      # Editor and flow control
      setopt NO_FLOW_CONTROL BEEP

      # Job control
      setopt LONG_LIST_JOBS AUTO_RESUME NOTIFY
      unsetopt BG_NICE HUP CHECK_JOBS

      # Completion behavior
      setopt COMPLETE_IN_WORD ALWAYS_TO_END AUTO_MENU AUTO_LIST AUTO_PARAM_SLASH COMPLETE_ALIASES
      unsetopt MENU_COMPLETE

      # History behavior
      setopt BANG_HIST APPEND_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY
      setopt HIST_VERIFY HIST_REDUCE_BLANKS HIST_ALLOW_CLOBBER
      setopt HIST_IGNORE_SPACE HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS
      setopt HIST_NO_STORE HIST_BEEP HIST_EXPIRE_DUPS_FIRST

      # Directory navigation
      setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT

      # ── Key bindings ─────────────────────────────────────────
      bindkey '^[[3~' delete-char          # Delete key
      bindkey '^[[H'  beginning-of-line    # Home key
      bindkey '^[[F'  end-of-line          # End key
      bindkey '^[[1;5C' forward-word       # Ctrl+Right
      bindkey '^[[1;5D' backward-word      # Ctrl+Left

      # ── Completion system ──────────────────────────────────────
      zmodload -i zsh/complist

      # Cache completion for slow commands
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path "$ZSH_CACHE"

      # Auto rehash commands
      zstyle ':completion:*' rehash true

      # Colored completion list
      zstyle ':completion:*:default' list-colors ''${(s.:.)LS_COLORS}

      # Graphical menu selection
      zstyle ':completion:*:*:*:*:*' menu select

      # Group different match types separately
      zstyle ':completion:*' group-name '''
      zstyle ':completion:*' verbose yes

      # Case-insensitive, partial-word, then substring completion
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

      # Complete .. directories
      zstyle ':completion:*' special-dirs true

      # Fault tolerance (1 error per 3 characters)
      zstyle ':completion:*' completer _complete _correct _approximate
      zstyle -e ':completion:*:approximate:*' max-errors 'reply=( $(( ($#PREFIX+$#SUFFIX)/3 )) numeric )'

      # Don't complete uninteresting system users
      zstyle ':completion:*:*:*:users' ignored-patterns \
              adm amanda apache at avahi avahi-autoipd beaglidx bin cacti canna \
              clamav daemon dbus distcache dnsmasq dovecot fax ftp games gdm \
              gkrellmd gopher hacluster haldaemon halt hsqldb ident junkbust kdm \
              ldap lp mail mailman mailnull man messagebus mldonkey mysql nagios \
              named netdump news nfsnobody nobody nscd ntp nut nx obsrun openvpn \
              operator pcap polkitd postfix postgres privoxy pulse pvm quagga radvd \
              rpc rpcuser rpm rtkit scard shutdown squid sshd statd svn sync tftp \
              usbmux uucp vcsa wwwrun xfs '_*'

      # Don't complete internal functions
      zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

      # ── Completion formatting ──────────────────────────────────
      zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
      zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
      zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
      zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
      zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

      zstyle ':completion:*:matches' group 'yes'
      zstyle ':completion:*:options' description 'yes'
      zstyle ':completion:*:options' auto-description '%d'

      # ── History completion (Ctrl+Space) ────────────────────────
      zle -C hist-complete complete-word _generic
      zstyle ':completion:hist-complete:*' completer _history
      bindkey '^@' hist-complete

      # In menu selection, Ctrl+Space to descend into subdirectories
      bindkey -M menuselect '^@' accept-and-infer-next-history

      # ── Directory completion ───────────────────────────────────
      zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
      zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
      zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
      zstyle ':completion:*' squeeze-slashes true
      zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

      # ── Hostname completion ────────────────────────────────────
      zstyle -e ':completion:*:hosts' hosts 'reply=(
        ''${=''${=''${=''${''${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
        ''${=''${(f)"$(cat /etc/hosts(|)(N) <<(ypcat hosts 2>/dev/null))"}%%\#*}
        ''${=''${''${''${''${(@M)''${(f)"$(cat ~/.ssh/config 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
      )'

      # ── Man pages ──────────────────────────────────────────────
      zstyle ':completion:*:manuals' separate-sections true
      zstyle ':completion:*:manuals.(^1*)' insert-sections true

      # ── SSH/SCP/Rsync ──────────────────────────────────────────
      zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
      zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
      zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
      zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
      zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
      zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
      zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'

      # ── Kill/rm/diff ───────────────────────────────────────────
      zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
      zstyle ':completion::*:rm:*:*' file-patterns '*.o:object-files:object\ file *(~|.(old|bak|BAK)):backup-files:backup\ file *(~|.log):log-files:log\ files *~*(~|.(o|old|bak|log|BAK)):all-files:all\ files'
      zstyle ':completion::*:kill:*:*' command 'ps xf -U $USER -o pid,%cpu,cmd'
      zstyle ':completion:*:*:kill:*' menu yes select
      zstyle ':completion:*:*:kill:*' force-list always
      zstyle ':completion:*:*:kill:*' insert-ids single

      # ── Status line for many matches ───────────────────────────
      zstyle ':completion:*:default' select-prompt $'\e[01;35m -- Match %M    %P -- \e[00;00m'
      zstyle ':completion:*:default' list-prompt '%S%M matches%s'

      # ── History substring search colors ────────────────────────
      HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=white,fg=black,bold'
      HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=yellow,fg=black,bold'
      HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS='i'
    '';
  };

  # Session variables
  home.sessionVariables =
    {
      TERM = lib.mkDefault "xterm-256color";
      EDITOR = lib.mkDefault "vi";
      VISUAL = lib.mkDefault "$EDITOR";
      ZSH_CACHE = "${config.home.homeDirectory}/.cache/zsh";
      LC_ALL = lib.mkDefault "en_US.UTF-8";
      LANG = lib.mkDefault "en_US.UTF-8";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      HOMEBREW_PREFIX = lib.mkDefault "/opt/homebrew";
      HOMEBREW_CELLAR = lib.mkDefault "/opt/homebrew/Cellar";
      HOMEBREW_REPOSITORY = lib.mkDefault "/opt/homebrew";
    };

  # Session PATH additions
  home.sessionPath =
    [
      "${config.home.homeDirectory}/bin"
      "${config.home.homeDirectory}/.local/bin"
      "/usr/local/sbin"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];

  # Shell aliases (namespaced, non-conflicting)
  home.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    d = "dirs -v";
    reload = "exec zsh";
    cls = "clear";
    h = "atuin search --interactive";
    history-stat = "atuin stats";
  };

  # Create cache directory
  home.file.".cache/zsh/.keep".text = "";
}
