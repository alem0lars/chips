config = "startup_setup".get_config

options = parse_args

if config[:lastpass]
  "lpass".run "logout"
  "lpass".run "login", config[:lastpass][:user][:email]
  "lpass".run "sync"
end

ssh_key = "~/.ssh/id_rsa".to_pn.expand_path
"ssh-add".run("#{ssh_key}") if File.file?(ssh_key)

"unclutter".run "-root"

"start-pulseaudio-x11".run

"urxvtd".run

"copyq".run if options[:copyq]

"openterm".run("--title", "weechat", "--cmd", "weechat") if options[:weechat]
"openterm".run("--title", "mutt", "--cmd", "mutt") if options[:mutt]
"openterm".run("--title", "turses", "--cmd", "turses") if options[:turses]

"toggl".run if config[:toggl]

"openterm".run "--title", "task", "--cmd", "task sync && task list"
"openterm".run "--title", "anapnea", "--cmd", "ssh alem0lars@anapnea.net"
"openterm".run "--title", "sysmon", "--cmd", "tmuxinator start sysmon"


# vim: set filetype=ruby :
