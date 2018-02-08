[
  -> () { "xdotool".check_program },
  -> () { "wmctrl".check_program },
  -> () {
    # Parse options.
    $options = parse_args do |parser, opts|
      parser.on("-c", "--cmd CMD", "Command to be executed") do |cmd|
        opts[:cmd] = cmd
      end
      parser.on("-n", "--name NAME",
                "Regex to match the template name") do |name|
        opts[:name] = name
      end
    end
  },
  -> () {
    # TODO implement
  }
].do_all auto_exit_code: true
