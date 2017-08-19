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

  def is_running(**run_args)
    if "pgrep".check_program || "`pgrep` is needed".perr
      "pgrep".capture(self.to_s, **run_args).length > 0
    end
  end

  def run_if(condition, *args, **kwargs)
    if condition
      run(*args, **kwargs)
    else
      true
    end
  end

  def run(*args,
          dir: nil, msg: nil, verbose: true, quiet: false, simulate: false,
          detached: false, single: false, ignore_status: false, output: $stdout,
          interactive: false, retry_on_error: false)
    simulate ||= $simulate

    program_name = self.to_s
    cmd = program_name.dup
    pretty_cmd = program_name.dup
    unless args.empty?
      cmd << " "
      cmd << args.map do |arg|
        arg.to_s.strip.gsub(/(?:H-)+(.*)(?:-H)+/, '\1').escape
      end.join(" ")

      pretty_cmd << " "
      pretty_cmd << args.map do |arg|
        arg.to_s.strip.gsub(/(?:H-)+.*(?:-H)+/, "HIDDEN").escape
      end.join(" ")
    end

    status = false
    if single && program_name.is_running
      "command `#{pretty_cmd.as_tok}` is already running".pinf
      status = true
    else
      _run = lambda do |run_cmd|
        run_cmd << " 2>&1"

        begin
          status = if interactive
                     pid = Process.spawn(run_cmd)
                     if detached
                       if output != $stdout
                         "cannot redirect output in interactive program".perr
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
                         output.write(res) unless quiet
                       end
                       Process.detach(pid)
                       true
                     else
                       res = `#{run_cmd}`
                       output.write(res) unless quiet
                       $?.success?
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
            status = "run command `#{pretty_cmd.as_tok}` (workdir: `#{dir.as_tok}`)".simulated.pinf
          else
            _run.call(cmd)
          end
        end
      else
        msg.pinf if msg
        if simulate
          status = "run command `#{pretty_cmd.as_tok}`".simulated.pinf
        else
          _run.call(cmd)
        end
      end

      if !simulate
        if ignore_status || status
          "command `#{pretty_cmd.as_tok}` successfully run".psuc if verbose
        else
          "command `#{pretty_cmd.as_tok}` failed to run".perr if verbose
          if retry_on_error
            if "retry".ask type: :bool
              status = run(*args, dir: dir, msg: msg, verbose: verbose,
                           quiet: quiet, simulate: simulate, detached: detached,
                           single: single, ignore_status: ignore_status,
                           output: output, retry_on_error: retry_on_error)
            else
              status = false
            end
          end
        end
      end
    end

    ignore_status || status
  end

  def chperms(perms, simulate: false)
    simulate ||= $simulate

    if simulate
      "change permissions to: `#{perms}`".simulated.pinf
    else
      FileUtils.chmod(perms.to_s.to_i(8), self.to_s)
    end
  end

  # }}}

  # {{{ fs operations

  def filename
    Pathname.new(self.to_s).sub_ext("").basename.to_s
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
        "skipping invalid config at `#{config.as_tok}`".pwrn
      end
    end)

    env_var_name = "CFG_#{name.upcase}"
    if ENV.has_key?(env_var_name)
      begin
        config.merge!(JSON.parse(ENV[env_var_name]))
      rescue JSON::ParserError => _
        "skipping invalid config in the environment variable `#{env_var_name.as_tok}`".pwrn
      end
    end

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
          "downloading script `#{name.as_tok}` from `#{url.as_tok}`".pinf
          begin
            data = download(url)
          rescue ArgumentError => err # TODO add right errors
            return "failed to download `#{url.as_tok}`: #{err.message.as_tok}".perr
          end
          if dst_path.directory?
            dst_dir_path = dst_path
          else
            if dst_path.dirname.directory?
              dst_dir_path = dst_path.dirname
            else
              return "invalid destination path `#{to.as_tok}`".perr
            end
          end

          "script successfully downloaded".psuc

          dst_script_path = dst_dir_path.join(name.to_s)
          if simulate
            "wrote to `#{dst_script_path.as_tok}` (perms: #{perms.as_tok})".simulated.pinf
          else
            dst_script_path.delete if dst_script_path.file?
            IO.copy_stream(data, dst_script_path)
            dst_path.chperms perms
          end

          "script successfully installed".psuc
        end
      end
    else
      if script_path.filename.end_with?("-wrapper")
        program_name = script_path.filename.gsub(/-wrapper$/, "")
        unless program_name.check_program
          "missing program `#{program_name}`".perr exit_code: 1
        end
        "building wrapper for `#{program_name.as_tok}`".pinf
        dst_path = dst_path.dirname.join(program_name)
      else
        "building script `#{script_path.as_tok}`".pinf
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

      "script successfully built".psuc

      perms = "555"
      if simulate
        if dst_path
          "wrote to `#{dst_path.as_tok}` (perms: #{perms.as_tok})".simulated.pinf
        end
      else
        dst_path.delete if dst_path.file?
        dst_path.write dst_data if dst_path
        dst_path.chperms perms
      end

      "script successfully installed".psuc
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
  url = URI.encode(URI.decode(url))
  url = URI(url)
  raise Error, "url was invalid" if !url.respond_to?(:open)

  options = {}
  options["User-Agent"] = "MyApp/1.2.3"
  options[:content_length_proc] = ->(size) {
    if max_size && size && size > max_size
      raise Error, "file is too big (max is #{max_size})"
    end
  }

  downloaded_file = url.open(options)

  if downloaded_file.is_a?(StringIO)
    tempfile = Tempfile.new(basename, binmode: true)
    IO.copy_stream(downloaded_file, tempfile.path)
    downloaded_file = tempfile
    OpenURI::Meta.init downloaded_file, stringio
  end

  downloaded_file
rescue *DOWNLOAD_ERRORS => error
  raise if error.instance_of?(RuntimeError) && error.message !~ /redirection/
  raise Error, "download failed (#{url}): #{error.message}"
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
        status = "interrupted while running command".pwrn ask_continue: true
      end
    end

    status
  end

end

class Hash

  # extract `n` sample key/value pairs from the underlying `Hash`
  def sample(n=1)
    Hash[self.to_a.sample(n)]
  end

  # perform recursive merge of the current `Hash` (`self`) with the provided one
  # (the `second` argument)
  #
  # the merge have knows how to recurse in both `Hash`es and `Array`s
  def deep_merge(second)
    merger = proc do |key, v1, v2|
      if Hash === v1 && Hash === v2
        v1.merge(v2, &merger)
      elsif Array === v1 && Array === v2
        (Set.new(v1) + Set.new(v2)).to_a
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

# ensure the current process is running as `root`
def ensure_root
  if !(Process.euid == 0)
    "the script needs root privileges".perr exit_code: 255
  end
end

def uname
  `uname -r`
end

# parse commandline arguments
def parse_args(simulate_enabled: true)
  options = {}
  parser = OptionParser.new do |p|
    if simulate_enabled
      p.on("-s", "--[no-]simulate", "run in simulate mode") do |simulate|
        $simulate = options[:simulate] = simulate
        "running in `simulate` mode".pinf if $simulate
      end
    end

    yield(p, options) if block_given?

    p.on_tail("-h", "--help", "show this message") do
      puts p
      exit
    end
  end
  parser.parse!
  options[:parser] = parser
  def options.phelp
    self[:parser].to_s.pinf
  end
  options
end

# {{{ specific programs support

def lpass_logged_in?
  "lpass".run("status", verbose: false, quiet: true)
end

def lpass_sync
  "lpass".run "sync"
end

def lpass_login(user)
  "lpass".run "login", user
end

def lpass_show_pwd(id, **run_args)
  "lpass".capture "show", "--pass", "H-#{id.to_s}-H", **run_args
end

def openterm(cmd, run_if: true, title: nil, tmux: true)
  args  = []
  args += ["--title", title]
  args += [tmux ? "--tmux" : "--no-tmux"]
  unless cmd.nil? || cmd.empty?
    args << "--cmd"
    args << Array(cmd).map { |e| e.escape }.join(" ")
  end

  if run_if
    "openterm".run(*args, interactive: true)
  else
    true
  end

end

# }}}
