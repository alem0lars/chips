$config = "multimonitor".get_config(default: {
  profiles: {
    # The default setup info, it does nothing particular
    default: { eDP1: { role: :internal } }
  }
})

#
# Setup a monitor with all known information
#
def setup_monitor(name, info, exclude: [])
  exclude = exclude.map(&:to_s)

  kwargs = {}
  kwargs[:"--rotate"] = "normal"
  kwargs[:"--#{info[:position]}-of"] = $config[:internal_monitor_name] if info[:position]
  kwargs[:"--mode"] = info[:mode]
  if info[:scale]
    x, y = info[:mode].split("x").map{ |d| d.to_i }
    kwargs[:"--scale"] = "#{info[:scale]}x#{info[:scale]}"
    scaled_x = (x * info[:scale]).truncate
    scaled_y = (y * info[:scale]).truncate
    kwargs[:"--panning"] = "#{scaled_x}x#{scaled_y}"
  end

  kwargs.reject! { |k, v| exclude.include? k.to_s }

  if kwargs.empty?
    "skipping monitor #{name.as_tok} setup".pwrn
  else
    xrandr(name, **kwargs)
  end
end

#
# Filter `info`, keeping only those having the provided `role`
#
def monitors_by_role(info, roles)
  roles = Array(roles).map(&:to_s)
  info.find_all { |_, monitor| roles.include?(monitor[:role].to_s) }
end

#
# Run command `xrandr`
#
def xrandr(output, *args, **kwargs)
  cmd = "xrandr"

  xrandr_args = args
  kwargs.each { |k, v| xrandr_args += [k, v] if v }

  if $simulate
    "execute `#{cmd.as_tok}` against `#{output.as_tok}` with args: `#{args.as_tok}`".pinf
    cmd.run "--output", output, *xrandr_args, interactive: true
  else
    cmd.run "--output", output, *xrandr_args, interactive: true
  end
end

[
  -> () { # Check external requirements
    "xrandr".check_program!
  },
  -> () { # $config normalization
    # The allowed monitor roles
    allowed_roles = %i(internal external)

    # 1: Normalize `$config[:profiles]`
    $config[:profiles] ||= {}
    $config[:profiles].each do |name, info|
      "invalid role detected".perr unless monitors_by_role(info, allowed_roles)
      unless monitors_by_role(info, :internal).length == 1
        "exactly one internal monitor is needed".perr
      end
      info[:scale] = info[:scale].to_i if info[:scale]
      if info[:scale] && !info[:mode]
        "#{"mode".as_tok} is required if #{"scale".as_tok} is present".perr
      end
    end

    # 2: Parse options
    options = parse_args do |parser, opts|
      parser.on("--name [NAME]",
                "select the profile " +
                "(available: `#{$config[:profiles].keys}`)") do |name|
        opts[:selected_profile] = name if name
      end
    end

    # 3: Merge `options` <-> `$config`
    $config[:selected_profile_name] = $config[:default_profile_name] || options[:profile_name]

    # 4: Normalize `$config`
    # 4.2: Normalize `$config[:selected_profile_name]`
    if $config[:selected_profile_name]
      $config[:selected_profile_name] = $config[:selected_profile_name].to_sym
    end
    unless $config[:profiles].has_key? $config[:selected_profile_name]
      "invalid profile name".perr
    end
    # 4.3: Normalize `$config[:selected_profile]`
    $config[:selected_profile] = $config[:profiles][$config[:selected_profile_name]]
    # 4.4: Normalize `$config[:internal_monitor_name]`
    $config[:internal_monitor_name], _ = monitors_by_role($config[:selected_profile], :internal).first
    unless $config[:internal_monitor_name]
      "missing monitor with role #{"internal".as_tok}".perr
    end
    unless $config[:selected_profile].has_key? $config[:internal_monitor_name]
      "invalid setup name #{$config[:internal_monitor_name].as_tok}".perr
    end
    # 4.5: Normalize `$config[:internal_monitor]`
    $config[:internal_monitor] = $config[:selected_profile][$config[:internal_monitor_name]]
  },
  -> () { # Perform monitors setup
    "using profile `#{$config[:selected_profile_name].as_tok}`: `#{$config[:selected_profile].as_tok}`".pinf

    # Setup all monitors
    $config[:selected_profile]
      .each { |n, i| setup_monitor(n, i) }

    # Monitors that needs to be scaled, need to have settings re-applied
    # (without panning)
    $config[:selected_profile]
      .select { |_, i| i[:scale] }
      .each { |n, _| xrandr(n, "--off") }
    $config[:selected_profile]
      .select { |_, i| i[:scale] }
      .each { |n, i| setup_monitor(n, i, exclude: %w(--panning)) }
  }
].do_all auto_exit_code: true


# vim: set filetype=ruby :
