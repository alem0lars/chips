$config = "startup-setup".get_config

_options = parse_args

[
  # Start basic daemons
  -> { "start-pulseaudio-x11".run single: "pulseaudio", interactive: true },
  -> { "redshift".run_if $config[:redshift], detached: true, single: true, interactive: true },
  -> { "unclutter".run "-root", detached: true, single: true, interactive: true },
  # Setup desktop environment
  -> { "multimonitor".run_if $config[:multimonitor], detached: true, single: true, interactive: true },
  -> { "dunst".run_if $config[:dunst], detached: true, single: true, interactive: true },
  -> { "taffybar".run_if $config[:taffybar], detached: true, single: true, interactive: true },
  -> {
    if $config[:wmname]
      "wmname".run $config[:wmname], detached: true, single: true, interactive: true
    else
      true
    end
  },
  -> {
    if $config[:feh]
      "feh".run "--no-fehbg", "--image-bg", "black", "--bg-max", $config[:feh][:path].escape, interactive: true
    else
      true
    end
  },
  # Setup LastPass
  -> {
    if $config[:lastpass]
      unless lpass_logged_in?
        [ -> { lpass_login $config[:lastpass][:user] },
          -> { lpass_sync }
        ].do_all
      else
        "lastpass login skipped: already logged in".psuc
      end
    else
      true
    end
  },
  # Setup SSH
  -> {
    ssh_auth_sock = ENV["XDG_RUNTIME_DIR"].to_pn.expand_path.join("ssh-agent.socket")
    "ssh-agent".run "-a", ssh_auth_sock, single: true, interactive: true
  },
  -> {
    ssh_key = "~/.ssh/id_rsa".to_pn.expand_path
    if File.file?(ssh_key)
      unless "ssh-add".capture("-l").split("\n").any? { |e| e.split(/\s+/)[2] == ssh_key.to_s }
        "ssh-add".run "#{ssh_key}", interactive: true
      else
        "ssh key `#{ssh_key.as_tok}` is already present: skipping..".pinf
      end
    else
      true
    end
  },
  # Trayer apps
  -> { "megasync".run_if $config[:mega], detached: true, single: true },
  # Standalone apps
  -> { "copyq".run_if $config[:copyq], detached: true, single: true },
  -> { "trello".run_if $config[:trello], detached: true, single: true },
  -> { "toggl".run_if $config[:toggl], detached: true, single: true },
  -> { "thunderbird".run_if $config[:thunderbird], detached: true, single: true },
  -> { "slack".run_if $config[:slack], detached: true, single: true },
  -> { "whatsapp".run_if $config[:whatsapp], detached: true, single: true },
  -> { "messenger".run_if $config[:messenger], detached: true, single: true },
  -> { "telegram-desktop".run_if $config[:telegram], detached: true, single: true },
  # Gnome Keyring & related apps
  -> {
    if $config[:gnome_keyring]
      unless $config[:gnome_keyring][:pwd]
        "missing password for Gnome Keyring".perr
      end
      $config[:gnome_keyring][:pwd].as_pwd!

      status = [
        -> {
          ENV["GNOME_KEYRING_PASSWORD"] = $config[:gnome_keyring][:pwd]
          status = "gnome-keyring-unlock".run interactive: true
          ENV["GNOME_KEYRING_PASSWORD"] = nil
          status
        }
        # => Standalone apps that require Gnome Keyring unlocked.
      ].do_all

      unless status
        "failed to unlock gnome keyring and/or run apps depending upon it!".pwrn
      end

      status
    end
    true
  },
  -> { "skypeforlinux".run detached: true, single: true },
  -> { openterm %w(weechat), run_if: $config[:weechat], title: :weechat, detached: true },
  # => Connections to remote servers
  -> {
    if $config[:ssh]
      $config[:ssh].each do |ssh|
        ssh[:pwd].as_pwd!
        ssh[:title] ||= "#{ssh[:user]}@#{ssh[:server]}"

        cmd = []
        cmd += ["sshpass", "-p", "H-#{ssh[:pwd]}-H"] if ssh[:pwd]
        cmd += ["ssh", "#{ssh[:user]}@#{ssh[:server]}"]

        openterm cmd, title: ssh[:title], detached: true
      end
    else
      true
    end
  },
  # => spawn web apps
  -> {
    return true unless $config[:web_apps]
    args = []
    if $config[:web_apps][:only]
      args << "--only"
      args << $config[:web_apps][:only].join(",")
    end
    "spawn-web-apps".run(*args, detached: true, single: true, interactive: true)
  },
  # => spawn pre-defined consoles
  -> {
    if $config[:tmuxinator]
      "tmuxinator".run "stop", "sysmon", ignore_status: true, interactive: true
      openterm %w(tmuxinator start sysmon), title: :sysmon, tmux: false, detached: true
    end
  }
].do_all


# vim: set filetype=ruby :
