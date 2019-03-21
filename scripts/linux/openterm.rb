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

title.gsub!(/[@.]/, "-")

ENV.delete "TMUX" if tmux

args  = []

# Add title argument.
args += [
  case term
  when /rxvt/ then "-title"
  when /^st$/ then "-t"
  else             "--title"
  end,
  title
]

# When using tmux, speedup loading using bash instead of zsh
outer_shell = tmux ? "bash" : "zsh"

args += [
  case term
  when /^kitty$/ then nil
  else                "-e"
  end,
  outer_shell,
  "-i"
].compact

if tmux
  if "tmux".run("has-session", "-t", title, output: ->(out, _) { out.empty? }, verbose: false)
    args += ["-c", "tmux attach-session -t #{title}"]
    "attaching to existing tmux session: #{title.as_tok}".pinf
  else
    if cmd
      args += ["-c", "tmux new-session -s #{title} #{cmd.escape}"]
    else
      args += ["-c", "tmux new-session -s #{title}"]
    end
    "creating new tmux session: #{title.as_tok}".pinf
  end
else
  if cmd
    args += ["-c", "#{cmd}"]
  end
end

term.run(*args, interactive: true)


# vim: set filetype=ruby :
