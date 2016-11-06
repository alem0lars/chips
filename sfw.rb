require "fileutils"
require "json"
require "mkmf"
require "optionparser"
require "pathname"
require "shellwords"

MakeMakefile::Logging.instance_variable_set(:@logfile, File::NULL)

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

  def ask(type: :string)
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
          ask question, type: type
        end
      when :string
        if answer.empty?
          "empty answer".pwrn
          ask question, type: type
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

  def perr(exit_code: nil)
    puts self.to_s.red.prefixed(" ! ".black.bg_red)
    exit(exit_code) unless exit_code.nil?
    return false
  end

  def pwrn(ask_continue: false)
    puts self.to_s.yellow.prefixed(" W ".black.bg_yellow)
    exit(-1) if ask_continue && !"continue".ask
    return false
  end

  # }}}

  # {{{ type conversion

  def to_pn
    Pathname.new self.to_s
  end

  # }}}

  # {{{ execution

  def check_program
    find_executable0(self.to_s)
  end

  def is_running
    if "pgrep".check_program || "`pgrep` is needed".perr
      `pgrep #{self.to_s}`.strip.length > 0
    end
  end

  def run(*args,
          dir: nil, msg: nil, verbose: true, quiet: false, simulate: false,
          detached: false, single: false, ignore_status: false)
    simulate ||= $simulate

    out = quiet ? File::NULL : $stdout
    err = quiet ? File::NULL : $stderr

    cmd = self.to_s
    pretty_cmd = cmd.dup
    unless args.empty?
      cmd << " "
      cmd << args.map do |arg|
        arg.to_s.strip.gsub(/<HIDDEN>(.+)<\/HIDDEN>/, '\1').escape
      end.join(" ")

      pretty_cmd << " "
      pretty_cmd << args.map do |arg|
        arg.to_s.strip.gsub(/\<HIDDEN\>.+\<\/HIDDEN\>/, "HIDDEN").escape
      end.join(" ")
    end

    status = false
    if single && cmd.is_running
      "command `#{pretty_cmd.as_tok}` is already running".pinf
    else
      cmd << " &" if detached

      if dir
        FileUtils.cd(dir) do
          msg.pinf if msg
          if simulate
            status = "run command `#{pretty_cmd.as_tok}` (workdir: `#{dir.as_tok}`)".simulated.pinf
          else
            status = system(cmd, out: out, err: err)
          end
        end
      else
        msg.pinf if msg
        if simulate
          status = "run command `#{pretty_cmd.as_tok}`".simulated.pinf
        else
          status = system(cmd, out: out, err: err)
        end
      end

      if !simulate
        if ignore_status || status
          "command `#{pretty_cmd.as_tok}` successfully run".psuc if verbose
        else
          "command `#{pretty_cmd.as_tok}` failed to run".perr if verbose
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
      rescue JSON::ParserError => err
        "skipping invalid config at `#{config.as_tok}`".pwrn
      end
    end)

    env_var_name = "CFG_#{name.upcase}"
    if ENV.has_key?(env_var_name)
      begin
        config.merge!(JSON.parse(ENV[env_var_name]))
      rescue JSON::ParserError => err
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

    return "invalid script: not a valid file".perr unless script_path.file?

    "building script `#{script_path.as_tok}`".pinf

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

    return dst_data
  end

  # }}}

end

class String

  include Shortcuts

end

class Symbol

  include Shortcuts

end

class Pathname

  include Shortcuts

end

class Array

  include Shortcuts

  def do_all
    status = true

    self.each do |blk|
      break unless status
      status = blk.call
    end

    status
  end

end

class Hash

  include Shortcuts

  # Extract `n` sample key/value pairs from the underlying `Hash`.
  def sample(n=1)
    Hash[self.to_a.sample(n)]
  end

  # Perform recursive merge of the current `Hash` (`self`) with the provided one
  # (the `second` argument).
  #
  # The merge have knows how to recurse in both `Hash`es and `Array`s.
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

  # Return a new `Hash` with all keys converted to `String`s.
  def deep_stringify_keys
    deep_transform_keys{ |key| key.to_s }
  end

  # Destructively convert all keys to `String`s.
  def deep_stringify_keys!
    deep_transform_keys!{ |key| key.to_s }
  end

  # Return a new `Hash` with all keys converted to `Symbol`s, as long as they
  # respond to `to_sym`.
  def deep_symbolize_keys
    deep_transform_keys{ |key| key.to_sym rescue key }
  end

  # Destructively convert all keys to `Symbol`s, as long as they respond to
  # `to_sym`.
  def deep_symbolize_keys!
    deep_transform_keys!{ |key| key.to_sym rescue key }
  end

  # Return a new `Hash` with all keys converted by the block operation.
  def deep_transform_keys(&block)
    deep_transform_keys_in_object(self, &block)
  end

  # Destructively convert all keys by using the block operation.
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

def ensure_root
  if !(Process.euid == 0)
    "the script needs root privileges".perr exit_code: -1
  end
end

def uname
  `uname -r`
end

def parse_args(simulate_enabled: true)
  options = {}
  OptionParser.new do |parser|
    if simulate_enabled
      parser.on("-s", "--[no-]simulate", "Run in simulate mode") do |simulate|
        $simulate = options[:simulate] = simulate
        "running in `simulate` mode".pinf if $simulate
      end
    end

    yield(parser, options) if block_given?

    parser.on_tail("-h", "--help", "Show this message") do
      puts parser
      exit
    end
  end.parse!
  options
end