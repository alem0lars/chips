require "erb"
require "fileutils"
require "json"
require "mkmf"
require "net/http"
require "open-uri"
require "optparse"
require "ostruct"
require "pathname"
require "shellwords"
require "yaml"
require "tempfile"
require "pp"
begin
  require "ap"
rescue LoadError
end

$exit_code = nil

MakeMakefile::Logging.instance_variable_set(:@logfile, File::NULL)

# {{{ utils

class ErbRenderer < OpenStruct
  def render(template)
    ERB.new(template).result(binding)
  end
end

# }}}

module Shortcuts

  # {{{ color

  def black;         "\e[30m#{self.to_s}\e[0m" end
  def red;           "\e[31m#{self.to_s}\e[0m" end
  def green;         "\e[32m#{self.to_s}\e[0m" end
  def yellow;        "\e[33m#{self.to_s}\e[0m" end
  def blue;          "\e[34m#{self.to_s}\e[0m" end
  def magenta;       "\e[35m#{self.to_s}\e[0m" end
  def cyan;          "\e[36m#{self.to_s}\e[0m" end
  def gray;          "\e[37m#{self.to_s}\e[0m" end

  def bg_black;      "\e[40m#{self.to_s}\e[0m" end
  def bg_red;        "\e[41m#{self.to_s}\e[0m" end
  def bg_green;      "\e[42m#{self.to_s}\e[0m" end
  def bg_yellow;     "\e[43m#{self.to_s}\e[0m" end
  def bg_blue;       "\e[44m#{self.to_s}\e[0m" end
  def bg_magenta;    "\e[45m#{self.to_s}\e[0m" end
  def bg_cyan;       "\e[46m#{self.to_s}\e[0m" end
  def bg_gray;       "\e[47m#{self.to_s}\e[0m" end

  def bold;          "\e[1m#{self.to_s}\e[22m" end
  def italic;        "\e[3m#{self.to_s}\e[23m" end
  def underline;     "\e[4m#{self.to_s}\e[24m" end
  def blink;         "\e[5m#{self.to_s}\e[25m" end
  def reverse_color; "\e[7m#{self.to_s}\e[27m" end

  # }}}

  # {{{ format

  def as_tok
    self.to_s.magenta
  end

  def prefixed(prefix)
    "#{prefix} #{self}"
  end

  def simulated
    prefixed "[simulated]".bg_yellow.black
  end

  def escape
    Shellwords.escape self.to_s
  end

  # }}}

  # {{{ input

  def ask(type: :string, allow_empty: false)
    question = self.to_s.gsub(/[?]*/, "")
    question.strip!
    question << "? "

    $stdout.write question.magenta.prefixed(" ? ".black.bg_magenta)
    answer = gets.chomp

    case type
    when :bool
      if answer =~ /(y|ye|yes|yeah|ofc)$/i
        true
      elsif answer =~ /(n|no|fuck|fuck\s+you|fuck\s+off)$/i
        false
      else
        "answer misunderstood".pwrn
        question.ask type: type
      end
    when :string
      if !allow_empty && answer.empty?
        "empty answer".pwrn
        question.ask type: type
      else
        answer
      end
    else "unhandled question type: `#{type}`".perr
    end
  end

  # }}}

  # {{{ output

  def psuc
    puts self.to_s.green.prefixed(" > ".black.bg_green)
    return true
  end

  def pinf
    puts self.to_s.blue.prefixed(" I ".black.bg_blue)
    return true
  end

  def perr(exit_code: $exit_code)
    puts self.to_s.red.prefixed(" ! ".black.bg_red)
    exit(exit_code) unless exit_code.nil?
    return false
  end

  def pwrn(ask_continue: false)
    puts self.to_s.yellow.prefixed(" W ".black.bg_yellow)
    if ask_continue
      "continue".ask
    else
      false
    end
  end

  # }}}

  # {{{ type conversion

  def to_pn
    Pathname.new self.to_s
  end

  # }}}

  # {{{ parsing

  def as_pwd!(**run_args)
    replace self.as_pwd(**run_args)
  end

  def as_pwd(**run_args)
    case self.to_s
    when /^lpass:(?<id>.+)$/ then lpass_show_pwd(Regexp.last_match(:id), **run_args)
    else self
    end.dup
  end

  # TODO test erb_render
  def erb_render(data)
    ErbRenderer.new(data).render(self.to_s)
  end

  # }}}

  # {{{ execution

  def capture(*args, **run_args)
    program_name = self.to_s
    output = StringIO.new
    run_args[:output] = output
    run_args[:verbose] = false
    if program_name.run(*args, **run_args)
      output.string.strip
    else
      ""
    end
  end

  def check_program
    find_executable0(self.to_s)
  end

  def check_program!
    "missing program `#{self.to_s}`".perr unless self.to_s.check_program
    true
  end

  def is_running(**run_args)
    if "pgrep".check_program || "#{"pgrep".as_tok} is needed".perr
      "pgrep".capture(self.to_s, **run_args).length > 0
    end
  end

  def tmux(*cmd, **run_args)
    detached = run_args.delete :detached
    manual_exit = run_args.delete :manual_exit
    args = []
    args << "new-session"
    args << "-d" if detached
    args += ["-s", self.to_s.gsub(/[.:\/]/, "")]
    if manual_exit
      args << "bash"
      args << "-c"
      args << [
        format_args(cmd),
        "echo Hit Ctrl+D to exit",
        "read"
      ].join("; ")
    else
      args += cmd
    end

    with_env TMUX: nil do
      "tmux".run(*args, **run_args)
    end
  end

  def run_if(condition, *args, **kwargs)
    if condition
      run(*args, **kwargs)
    else
      true
    end
  end

  def arg_if(arg_value)
    arg_name = self.to_s
    if arg_value
      arg_name
    else
      []
    end
  end

  def arg_valued(arg_value)
    arg_name = self.to_s
    arg_value ? [arg_name, arg_value] : []
  end

  def run(*args,
          dir: nil, msg: nil, verbose: true, simulate: false,
          detached: false, single: false, ignore_status: false, output: $stdout,
          interactive: false, retry_on_error: false,
          success_msg: nil, failure_msg: nil)
    simulate ||= $simulate

    program_name = self.to_s
    cmd = program_name.dup
    pretty_cmd = program_name.dup
    unless args.empty?
      cmd << " "
      cmd << format_args(args)

      pretty_cmd << " "
      pretty_cmd << format_args(args, pretty: true)
    end

    handle_output = ->(output_data) do
      data = output_data.strip
      lines = data.split("\n")

      tmp_output, fn = if output.respond_to? :call
                         [StringIO.new, output]
                       else
                         [output, ->(_, _) { true }]
                       end

      return false unless $?.success?

      if tmp_output.nil?
        true
      else
        tmp_output.write(data)
        fn.call(data, lines)
      end
    end

    status = false
    program_to_check = single.is_a?(String) ? single : program_name
    if single && program_to_check.is_running
      "Command `#{pretty_cmd.as_tok}` is already running".pinf
      status = true
    else
      _run = lambda do |run_cmd|
        run_cmd << " 2>&1"

        begin
          status = if interactive
                     pid = Process.spawn(run_cmd)
                     if detached
                       if output != $stdout
                         "Cannot redirect output in interactive program".perr
                       end
                       Process.detach(pid)
                       true
                     else
                       Process.wait(pid)
                       $?.success?
                     end
                   else
                     if detached
                       pid = fork do
                         res = `#{run_cmd}`
                         handle_output.call(res)
                       end
                       Process.detach(pid)
                       true
                     else
                       res = `#{run_cmd}`
                       handle_output.call(res)
                     end
                   end
        rescue Interrupt
          status = false
        end
      end

      if dir
        FileUtils.cd(dir) do
          msg.pinf if msg
          if simulate
            status = "Run command #{pretty_cmd.as_tok} (workdir=#{dir.as_tok})".simulated.pinf
          else
            _run.call(cmd)
          end
        end
      else
        msg.pinf if msg
        if simulate
          status = "Run command #{pretty_cmd.as_tok}".simulated.pinf
        else
          _run.call(cmd)
        end
      end

      if !simulate
        if ignore_status || status
          "Command #{pretty_cmd.as_tok} successfully run".psuc if verbose
        else
          "Command #{pretty_cmd.as_tok} failed to run".perr if verbose
          if retry_on_error
            if "Retry".ask type: :bool
              status = run(*args, dir: dir, msg: msg, verbose: verbose,
                           simulate: simulate, detached: detached,
                           single: single, ignore_status: ignore_status,
                           output: output, interactive: interactive,
                           retry_on_error: retry_on_error)
            else
              status = false
            end
          end
        end
      end
    end

    status = ignore_status || status

    if status
      success_msg.to_s.psuc if success_msg
    else
      failure_msg.to_s.pwrn if failure_msg
    end

    status
  end

  def chperms(perms, simulate: false)
    simulate ||= $simulate

    if simulate
      "Change permissions to: #{perms.as_tok}".simulated.pinf
    else
      FileUtils.chmod(perms.to_s.to_i(8), self.to_s)
    end
  end

  # }}}

  # {{{ fs operations

  def filename
    Pathname.new(self.to_s).sub_ext("").basename.to_s
  end

  def cd
    status = nil
    FileUtils.cd(self.to_s) do
      status = yield
    end
    status
  end

  # }}}

  # {{{ misc

  def get_config(default: {})
    name = self.to_s

    avail_config_paths = [
      "/etc".to_pn.join(name),
      ENV["HOME"].to_pn.join(".config", name),
      ENV["HOME"].to_pn.join(".#{name}")
    ]

    config = default

    config.merge!(avail_config_paths.each_with_object({}) do |config_path, hash|
      begin
        hash.merge!(JSON.parse(config_path.read)) if config_path.readable?
      rescue JSON::ParserError => _
        "Skipping invalid config at #{config.as_tok}".pwrn
      end
    end)

    env_var_name = "CFG_#{name.upcase}"
    if ENV.has_key?(env_var_name)
      begin
        config.merge!(JSON.parse(ENV[env_var_name]))
      rescue JSON::ParserError => _
        "Skipping invalid config in the environment variable #{env_var_name.as_tok}".pwrn
      end
    end

    "Successfully parsed chip configuration".psuc

    config.deep_symbolize_keys
  end

  # }}}

  # {{{ replication

  def build_script(to: nil, simulate: false)
    simulate ||= $simulate

    script_path = self.to_s.to_pn
    dst_path = to.to_s.to_pn unless to.nil?
    perms = "555"

    return "invalid script: not a valid file".perr unless script_path.file?

    if %w(.yml .yaml).include? script_path.extname
      # TODO make checks about correctness of information provided
      data = YAML.load_file(script_path).deep_symbolize_keys
      if data.has_key? :download
        data[:download].each do |name, url|
          "Downloading script #{name.as_tok} from #{url.as_tok}".pinf
          begin
            data = download(url)
          rescue ArgumentError => err # TODO add right errors
            return "Failed to download #{url.as_tok}: #{err.message.as_tok}".perr
          end
          if dst_path.directory?
            dst_dir_path = dst_path
          else
            if dst_path.dirname.directory?
              dst_dir_path = dst_path.dirname
            else
              "Invalid destination path #{to.as_tok}".perr
            end
          end

          "Script successfully downloaded".psuc

          dst_script_path = dst_dir_path.join(name.to_s)
          if simulate
            "Wrote to #{dst_script_path.as_tok} (permissions=#{perms.as_tok})".simulated.pinf
          else
            dst_script_path.delete if dst_script_path.file?
            IO.copy_stream(data, dst_script_path)
            dst_path.chperms perms
          end

          "Script successfully installed".psuc
        end
      end
    else
      if script_path.filename.end_with?("-wrapper")
        program_name = script_path.filename.gsub(/-wrapper$/, "")
        unless program_name.check_program
          if "Missing program #{program_name.as_tok}".pwrn ask_continue: true
            "Skipping installation of #{program_name.as_tok}".pinf
            return
          else
            "Fix your installation!".perr
          end
        end
        "Building wrapper for #{program_name.as_tok}".pinf
        dst_path = dst_path.dirname.join(program_name)
      else
        "Building script #{script_path.as_tok}".pinf
      end

      script_data = script_path.read
      if script_path.extname == ".rb"
        hashbang    = "#!/usr/bin/env ruby"
        separator   = "# entry-point"
        sfw_data    = __FILE__.to_pn.read
        dst_data    = "#{hashbang}\n\n#{sfw_data}\n\n#{separator}\n#{script_data}"
      else
        dst_data = script_data
      end

      "Script successfully built".psuc

      perms = "555"
      if simulate
        if dst_path
          "Wrote to #{dst_path.as_tok} (permissions=#{perms.as_tok})".simulated.pinf
        end
      else
        dst_path.delete if dst_path.file?
        dst_path.write dst_data if dst_path
        dst_path.chperms perms
      end

      "Script successfully installed".psuc
    end

    return dst_data
  end

  # }}}

end

# TODO add right errors

Error = Class.new(StandardError)

DOWNLOAD_ERRORS = [
  SocketError,
  OpenURI::HTTPError,
  RuntimeError,
  URI::InvalidURIError,
  Error,
]

def download(url, max_size: nil)
  if $simulate
    "Downloaded url #{url}".pinf
    ""
  else
    url = URI.encode(URI.decode(url))
    url = URI(url)
    raise Error, "URL was invalid" if !url.respond_to?(:open)

    options = {}
    options["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36"
    options[:content_length_proc] = ->(size) {
      if max_size && size && size > max_size
        raise Error, "File is too big (maximum=#{max_size.as_tok})"
      end
    }

    downloaded_file = url.open(options)

    if downloaded_file.is_a?(StringIO)
      downloaded_file.read
    else
      downloaded_file
    end
  end
rescue *DOWNLOAD_ERRORS => error
  raise if error.instance_of?(RuntimeError) && error.message !~ /redirection/
  raise Error, "Download failed (#{url.as_tok}): #{error.message}"
end

# include the defined shortcuts
class Fixnum;   include Shortcuts end
class String;   include Shortcuts end
class Symbol;   include Shortcuts end
class Pathname; include Shortcuts end
class Array;    include Shortcuts end
class Hash;     include Shortcuts end

class Array

  def do_all(auto_exit_code: false)
    status = true

    self.each do |blk|
      $exit_code = $exit_code.nil? ? 1 : $exit_code + 1 if auto_exit_code
      break unless status
      begin
        status = blk.call
      rescue Interrupt
        status = "Interrupted while running command".pwrn ask_continue: true
      end
    end

    status
  end

end

class Hash

  # Extract `n` sample key/value pairs from the underlying `Hash`
  def sample(n=1)
    Hash[self.to_a.sample(n)]
  end

  # Perform recursive merge of the current `Hash` (`self`) with the provided one
  # (the `second` argument)
  #
  # the merge have knows how to recurse in both `Hash`es and `Array`s
  def deep_merge(second, **options)
    array_concat = options.key?(:array_concat) ? options[:array_concat] : false

    merger = proc do |key, v1, v2|
      if Hash === v1 && Hash === v2
        v1.merge(v2, &merger)
      elsif Array === v1 && Array === v2
        if array_concat
          (Set.new(v1) + Set.new(v2)).to_a
        else
          v2
        end
      else
        v2
      end
    end

    self.merge(second, &merger)
  end

  def fqkeys(prefix="")
    self.inject([]) do |acc, (k, v)|
      prefix_new = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      acc + (v.is_a?(Hash) ? v.fqkeys(prefix_new) : [prefix_new])
    end
  end

  def slice(*keys)
    self.select{|k, _| keys.include?(k)}
  end

  # return a new `Hash` with all keys converted to `String`s
  def deep_stringify_keys
    deep_transform_keys{ |key| key.to_s }
  end

  # destructively convert all keys to `String`s
  def deep_stringify_keys!
    deep_transform_keys!{ |key| key.to_s }
  end

  # return a new `Hash` with all keys converted to `Symbol`s, as long as they
  # respond to `to_sym`
  def deep_symbolize_keys
    deep_transform_keys{ |key| key.to_sym rescue key }
  end

  # destructively convert all keys to `Symbol`s, as long as they respond to
  # `to_sym`
  def deep_symbolize_keys!
    deep_transform_keys!{ |key| key.to_sym rescue key }
  end

  # return a new `Hash` with all keys converted by the block operation
  def deep_transform_keys(&block)
    deep_transform_keys_in_object(self, &block)
  end

  # destructively convert all keys by using the block operation
  def deep_transform_keys!(&block)
    deep_transform_keys_in_object!(self, &block)
  end

  def deep_transform_keys_in_object(object, &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key)] = deep_transform_keys_in_object(value, &block)
      end
    when Array
      object.map {|e| deep_transform_keys_in_object(e, &block)}
    else object
    end
  end
  private :deep_transform_keys_in_object

  def deep_transform_keys_in_object!(object, &block)
    case object
    when Hash
      object.keys.each do |key|
        value = object.delete(key)
        object[yield(key)] = deep_transform_keys_in_object!(value, &block)
      end
      object
    when Array
      object.map! {|e| deep_transform_keys_in_object!(e, &block)}
    else object
    end
  end
  private :deep_transform_keys_in_object!
end

class Pathname
  def gsub(pattern, replacement, &block)
    Pathname.new(self.to_s.gsub(pattern, replacement, &block))
  end
end

# Ensure the current process is running as `root`
def ensure_root
  if !(Process.euid == 0)
    "The script needs root privileges".perr exit_code: 255
  else
    true
  end
end

def uname
  `uname -r`
end

# parse commandline arguments
def parse_args(mandatory: %i(), simulate_enabled: true)
  options = {}

  parser = OptionParser.new do |p|
    if simulate_enabled
      p.on("-s", "--[no-]simulate", "Run in simulate mode") do |simulate|
        $simulate = options[:simulate] = simulate
        "Running in `simulate` mode".pinf if $simulate
      end
    end

    yield(p, options) if block_given?

    p.on_tail("-h", "--help", "Show this message") do
      puts p
      exit
    end
  end

  # Perform parsing
  parser.parse!

  # Ensure mandatory arguments are present
  mandatory.each do |mandatory_arg_name|
    unless options.key? mandatory_arg_name
      "Missing required argument #{mandatory_arg_name.as_tok}".perr
      return nil
    end
  end

  # Add parser to returned options for convenience
  options[:parser] = parser

  # Add `phelp` function to returned options, in order to allow caller to print
  # the arguments help
  def options.phelp
    self[:parser].to_s.pinf
  end

  options
end

# {{{ Environment

def with_env(**kwargs)
  "No block given".perr exit_code: 1 unless block_given?

  # Save
  old_values = {}
  kwargs.each do |key, value|
    key = key.to_s
    old_values[key] = ENV[key]
    ENV[key] = value
  end

  # Evaluation with modified environment
  result = yield

  # Restore
  old_values.each { |key, value| ENV[key] = value }

  # Return result
  result
end

# }}}

def format_args(args, pretty: false)
  if args.is_a? Array
    args.map { |arg| format_args(arg, pretty: pretty) }.
         reject(&:empty?).
         join(" ")
  else
    # Allow lazy evaluation of arguments
    args = args.call if args.respond_to? :call

    if pretty
      args.to_s.strip.gsub(/(?:H-)+.*(?:-H)+/, "HIDDEN").escape
    else
      args.to_s.strip.gsub(/(?:H-)+(.*)(?:-H)+/, "\1").escape
    end
  end
end

def render_dir(template_dir, output_dir,
               context: {},
               include_regex: nil,
               templatized_regex: nil,
               verbose: false)
  template_dir = template_dir.expand_path
  output_dir = output_dir.expand_path

  Pathname.glob(template_dir.join("**", "*")) do |src_path|
    src_rel_path = src_path.relative_path_from(template_dir)
    dst_path = output_dir.join(src_rel_path)

    next if src_path.directory? # skip directories

    if include_regex.nil? || src_rel_path.to_s =~ include_regex
      # 1: Create parent directory of destination file
      begin
        dst_path.dirname.mkpath unless dst_path.dirname.directory?
      rescue Exception => error
        if "Failed to create directory #{dst_path.dirname.as_tok}: #{error}".pwrn ask_continue: true
          next
        else
          return
        end
      else
        "[#{"mkdir".as_tok}] #{dst_path.dirname.as_tok}".psuc if verbose
      end

      # 2: Compute file content
      is_templatized = templatized_regex && src_rel_path.to_s =~ templatized_regex
      if is_templatized
        dst_content = ErbRenderer.new(context).render(src_path.read)
      else
        dst_content = src_path.read
      end

      # 3: Copy file
      begin
        dst_path.write(dst_content)
      rescue Exception => error
        if "Failed to copy  #{src_path.as_tok} to #{dst_path.as_tok}: #{error}".pwrn ask_continue: true
          next
        else
          return
        end
      else
        if is_templatized
          "[#{"generate".as_tok}] #{src_path.as_tok} → #{dst_path.as_tok}".psuc if verbose
        else
          "[#{"copy".as_tok}] #{src_path.as_tok} → #{dst_path.as_tok}".psuc if verbose
        end
      end
    else
      "[#{"skip".as_tok}] #{src_path.as_tok}".pinf if verbose
    end
  end

  true
end

# ──────────────────────────────────────────────────────────────── FileSystem ──

def xdg_runtime_dir(*args)
  ENV["XDG_RUNTIME_DIR"].to_pn.expand_path.join(*args.map(&:to_s))
end

# ───────────────────────────────────────────────────────────────── Chip Flow ──

class Proc
  # Execute the underlying object and the other only if the first returns `true`
  # Return `true` if both return `true`
  def &(other)
    lambda {
      _update_exit_code
      status = _safe_call

      _update_exit_code
      status && other._safe_call(status)
    }
  end

  # Execute sequentially both and return `true` if any returns `true`
  def |(other)
    lambda {
      _update_exit_code
      status_self = _safe_call

      _update_exit_code
      status_other = other._safe_call(status_self)

      status_self || status_other
    }
  end

  def _update_exit_code
    $exit_code = $exit_code.nil? ? 1 : $exit_code + 1 if $auto_exit_code
  end

  def _safe_call(*args)
    begin
      Proc.new do |*args|
        diff = arity - args.size
        diff = 0 if diff.negative?
        args = args.concat(Array.new(diff, nil)).take(arity)

        call(*args)
      end.call(*args)
    rescue Interrupt
      "Interrupted while running flow entry".pwrn ask_continue: true
    end
  end
end

# Define the chip flow
def define_flow(name: File.basename(__FILE__, File.extname(__FILE__)),
                auto_exit_code: true,
                # Boilerplate
                main: false,
                config: false,
                args: nil)
  # Define internal utility methods
  $auto_exit_code = true

  # Evaluate flow defined in the provided block
  if block_given?
    fn = -> () {
      if main
        "Starting #{name.as_tok}..".pinf
      else
        true
      end
    }

    # Fill boilerplate
    # -> Init config
    fn = fn & -> () {
      if config
        $config = name.get_config
      else
        $config = {}
      end

      true
    }
    # -> Parse args
    fn = fn & -> () {
      if args
        if args.respond_to? :call
          $args = parse_args { |p, o| args.call(p, o) }
          true
        else
          "Invalid arguments specification".perr
        end
      else
        $args = parse_args
        true
      end
    }

    # Execute the given block
    fn = fn & yield

    # Show results
    fn = fn | -> (status) {
      if main
        if status
          "Successfully #{name.as_tok}".psuc
        else
          "Failed to execute #{name.as_tok}".perr
        end
      else
        true
      end
    }

    status = fn.call
  else
    status = "Invalid flow specification: no block given".perr
  end

  # Cleanup internal utility methods
  $auto_exit_code = nil

  # Return status
  status
end

# ───────────────────────────────────────────────── Specific Programs Support ──

def lpass_login(user)
  "lpass".run "login", user, interactive: true
end

def lpass_sync
  "lpass".run "sync", interactive: true
end

def lpass_show_pwd(id, **run_args)
  "lpass".capture "show", "--pass", "H-#{id.to_s}-H", **run_args
end

def lpass_logged_in?
  "lpass".run("status", verbose: false, output: nil)
end

def lpass_login_and_sync(user)
  unless lpass_logged_in?
    define_flow main: false do
      -> { lpass_login user } & -> { lpass_sync }
    end
  else
    "Lastpass login skipped: already logged in".psuc
  end
end

def openterm(cmd, run_if: true, title: nil, tmux: true, detached: false)
  args  = []
  args += ["--title", title]
  args += [tmux ? "--tmux" : "--no-tmux"]
  unless cmd.nil? || cmd.empty?
    args << "--cmd"
    args << Array(cmd).map { |e| e.escape }.join(" ")
  end

  if run_if
    "openterm".run(*args, interactive: true, detached: detached)
  else
    true
  end
end

def ssh_add(ssh_key)
  ssh_key = ssh_key.to_s.to_pn.expand_path
  if ssh_key.file?
    already_present = "ssh-add".capture("-l").split("\n").any? do |e|
      e.split(/\s+/)[2] == ssh_key.to_s
    end

    if already_present
      "SSH key #{ssh_key.as_tok} is already present: skipping".pinf
    else
      "Adding SSH key #{ssh_key.as_tok}".pinf
      "ssh-add".run "#{ssh_key}",
                    interactive: true,
                    success_msg: "SSH key successfully added",
                    failure_msg: "Failed to add SSH key: skipping"
    end
  else
    true
  end
end

def gnome_keyring_unlock(pwd)
  unless pwd
    "Missing password for Gnome Keyring".perr
  else
    pwd.as_pwd!

    ENV["GNOME_KEYRING_PASSWORD"] = $config[:gnome_keyring][:pwd]
    status = "gnome-keyring-unlock".run interactive: true,
                                        success_msg: "Successfully unlocked gnome keyring",
                                        failure_msg: "Failed to unlock gnome keyring"
    ENV["GNOME_KEYRING_PASSWORD"] = nil

    status
  end
  true
end

# ──────────────────────────────────────────────────────────────────────────────
