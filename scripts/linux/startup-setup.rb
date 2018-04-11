define_flow main: true, config: true do
  # TODO validate config

  # 1: Login to Lastpass
  -> {
    lpass_login_and_sync($config[:lastpass][:user]) if $config[:lastpass]
  } |
  # 2: Setup SSH agent
  (
    -> {
      run_app("ssh-agent", config: {
        args: ["-a", xdg_runtime_dir("ssh-agent.socket")]
      })
    } &
    -> { ssh_add "~/.ssh/id_rsa" }
  ) |
  # 3: Spawn apps
  -> {
    define_flow main: false do
      $config[:apps].map do |config|
        -> { run_app(config.delete(:name), config: config) }
      end.to_flow(:|)
    end
  }
end


# vim: set filetype=ruby :
