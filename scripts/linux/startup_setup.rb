config = "startup_setup".get_config

options = parse_args

[ -> {
    if config[:lastpass]
      status = unless lpass_logged_in?
        [ -> { lpass_login config[:lastpass][:user] },
          -> { lpass_sync }
        ].do_all
      else
        "lastpass login skipped: already logged in".psuc
      end
    else
      true
    end
  }, -> {
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
      config[:mega].each do |e|
        e[:pwd].as_pwd!
        args = [
          "-r", "/Root".to_pn.join(e[:remote]),
          "-l", e[:local],
          "-u", e[:user],
          "-p", "H-#{e[:pwd]}-H"
        ]
        kwargs = { quiet: true, ignore_status: true }

        "megacopy".run "--reload", "--download", *args, **kwargs
        "megacopy".run "--reload",               *args, **kwargs
      end
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
    "tmuxinator".run "stop", "sysmon"
    openterm %w(tmuxinator start sysmon), title: :sysmon, tmux: false
  }
].do_all


# vim: set filetype=ruby :
