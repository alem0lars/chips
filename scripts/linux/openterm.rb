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
  end
].compact

cmd_args = [outer_shell, "-i"]

if tmux
  if "tmux".run("has-session", "-t", title, output: ->(out, _) { out.empty? }, verbose: false)
    cmd_args += ["-c", "tmux attach-session -t #{title}"]
    "attaching to existing tmux session: #{title.as_tok}".pinf
  else
    if cmd
      cmd_args += ["-c", "tmux new-session -s #{title} #{cmd.escape}"]
    else
      cmd_args += ["-c", "tmux new-session -s #{title}"]
    end
    "creating new tmux session: #{title.as_tok}".pinf
  end
else
  if cmd
    cmd_args += ["-c", "#{cmd}"]
  end
end

# Merge cmd_args into args.
if term =~ /^termite$/
  args << cmd_args
else
  args += cmd_args
end

term.run(*args, interactive: true)
