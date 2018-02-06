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
    default_config = $config[:default_scanners_config]
  end

  $config[:targets][target] = {}

  $config[:targets][target][scanner] = default_config.deep_merge($config[:targets][target][scanner] || {})
  if scanner.check_program
    unless $config[:targets][target][scanner][:enabled]
      $config[:targets][target].delete(scanner)
    end
  else
    "skipping scanner #{scanner.as_tok}: program not found".pwrn ask_continue: true
    $config[:targets][target][scanner][:enabled] = false
  end
end

# ─────────────────────────────────────────────────────────────── Entry-Point ──

[
  -> () {
    # Parse config.
    $config = "spawn-va".get_config || {}

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
      parser.on("-o", "--output-dir OUTPUT_DIR",
                "Output directory where reports should be saved") do |out_dir|
        opts[:output_dir] = out_dir
      end
    end

    # Check required arguments.
    "invalid output directory".perr exit_code: 1 unless $options[:output_dir]
    "invalid targets".perr exit_code: 1 unless $options[:targets]

    true
  },
  -> () { # Normalize config
    $options[:targets].each do |target|
      fill_config! :nikto, target
      fill_config! :wpscan, target
    end

    $config[:output_dir] = Pathname.new($options[:output_dir])
    $config[:output_dir].mkpath

    true
  },
  -> () { # Perform VA
    puts $config
    $config[:targets].each do |target, config|
      if config[:nikto][:enabled]
        extension = config[:nikto][:format] || "unknown"
        "nikto".run "-h", target,
                    "-Cgidirs",
                    "-plugins".arg_values(config[:nikto][:plugins]),
                    "-evasion".arg_valued(config[:nikto][:evasion]),
                    "-mutate".arg_valued(config[:nikto][:mutate]),
                    "-tuning".arg_valued(config[:nikto][:tuning]),
                    "-update".arg_if(config[:nikto][:update]),
                    "-F".arg_valued(config[:nikto][:format]),
                    "-output", report_name("nikto", target, extension)
      end

      if config[:wpscan][:enabled]
        "wpscan".run "--url", target
      end
    end

    true
  }
].do_all
