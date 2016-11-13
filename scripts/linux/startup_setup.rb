config = "startup_setup".get_config

options = parse_args


[ -> {
    if config[:lastpass]
      status = if !"lpass".run("status", verbose: false, quiet: true)
        [ -> { "lpass".run "login", config[:lastpass][:user] },
          -> { "lpass".run "sync" }
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
      "ssh-add".run "#{ssh_key}"
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
      "openterm".run("--title", "weechat", "--cmd", "weechat")
    else
      true
    end
  },
  -> {
    if config[:mutt]
      "openterm".run("--title", "mutt", "--cmd", "mutt")
    else
      true
    end
  },
  -> {
    if config[:turses]
      "openterm".run("--title", "turses", "--cmd", "turses")
    else
      true
    end
  },
  -> {
    "openterm".run "--title", "task", "--cmd", "task sync && task list"
  },
  -> {
    if config[:ssh]
      Array(config[:ssh]).each do |ssh|
        ssh[:pwd].as_pwd!
        ssh[:title] ||= "#{ssh[:user]}@#{ssh[:server]}"
        cmd  = ssh[:pwd] ? "sshpass -p <HIDDEN>#{ssh[:pwd].escape}</HIDDEN> " : ""
        cmd << "ssh #{ssh[:user]}@#{ssh[:server]}"

        "openterm".run "--title", ssh[:title], "--cmd", cmd
      end
    else
      true
    end
  },
  -> {
    "openterm".run "--title", "sysmon", "--cmd", "tmuxinator start sysmon",
                   "--without-tmux"
  },
  -> {
    if config[:mega]
      config[:mega].each do |e|
        e[:pwd].as_pwd!
        args = [
          "-r", "/Root".to_pn.join(e[:remote]),
          "-l", e[:local],
          "-u", e[:user],
          "-p", "<HIDDEN>#{e[:pwd]}</HIDDEN>"
        ]
        kwargs = { quiet: true, ignore_status: true }

        "megacopy".run "--reload", "--download", *args, **kwargs
        "megacopy".run "--reload",               *args, **kwargs
      end
    else
      true
    end
  }
].do_all


# vim: set filetype=ruby :
