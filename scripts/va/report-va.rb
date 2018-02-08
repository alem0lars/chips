
[
  -> () { # Parse config
    $config = "report-va".get_config || {}
  },
  -> () { # Parse options
    $options = parse_args(mandatory: %i(template context output)) do |parser, opts|
      parser.on("-t", "--template TEMPLATE",
                "Template file for generating the report") do |template|
        opts[:template] = template
      end
      parser.on("-d", "--context CONTEXT",
                "Context to be used as template's context") do |context|
        opts[:context] = context
      end
      parser.on("-o", "--output OUTPUT",
                "Path for the generated report") do |output|
        opts[:output] = output
      end
    end
  },
  -> () { # Normalize config
    $config[:template_dir] = $options[:template].to_pn
    $config[:context_file] = $options[:context].to_pn
    $config[:output_file] = $options[:output].to_pn

    [
      -> () {
        if $config[:template_dir].directory?
          "Using template directory at path #{$config[:template_dir].as_tok}".pinf
        else
          "Invalid template directory at path #{config[:template_dir].as_tok}: not a directory".perr
        end
      },
      -> () {
        if $config[:context_file].file?
          "Using context at path #{$config[:context_file].as_tok}".pinf
        else
          "Invalid context at path #{config[:context_file].as_tok}: not a file".perr
        end
      },
      -> () {
        $config[:context] = YAML.load_file($config[:context_file]).deep_symbolize_keys
        if $config[:context]
          "Successfully loaded context (length=#{$config[:context].length.to_s.as_tok})".pinf
        else
          "Failed to load context at path #{$config[:context_file]}".perr
        end
      },
      -> () {
        if $config[:output_file].exist?
          "Invalid report path #{config[:output_file].as_tok}: already exists".perr
        else
          "Report will be generated at path #{$config[:output_file].as_tok}".pinf
        end
      }
    ].do_all
  },
  -> () {
    Dir.mktmpdir("report-va-") do |tmp_dir|
      tmp_dir = tmp_dir.to_pn
      return render_dir($config[:template_dir],
                        { context: $config[:context] },
                        tmp_dir,
                        templatized_regex: /\.tex$/,
                        verbose: true)
    end
  }
].do_all auto_exit_code: true
