config = "openterm".get_config

options = parse_args do |parser, options|
  parser.on("-t", "--[no-]tmux", "use tmux") do |tmux|
    options[:tmux] = tmux
  end
  parser.on("-c", "--cmd COMMAND", "command") do |cmd|
    options[:cmd] = cmd
  end
  parser.on("-t", "--title TITLE", "title") do |title|
    options[:title] = title
  end
end

term = config[:term]
if term == "urxvtc" && !"urxvtd".is_running # fallback when no daemon is avail
  term = "urxvt"
end

if options.has_key? :tmux
  tmux = options[:tmux]
else
  tmux = config[:tmux]
end

if options[:title].nil? || options[:title].empty?
  title = ("a".."z").to_a.shuffle[0,8].join
else
  title = options[:title]
end

cmd = options[:cmd]

title.gsub! /[@.]/, "-"

ENV.delete "TMUX"

args  = []
args += ["-title", title]
args += ["-e", "zsh", "-i"]
args += ["-c", "tmux new-session -s #{title} #{cmd.escape}"] if  cmd &&  tmux
args += ["-c", "tmux new-session -s #{title}"              ] if !cmd &&  tmux
args += ["-c", "#{cmd}"                                    ] if  cmd && !tmux

term.run(*args)


# vim: set filetype=ruby :
