config = "startup_setup".get_config

_options = parse_args

[ -> {
    if config[:feh]
      "feh".run "--no-fehbg", "--image-bg", "black", "--bg-max", config[:feh][:path].escape
    end
  },
  -> {
    if config[:dunst]
      "dunst".run detached: true, single: true
    else
      true
    end
  },
  -> {
    if config[:redshift]
      "redshift".run detached: true, single: true
    else
      true
    end
  },
  -> {
    if config[:taffybar]
      "taffybar".run detached: true, single: true
    else
      true
    end
  },
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
  -> {
    if config[:mega]
      "megasync".run detached: true, single: true
    else
      true
    end
  },
  -> { "unclutter".run "-root", detached: true, single: true },
  -> { "start-pulseaudio-x11".run single: true },
  -> { "urxvtd".run detached: true, single: true },
  -> {
    if config[:copyq]
      "copyq".run detached: true, single: true
    else
      true
    end
  },
  -> {
    if config[:thunderbird]
      "thunderbird".run detached: true, single: true
    else
      true
    end
  },
  -> {
    if config[:slack]
      "slack".run detached: true, single: true
    else
      true
    end
  },
  -> {
    if config[:weechat]
      openterm %w(weechat), title: :weechat
    else
      true
    end
  },
  -> {
    if config[:mutt]
      openterm %w(mutt), title: :mutt
    else
      true
    end
  },
  -> {
    if config[:turses]
      openterm %w(turses), title: :turses
    else
      true
    end
  },
  -> {
    openterm title: :task
  },
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
  -> {
    if config[:tmuxinator]
      "tmuxinator".run "stop", "sysmon", quiet: true, ignore_status: true
      openterm %w(tmuxinator start sysmon), title: :sysmon, tmux: false
    end
  }
].do_all


# vim: set filetype=ruby :
