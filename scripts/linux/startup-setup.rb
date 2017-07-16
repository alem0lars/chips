config = "startup-setup".get_config

_options = parse_args

[
  # basic daemons
  -> { "start-pulseaudio-x11".run single: true },
  -> { "redshift".run_if config[:redshift], detached: true, single: true },
  -> { "unclutter".run "-root", detached: true, single: true },
  -> { "urxvtd".run detached: true, single: true },
  # setup desktop environment
  -> { "dunst".run_if config[:dunst], detached: true, single: true },
  -> { "taffybar".run_if config[:taffybar], detached: true, single: true },
  -> {
    if config[:feh]
      "feh".run "--no-fehbg", "--image-bg", "black", "--bg-max", config[:feh][:path].escape
    end
  },
  # setup lastpass
  -> {
    if config[:lastpass]
      unless lpass_logged_in?
        [ -> { lpass_login config[:lastpass][:user] },
          -> { lpass_sync }
        ].do_all
      else
        "lastpass login skipped: already logged in".psuc
      end
    else
      true
    end
  },
  # setup ssh
  -> {
    ssh_key = "~/.ssh/id_rsa".to_pn.expand_path
    if File.file?(ssh_key)
      unless "ssh-add".capture("-l").split("\n").any? { |e| e.split(/\s+/)[2] == ssh_key.to_s }
        "ssh-add".run "#{ssh_key}"
      else
        "ssh key `#{ssh_key.as_tok}` is already present: skipping..".pinf
      end
    else
      true
    end
  },
  # trayer apps
  -> { "megasync".run_if config[:mega], detached: true, single: true },
  # standalone apps
  -> { "copyq".run_if config[:copyq], detached: true, single: true },
  -> { "thunderbird".run_if config[:thunderbird], detached: true, single: true },
  -> { "slack".run config[:slack], detached: true, single: true },
  -> { openterm %w(weechat), run_if: config[:weechat], title: :weechat },
  -> { openterm %w(mutt), run_if: config[:mutt], title: :mutt },
  -> { openterm %w(turses), run_if: config[:turses], title: :turses },
  -> { openterm %w(task), title: :task },
  # => connections to remote servers
  -> {
    if config[:ssh]
      config[:ssh].each do |ssh|
        ssh[:pwd].as_pwd!
        ssh[:title] ||= "#{ssh[:user]}@#{ssh[:server]}"

        cmd = []
        cmd += ["sshpass", "-p", "H-#{ssh[:pwd]}-H"] if ssh[:pwd]
        cmd += ["ssh", "#{ssh[:user]}@#{ssh[:server]}"]

        openterm cmd, title: ssh[:title]
      end
    else
      true
    end
  },
  # => spawn web apps
  -> { "spawn-web-apps".run_if config[:web_apps], detached: true, single: true },
  # => spawn pre-defined consoles
  -> {
    if config[:tmuxinator]
      "tmuxinator".run "stop", "sysmon", quiet: true, ignore_status: true
      openterm %w(tmuxinator start sysmon), title: :sysmon, tmux: false
    end
  }
].do_all


# vim: set filetype=ruby :