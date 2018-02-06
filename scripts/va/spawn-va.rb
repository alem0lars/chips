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
  $config[:targets][target][scanner] = default_config.deep_merge($config[:targets][target][scanner] || {})
  unless scanner.check_program || $simulate
    "skipping scanner #{scanner.as_tok}: program not found".pwrn ask_continue: true
    $config[:targets][target][scanner][:enabled] = false
  end
end

# ─────────────────────────────────────────────────────────────── Entry-Point ──

[
  -> () {
    # Parse config.
    $config = "spawn-va".get_config || {}

    $config[:supported_scanners] = %i(nikto wpscan golismero)
    $config[:targets] ||= {}
    $config[:default_scanners_config] ||= {}

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
          config[:enabled] = $options[:scanners].include? scanner
        end
      end
    end

    $config[:output_dir] = Pathname.new($options[:output_dir])
    $config[:output_dir].mkpath

    true
  },
  -> () { # Perform VA
    $config[:targets].each do |target, config|
      if config[:nikto][:enabled]
        extension = config[:nikto][:format] || "unknown"
        "nikto".run "-h", target,
                    "-Cgidirs",
                    "-plugins".arg_valued(config[:nikto][:plugins]),
                    "-evasion".arg_valued(config[:nikto][:evasion]),
                    "-mutate".arg_valued(config[:nikto][:mutate]),
                    "-tuning".arg_valued(config[:nikto][:tuning]),
                    "-update".arg_if(config[:nikto][:update]),
                    "-F".arg_valued(config[:nikto][:format]),
                    "-output", report_name(:nikto, target, extension),
                    interactive: true
      end

      if config[:wpscan][:enabled]
        "docker".run "run", "-it", "--rm", "wpscanteam/wpscan",
                     "--url", target,
                     "--wordlist".arg_valued(config[:wpscan][:wordlist]),
                     "--log", report_name(:wpscan, target, :txt),
                     interactive: true
      end

      if config[:golismero][:enabled]
        "golismero".run "scan", target,
                        "-o", report_name(:golismero, target, :json),
                        interactive: true
      end
    end

    true
  }
].do_all
