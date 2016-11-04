require "shellwords"
require "pathname"
require "fileutils"
require "optionparser"

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

  def run(*args, dir: nil, msg: nil, verbose: true, simulate: false)
    simulate ||= $simulate

    cmd = "#{self}"
    unless args.empty?
      cmd << " "
      cmd << args.map { |arg| Shellwords.escape(arg.to_s.strip) }.join(" ")
    end

    status = false
    if dir
      FileUtils.cd(dir) do
        msg.pinf if msg
        if simulate
          status = "run command `#{cmd.as_tok}` (workdir: `#{dir.as_tok}`)".simulated.pinf
        else
          status = system(cmd)
        end
      end
    else
      msg.pinf if msg
      if simulate
        status = "run command `#{cmd.as_tok}`".simulated.pinf
      else
        status = system(cmd)
      end
    end

    if !simulate
      if status
        "command `#{cmd.as_tok}` successfully run".psuc if verbose
      else
        "command `#{cmd.as_tok}` failed to run".perr if verbose
      end
    end

    status
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

  # {{{ replication

  def build_script(to: nil, simulate: false)
    simulate ||= $simulate

    script_path = self.to_s.to_pn
    dst_path = to.to_s.to_pn unless to.nil?

    return "invalid script: not a valid file".perr unless script_path.file?

    "building script `#{script_path.as_tok}`".pinf

    hashbang    = "#!/usr/bin/env ruby"
    separator   = "# entry-point"
    sfw_data    = __FILE__.to_pn.read
    script_data = script_path.read
    dst_data    = "#{hashbang}\n\n#{sfw_data}\n\n#{separator}\n#{script_data}"

    "script successfully built".psuc

    perms = "555"
    if simulate
      if dst_path
        "wrote to `#{dst_path.as_tok}` (perms: #{perms.as_tok})".simulated.pinf
      end
    else
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

class Pathname
  include Shortcuts
end

class Array
  def do_all
    status = true

    self.each do |blk|
      break unless status
      status = blk.call
    end

    status
  end
end

def ensure_root
  if !(Process.euid == 0)
    "you need root privileges in order to build the kernel".perr exit_code: -1
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
