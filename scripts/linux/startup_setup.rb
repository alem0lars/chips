config = "startup_setup".get_config

options = parse_args

if config[:lastpass]
  if !"lpass".run("status", verbose: false, quiet: true)
    [ -> { "lpass".run "login", config[:lastpass][:user] },
      -> { "lpass".run "sync" }
    ].do_all
  else
    "lastpass login skipped: already logged in".psuc
  end
end

ssh_key = "~/.ssh/id_rsa".to_pn.expand_path
"ssh-add".run("#{ssh_key}") if File.file?(ssh_key)

"unclutter".run("-root", detached: true) unless "unclutter".is_running

"start-pulseaudio-x11".run unless "start-pulseaudio-x11".is_running

"urxvtd".run(detached: true) unless "urxvtd".is_running

"copyq".run(detached: true) if config[:copyq] and !"copyq".is_running

"openterm".run("--title", "weechat", "--cmd", "weechat") if config[:weechat]
"openterm".run("--title", "mutt", "--cmd", "mutt") if config[:mutt]
"openterm".run("--title", "turses", "--cmd", "turses") if config[:turses]

"openterm".run "--title", "task", "--cmd", "task sync && task list"
"openterm".run "--title", "anapnea", "--cmd", "ssh alem0lars@anapnea.net"
"openterm".run "--title", "sysmon", "--cmd", "tmuxinator start sysmon",
               "--without-tmux"

if config[:mega]
  config[:mega].each do |e|
    "megacopy".run "--reload", "--download",
                   "-r", "/Root".to_pn.join(e[:remote]),
                   "-l", e[:local],
                   "-u", e[:user],
                   "-p", e[:lpassword] ?
                         `lpass show --password #{e[:lpassword]}` :
                         e[:password]
  end
end


# vim: set filetype=ruby :
