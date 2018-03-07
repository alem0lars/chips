# ───────────────────────────────────────────────────────────────── Utilities ──

def report_name(scanner_name, target, extension)
  now = Time.now.strftime("%Y.%m.%d-%H.%M.%S")
  "report|scanner=#{scanner_name}|target=#{target}|date=#{now}.#{extension}".gsub(/[\/]/, "")
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
  -> () { "tmux".check_program! },
  -> () { "docker".check_program! },
  -> () { # Parse config
    $config = "spawn-va".get_config || {}

    $config[:targets] ||= {}
    $config[:default_scanners_config] ||= {}
    $config[:supported_scanners] = %i[
      nikto
      wpscan
      droopescan
      sqlmap
      golismero
      metasploit
      arachni
      wapiti
    ]

    true
  },
  -> () { # Parse options
    $options = parse_args(mandatory: %i(targets output_dir)) do |parser, opts|
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
  },
  -> () { # Normalize config
    if $options[:scanners]
      $options[:scanners] = $options[:scanners].map { |s| s.to_sym }
      $options[:scanners].each do |scanner|
        unless $config[:supported_scanners].include? scanner
          "Invalid scanner #{scanner.as_tok}: not supported".perr exit_code: 1
        end
      end
    end

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
        dir_name = "spawn-va|target=#{target}|scanner=#{scanner}".gsub(/[\/]/, "")
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
        "#{"nikto".as_tok} has been spawned for #{target.as_tok}".psuc
      end

      if scanners[:wapiti][:enabled]
        config = scanners[:wapiti]
        extension = config[:format] || "unknown"
        session_name(:wapiti, target).tmux "docker", "run",
          "-it",
          "--rm",
          "--mount", "type=bind,source=#{config[:output_dir]},target=/boot",
          "k0st/alpine-wapiti",
          target,
          "-f".arg_valued(config[:format]),
          "-o", "/boot".to_pn.join(report_name(:wapiti, target, extension)),
          interactive: true,
          detached: true,
          manual_exit: true
        "#{"wapiti".as_tok} has been spawned for #{target.as_tok}".psuc
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
          "--random-agent".arg_if(config[:random_agent]),
          "--log", "/boot".to_pn.join(report_name(:wpscan, target, :txt)),
          interactive: true,
          detached: true,
          manual_exit: true
        "#{"wpscan".as_tok} has been spawned for #{target.as_tok}".psuc
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
        "#{"golismero".as_tok} has been spawned for #{target.as_tok}".psuc
      end

      if scanners[:droopescan][:enabled]
        config = scanners[:droopescan]
        session_name(:droopescan, target).tmux "docker", "run",
          "-it",
          "--rm",
          "--mount", "type=bind,source=#{config[:output_dir]},target=/boot",
          "alem0lars/droopescan",
          "scan",
          "-u", target,
          "-o", "json",
          interactive: true,
          detached: true,
          manual_exit: true
        "#{"droopescan".as_tok} has been spawned for #{target.as_tok}".psuc
      end

      if scanners[:sqlmap][:enabled]
        config = scanners[:sqlmap]

        session_name(:sqlmap, target).tmux "docker", "run",
          "-it",
          "--rm",
          "--mount", "type=bind,source=#{config[:output_dir]},target=/boot",
          "k0st/alpine-sqlmap",
          # Targets
          case target
          when /^log:/i     then "-l".arg_valued(target)
          when /^sitemap:/i then "-x".arg_valued(target)
          when /^bulk:/i    then "-m".arg_valued(target)
          else                   "-u".arg_valued(target)
          end,
          # Request
          "--method".arg_valued(config[:method]),
          "--data".arg_valued(
            config[:data],
            also: config[:method] =~ /get/i,
            warn: "Parameter #{"data".as_tok} isn't compatible " +
                  "with #{"method=get".as_tok}"),
          "--param-del".arg_valued(config[:params_delimiter]),
          "--random-agent".arg_if(
            config[:user_agent],
            also: config[:user_agent] == "random",
            otherwise: "--user-agent".arg_valued(config[:user_agent])),
          "--cookie".arg_valued(config[:cookie]),
          "--load-cookies".arg_valued(config[:cookie_file]),
          "--cookie-del".arg_valued(
            config[:cookie_delimiter],
            also: config[:cookie] || config[:cookie_file],
            warn: "Parameter #{"cookie-del".as_tok} has been specified " +
                  "but #{"cookie".as_tok} is missing"),
          "--drop-set-cookie".arg_if(config[:drop_set_cookie]),
          "--host".arg_valued(config[:host]),
          "--referer".arg_valued(config[:referer]),
          "--headers".arg_valued(config[:headers], format: -> (headers) {
            headers.is_a?(Array) ? headers.join("\n") : headers
          }),
          # Injection
          "-p".arg_valued(config[:params], format: -> (params) {
            params.is_a?(Array) ? params.join(",") : params
          }),
          "--prefix".arg_valued(config[:prefix]),
          "--suffix".arg_valued(config[:suffix]),
          # Detection
          "--level".arg_valued(config[:level]),
          "--risk".arg_valued(config[:risk]),
          # Fingerprint
          "-f".arg_if(config[:fingerprint]),
          # Enumeration
          "-a",
          # Brute-force
          "--common-tables",
          "--common-columns",
          # User-defined function injection
          # TODO
          # File-system access
          # TODO
          # OS access
          # TODO
          # Windows registry access
          # TODO
          # Verbosity
          "-v".arg_valued(config[:verbosity]),
          interactive: true,
          detached: true,
          manual_exit: true
        "#{"sqlmap".as_tok} has been spawned for #{target.as_tok}".psuc
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
      "A generic #{"msfconsole".as_tok} has been spawned with RHOSTS=#{targets_for_service(:metasploit).keys.join(",").as_tok}".psuc
    end

    # TODO at the moment doesn't run the command, instead it should do!
    return "not implemented yet" unless targets_for_service(:arachni).empty?
=begin
    unless targets_for_service(:arachni).empty?
      # config_dir = $config[:output_dir].join("arachni", "config")
      # config_dir.mkpath
      # data_dir = $config[:output_dir].join("arachni", "data")
      # data_dir.mkpath

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
=end

    true
  }
].do_all auto_exit_code: true
