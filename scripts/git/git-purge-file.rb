config = "git-purge-file".get_config

[
  -> () { # check external requirements
    $exit_code = 1
    "missing program `git`".perr unless "git".check_program
    true
  },
  -> () { # config normalization
    $exit_code = 2
    true
  },
  -> () { # arguments normalization (errors: exit_code=3)
    $exit_code = 3
    options = parse_args do |parser, options|
      parser.on("-p", "--path [PATH]",
                "Path to file or directory that should be purged") do |path|
        options[:path] = path
      end
    end

    "path needs to be provided".perr unless options[:path]

    config[:path] = options[:path].to_pn
  },
  -> () { # perform commands (errors: exit_code=4)
    $exit_code = 4
  },
  -> () {
    "git".run "filter-branch",
              "--tree-filter",
              "rm -rf #{config[:path]}",
              "--prune-empty",
              "HEAD",
              interactive: true
  },
  -> () {
    output = StringIO.new
    "git".run "for-each-ref",
              "--format",
              "%(refname)",
              "refs/original/",
              output: output
    config[:refs] = output.string.trim.split "\n"
  },
  -> () {
    status
    config[:refs].each do |ref|
      status &&= "git".run "update-ref", "-d", ref, interactive: true
    end
    status
  },
  -> () {
    "git".run "gc", "--prune=all", "--aggressive", interactive: true
  }
].do_all


# vim: set filetype=ruby :
