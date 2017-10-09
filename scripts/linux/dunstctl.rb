config = "dunstctl".get_config

avail_cmds = {
  pause: "DUNST_COMMAND_PAUSE",
  resume: "DUNST_COMMAND_RESUME"
}

[
  -> () {
    # Check external requirements.
    "missing program `notify-send`".perr unless "notify-send".check_program
    true
  },
  -> () {
    cmd_names = avail_cmds.keys.map(&:to_s)

    # Options normalization.
    options = parse_args do |parser, opts|
      parser.on("--cmd CMD", String, "(available: `#{cmd_names}`)") do |cmd|
        if cmd_names.include? cmd
          opts[:cmd] = cmd.to_sym
        else
          "invalid command specified, not in: #{cmd_names}".perr
        end
      end
    end

    # Merge `options` <-> `configs`
    config[:cmd] = options[:cmd]

    "a command needs to be specified!".perr unless config[:cmd]

    true
  },
  -> () {
    # See https://github.com/dunst-project/dunst/issues/408 for implementation
    # details.
    "notify-send".run avail_cmds[config[:cmd]]
  }
].do_all auto_exit_code: true
