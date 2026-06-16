# fish shell — ported from MyLinux fish/{config,aliases,functions}.fish.
#
# Retired from the old setup: fisher + tide (→ starship, DECISIONS 023), the
# nvm fisher plugin and load_nvm (→ Ticket 08), the per-shell ssh-agent eval
# (→ services.ssh-agent in ./default.nix), the toolbox `tb`/`tbr` aliases and
# the cargo-env / tide / key-binding-migration conf.d files. completions.fish
# only covered flatpak + toolbox and is dropped with them.
_: {
  programs.fish = {
    enable = true;

    shellAliases = {
      # Basics
      c = "clear";
      ff = "fastfetch";
      ls = "eza -a --icons=always";
      ll = "eza -al --icons=always";
      lt = "eza -a --tree --level=1 --icons=always";
      wifi = "nmtui";

      # docker→podman stays (DECISIONS); podman arrives with Ticket 08.
      docker = "podman";

      # npm / nx
      nf = "npm run format";
      nl = "npm run lint";
      nt = "npm run test";
      nx = "npx nx";

      # Rust / cargo (tools land in Ticket 08; aliases dormant until then)
      cb = "cargo build";
      cbr = "cargo build --release";
      cch = "cargo check"; # not 'cc' — avoid shadowing the C compiler
      ck = "cargo clippy --all-targets";
      ct = "cargo nextest run";
      cr = "cargo run";
      cw = "bacon"; # background cargo check/clippy/test watcher

      # System management. `update` was `rpm-ostree upgrade`; on NixOS it
      # rebuilds from the local flake checkout (matches the wallpaper picker's
      # FLAKE_DIR default, DECISIONS 022). The host is selected by hostname.
      update = "sudo nixos-rebuild switch --flake ~/desktop-nix";
      shutdown = "systemctl poweroff";
      reboot = "systemctl reboot";
      suspend = "systemctl suspend";

      # Git. `gs`=git-spice and lazygit's gh PR commands are dormant until
      # Ticket 08; `lg` is plain lazygit now (was `toolbox run -c dev-tools`).
      gs = "git-spice";
      ga = "git add";
      gc = "git checkout";
      gp = "git push";
      gl = "git log --oneline";
      lg = "lazygit";

      # Directory navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Coloured / human-readable defaults
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      df = "df -h";
      du = "du -h";
      free = "free -h";
      ps = "ps aux";
      top = "btop";
      cat = "bat";
      less = "bat";
      more = "bat";
    };

    functions = {
      # Create and enter a directory.
      mkcd = ''
        mkdir -p $argv[1]
        cd $argv[1]
      '';

      # Extract archives by extension.
      extract = ''
        if test -f $argv[1]
            switch $argv[1]
                case "*.tar.bz2"
                    tar xjf $argv[1]
                case "*.tar.gz"
                    tar xzf $argv[1]
                case "*.bz2"
                    bunzip2 $argv[1]
                case "*.rar"
                    unrar x $argv[1]
                case "*.gz"
                    gunzip $argv[1]
                case "*.tar"
                    tar xf $argv[1]
                case "*.tbz2"
                    tar xjf $argv[1]
                case "*.tgz"
                    tar xzf $argv[1]
                case "*.zip"
                    unzip $argv[1]
                case "*.Z"
                    uncompress $argv[1]
                case "*.7z"
                    7z x $argv[1]
                case "*"
                    echo "don't know how to extract '$argv[1]'"
            end
        else
            echo "'$argv[1]' is not a valid file"
        end
      '';

      # Find and kill processes matching a pattern. pgrep -f matches safely
      # (no grep-on-ps-aux self-matches); guard the empty-pattern case so we
      # never feed kill an empty arg list.
      killf = ''
        if test (count $argv) -eq 0
            echo "usage: killf <pattern>"
            return 1
        end
        pgrep -f -- $argv[1] | xargs --no-run-if-empty kill -9
      '';

      # Back up a file next to itself.
      backup = ''
        cp $argv[1] $argv[1].backup
        echo "Backup created: $argv[1].backup"
      '';

      # Largest directories under the given path.
      duh = ''
        du -h $argv | sort -hr | head -20
      '';

      # git status with colour-coded state.
      gst = ''
        git status --porcelain | while read -l line
            set -l statusg (echo $line | cut -c1-2)
            set -l file (echo $line | cut -c4-)
            switch $statusg
                case "??"
                    echo -e "\033[31m$file\033[0m (untracked)"
                case "A "
                    echo -e "\033[32m$file\033[0m (added)"
                case "M "
                    echo -e "\033[33m$file\033[0m (modified)"
                case "D "
                    echo -e "\033[31m$file\033[0m (deleted)"
            end
        end
      '';
    };

    interactiveShellInit = ''
      set -g fish_greeting ""
      set -g fish_history_size 10000
    '';
  };
}
