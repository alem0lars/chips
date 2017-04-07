# {{{ multimonitor configuration

# the allowed monitor roles
ALLOWED_ROLES = %i(internal external)

# the default setup info; it does nothing particular
DEF_SETUP_INFO = {
  eDP1: { role: :internal }
}

# }}}

# {{{ multimonitor utils

# filter `setup_info`, keeping only those having the provided `role`
def monitors_by_role(setup_info, role)
  roles = Array(role).map { |role| role.to_s }
  setup_info.find_all { |_, info| roles.include?(info[:role].to_s) }
end

def xrandr(output, *args)
  cmd = "xrandr"

  if $simulate
    "execute `#{cmd.as_tok}` against `#{output.as_tok}` with args: `#{args.as_tok}`".pinf
    cmd.run "--output", output, *args
  else
    cmd.run "--output", output, *args
  end
end

# }}}

setups_info = "multimonitor".get_config(default: { default: DEF_SETUP_INFO })

options = parse_args do |parser, options|
  parser.on("--name [NAME]", setups_info.keys,
            "select the setup (available: `#{setups_info.keys}`)") do |name|
    options[:setup_name] = name
  end
end

"xrandr".check_program

# 1. find setup name
setup_name = options[:setup_name]
# 2. validate setup info
unless options[:setup_name]
  setup_name = "select the setup (available: `#{setups_info.keys}`)".ask
end
setup_name = setup_name.to_sym
"invalid setup name".perr exit_code: -3 unless setups_info.has_key? setup_name
setup_info = setups_info[setup_name]
"using setup `#{setup_name.as_tok}`: `#{setup_info.as_tok}`".pinf
unless monitors_by_role(setup_info, ALLOWED_ROLES)
  "invalid role detected".perr(exit_code: -2)
end
unless monitors_by_role(setup_info, :internal).length == 1
  "exactly one internal monitor is needed".perr exit_code: -3
end
# 3. perform monitors setup
internal_monitor_name, _ = monitors_by_role(setup_info, :internal).first
monitors_by_role(setup_info, :external)
  .each { |n, _| xrandr(n, "--off") }
monitors_by_role(setup_info, :external)
  .each { |n, _| xrandr(n, "--auto") }
monitors_by_role(setup_info, :external)
  .select { |_, i| i[:position] }
  .each { |n, i| xrandr(n, "--#{i[:position]}-of", internal_monitor_name) }
monitors_by_role(setup_info, :external)
  .select { |_, i| i[:mode] }
  .each { |n, i| xrandr(n, "--mode", i[:mode]) }


# vim: set filetype=ruby :
