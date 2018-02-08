[
  -> () { "xdotool".check_program! },
  -> () { "wmctrl".check_program! },
  -> () {
    # Init config
    $config = {}
  },
  -> () {
    # Parse options
    $options = parse_args do |parser, opts|
      parser.on("-c", "--cmd CMD", "Command to be executed") do |cmd|
        opts[:cmd] = cmd
      end
      parser.on("-n", "--name NAME",
                "Regex to match the template name") do |name|
        opts[:name] = name
      end
    end

    if !$options[:cmd]
      "Missing command".perr
    elsif !$options[:name]
      "Missing name".perr
    else
      true
    end
  },
  -> () {
    # Normalize config
    $config[:cmd] = $options[:cmd]
    $config[:name] = $options[:name]

    true
  },
  -> () {
    window = "xdotool".capture "search", "--name", $config[:name]
    matches = window.split("\n")
    if matches.length == 0
      $config[:cmd].run interactive: true
    elsif matches.length > 1
      "Ambiguous name #{name}".perr
    else
      match = matches.first
      "wmctrl".run "-i", "-R", match
    end
  }
].do_all auto_exit_code: true
