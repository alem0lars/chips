define_flow main: true, config: true do
  # TODO validate configuration

  -> {
    $config[:respawn_apps].each { |app| app.pkill :quit }
    true
  } |
  -> {
    $config[:sleep_program].run sudo: true
  } |
  -> {
    $config[:lock_program].run_app_if $config[:lock_program], detached: false
  } |
  -> {
    $config[:respawn_apps].each { |app| app.run_app }
    true
  }
end


# vim: set filetype=ruby :
