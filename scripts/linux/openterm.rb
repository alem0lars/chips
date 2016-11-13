config = "openterm".get_config

options = parse_args do |parser, options|
  parser.on("-t", "--[no-]tmux", "use tmux") do |kernel|
    options[:tmux] = tmux
  end
  parser.on("-c", "--cmd COMMAND", "command") do |kernel|
    options[:cmd] = cmd
  end
  parser.on("-t", "--title TITLE", "title") do |kernel|
    options[:title] = title
  end
end

tmux  = config[:tmux] unless options.has_key?(:tmux)
term  = config[:term]
title = options[:title]
cmd   = options[:cmd]

args  = []
args += ["-title", options[:title]] if options[:title]
args += ["-e", "zsh", "-i"]
args += ["-c", "tmux new-session -s #{title} #{cmd}"] if  cmd &&  tmux
args += ["-c", "tmux new-session -s #{title}"       ] if !cmd &&  tmux
args += ["-c", cmd                                  ] if  cmd && !tmux

term.run(*args)


# vim: set filetype=ruby :
