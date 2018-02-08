config = "git-purge-file".get_config

[
  -> () { # check external requirements
    "git".check_program!
    true
  },
  -> () { # arguments normalization
    options = parse_args do |parser, opts|
      parser.on("-p", "--path [PATH]",
                "Path to file or directory that should be purged") do |path|
        opts[:path] = path
      end
    end

    config[:path] = options[:path] if options[:path]

    true
  },
  -> () { # config normalization
    "path needs to be provided".perr unless config[:path]
    config[:path] = config[:path].to_pn

    true
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

    true
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
].do_all auto_exit_code: true


# vim: set filetype=ruby :
