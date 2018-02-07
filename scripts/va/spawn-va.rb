# ───────────────────────────────────────────────────────────────── Utilities ──

def report_name(scanner_name, target, extension)
  now = Time.now.strftime("%Y.%m.%d-%H.%M.%S")
  "report|scanner=#{scanner_name}|target=#{target}|date=#{now}.#{extension}"
end

def fill_config!(scanner, target)
  target = target.to_s.to_sym

  if block_given?
    default_config = yield
  else
    default_config = $config[:default_scanners_config][scanner] || {}
  end

  $config[:targets][target] ||= {}
  $config[:targets][target][scanner] = default_config.deep_merge(
    $config[:targets][target][scanner] || {})
end

def targets_for_service(service_name)
  $config[:targets].select do |target, services|
    services.any? do |service, config|
      service == service_name && config[:enabled]
    end
  end
end

def session_name(service, target=nil)
  elems = []
  elems << ($config[:prefix] || "spawnva")
  elems << service
  elems << target if target
  elems.join("-")
end

# ─────────────────────────────────────────────────────────────── Entry-Point ──

[
  -> () { "tmux".check_program },
  -> () { "docker".check_program },
  -> () {
    # Parse config.
    $config = "spawn-va".get_config || {}

    $config[:targets] ||= {}
    $config[:default_scanners_config] ||= {}
    $config[:supported_scanners] = %i[
      nikto
      wpscan
      golismero
      metasploit
      arachni
    ]

    true
  },
  -> () {
    # Parse options.
    $options = parse_args do |parser, opts|
      parser.on("-t", "--targets x,y,z", Array,
                "Perform VA scan to provided targets") do |targets|
        opts[:targets] = targets
      end

      parser.on("-n", "--scanners x,y,z", Array,
                "Run only the specified scanners " +
                "(available: #{$config[:supported_scanners].as_tok})") do |s|
        opts[:scanners] = s
      end

      parser.on("-o", "--output-dir OUTPUT_DIR",
                "Output directory where reports should be saved") do |out_dir|
        opts[:output_dir] = out_dir
      end

      parser.on("-p", "--prefix PREFIX",
                "Prefix to use for tmux sessions") do |prefix|
        opts[:prefix] = prefix
      end
    end

    # Check required arguments.
    "invalid output directory".perr exit_code: 1 unless $options[:output_dir]
    "invalid targets".perr exit_code: 1 unless $options[:targets]
    if $options[:scanners]
      $options[:scanners] = $options[:scanners].map { |s| s.to_sym }
      $options[:scanners].each do |scanner|
        unless $config[:supported_scanners].include? scanner
          "Invalid scanner #{scanner.as_tok}: not supported".perr exit_code: 1
        end
      end
    end

    true
  },
  -> () { # Normalize config
    $options[:targets].each do |target|
      $config[:supported_scanners].each do |scanner|
        fill_config! scanner, target
      end
    end

    if $options[:scanners]
      $config[:targets].each do |target, scanners|
        scanners.each do |scanner, config|
          unless config[:enabled] == false # explicit `false` forces disable
            config[:enabled] = $options[:scanners].include? scanner
          end
        end
      end
    end

    $config[:output_dir] = Pathname.new($options[:output_dir])
    $config[:output_dir].mkpath

    $config[:targets].each do |target, scanners|
      scanners.each do |scanner, config|
        dir_name = "spawn-va|target=#{target}|scanner=#{scanner}"
        config[:output_dir] = $config[:output_dir].join(dir_name)
      end
      scanners.select { |s, c| c[:enabled] }.each do |scanner, config|
        config[:output_dir].mkpath
      end
    end

    $config[:prefix] = $options[:prefix]

    true
  },
  -> () { # Perform VA
    $config[:targets].each do |target, scanners|
      if scanners[:nikto][:enabled]
        config = scanners[:nikto]
        extension = config[:format] || "unknown"
        session_name(:nikto, target).tmux "docker", "run",
          "-it",
          "--rm",
          "--mount", "type=bind,source=#{config[:output_dir]},target=/boot",
          "frapsoft/nikto",
          "-host", target,
          "-Cgidirs",
          "-plugins".arg_valued(config[:plugins]),
          "-evasion".arg_valued(config[:evasion]),
          "-mutate".arg_valued(config[:mutate]),
          "-tuning".arg_valued(config[:tuning]),
          "-update".arg_if(config[:update]),
          "-F".arg_valued(config[:format]),
          "-output", "/boot".to_pn.join(report_name(:nikto, target, extension)),
          interactive: true,
          detached: true,
          manual_exit: true
      end

      if scanners[:wpscan][:enabled]
        config = scanners[:wpscan]
        session_name(:wpscan, target).tmux "docker", "run",
          "-it",
          "--rm",
          "--mount", "type=bind,source=#{config[:output_dir]},target=/boot",
          "wpscanteam/wpscan",
          "--url", target,
          "--wordlist".arg_valued(config[:wordlist]),
          "--log", "/boot".to_pn.join(report_name(:wpscan, target, :txt)),
          interactive: true,
          detached: true,
          manual_exit: true
      end

      if scanners[:golismero][:enabled]
        config = scanners[:golismero]
        session_name(:golismero, target).tmux "docker", "run",
          "-it",
          "--rm",
          "--mount", "type=bind,source=#{config[:output_dir]},target=/boot",
          "jsitech/golismero",
          "scan", target,
          "-o", "/boot".to_pn.join(report_name(:golismero, target, :json)),
          interactive: true,
          detached: true,
          manual_exit: true
      end
    end

    unless targets_for_service(:metasploit).empty?
      config_dir = $config[:output_dir].join("metasploit", "config")
      config_dir.mkpath
      data_dir = $config[:output_dir].join("metasploit", "data")
      data_dir.mkpath

      session_name(:metasploit).tmux "docker", "run",
        "-it",
        "--rm",
        "-p", "433:433",
        "-v", "/root/.msf4:#{config_dir}",
        "-v", "/tmp/data:#{data_dir}",
        "remnux/metasploit",
        "/bin/bash", "-c", [
          "source /usr/local/rvm/scripts/rvm",
          "/etc/init.d/postgresql start",
          "/opt/msf/msfupdate --git-branch master",
          "msfconsole -x 'set RHOSTS #{targets_for_service(:metasploit).keys.join(" ")}'",
        ].join("; "),
        interactive: true,
        detached: true,
        manual_exit: true
    end

    unless targets_for_service(:arachni).empty?
=begin
      config_dir = $config[:output_dir].join("arachni", "config")
      config_dir.mkpath
      data_dir = $config[:output_dir].join("arachni", "data")
      data_dir.mkpath
=end

      session_name(:arachni).tmux "docker", "run",
        "-it",
        "--rm",
        "-p", "222:22",
        "-p", "7331:7331",
        "arachni/arachni",
        interactive: true,
        detached: true,
        manual_exit: true
    end

    true
  }
].do_all
