define_flow main: true, config: true do
  sdi = { detached: true, single: true, interactive: true }

  -> { "start-pulseaudio-x11".run single: "pulseaudio", interactive: true }\
  |
  -> { "redshift".run_if $config[:redshift], **sdi }\
  |
  -> { "unclutter".run "-root", **sdi }\
  |
  -> { "multimonitor".run_if $config[:multimonitor], **sdi }\
  |
  -> { "dunst".run_if $config[:dunst], **sdi }\
  |
  -> { "taffybar".run_if $config[:taffybar], **sdi }\
  |
  -> { "wmname".run_if $config[:wmname], $config[:wmname], **sdi }\
  |
  -> { "nitrogen".run_if $config[:nitrogen], "--restore", interactive: true }\
  |
  -> { "feh".run_if $config[:feh], "--no-fehbg", "--image-bg", "black",
                    "--bg-max", -> { $config[:feh][:path].escape },
                    interactive: true }\
  |
  -> { "gnsync".run_if $config[:gnsync],
                       "--two-way", "--save-images", "--all",
                       "--path", -> { $config[:gnsync][:path].escape } }\
  |
  -> { lpass_login_and_sync($config[:lastpass][:user]) if $config[:lastpass] }\
  |
  (
    -> { "ssh-agent".run "-a", xdg_runtime_dir("ssh-agent.socket"),
                         single: true, interactive: true }\
    &
    -> { ssh_add "~/.ssh/id_rsa" }
  )\
  |
  -> { "megasync".run_if $config[:mega], **sdi }\
  |
  -> { "copyq".run_if $config[:copyq], **sdi }\
  |
  -> { "trello".run_if $config[:trello], **sdi }\
  |
  -> { "toggl".run_if $config[:toggl], **sdi }\
  |
  -> { "thunderbird".run_if $config[:thunderbird], **sdi }\
  |
  -> { "slack".run_if $config[:slack], **sdi }\
  |
  -> { "whatsapp".run_if $config[:whatsapp], **sdi }\
  |
  -> { "caprine".run_if $config[:caprine], **sdi }\
  |
  -> { "telegram".run_if $config[:telegram], **sdi }\
  |
  (
    -> { gnome_keyring_unlock($config[:gnome_keyring][:pwd]) if $config[:gnome_keyring] }\
    &
    -> { "skypeforlinux".run(**sdi) }
  )\
  |
  -> { openterm %w(weechat), run_if: $config[:weechat], title: :weechat, detached: true }\
  |
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
  }\
  |
  -> {
    return true unless $config[:web_apps]
    args = []
    if $config[:web_apps][:only]
      args << "--only"
      args << $config[:web_apps][:only].join(",")
    end
    "spawn-web-apps".run(*args, detached: true, single: true, interactive: true)
  }\
  |
  -> {
    if $config[:tmuxinator]
      "tmuxinator".run "stop", "sysmon", ignore_status: true, interactive: true
      openterm %w(tmuxinator start sysmon), title: :sysmon, tmux: false, detached: true
    end
  }
end


# vim: set filetype=ruby :
