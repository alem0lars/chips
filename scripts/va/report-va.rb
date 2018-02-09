[
  -> () { "texliveonfly".check_program },
  -> () { "latexmk".check_program },
  -> () { # Parse config
    $config = "report-va".get_config || {}
  },
  -> () { # Parse options
    $options = parse_args(mandatory: %i(template context output)) do |parser, opts|
      parser.on("-t", "--template TEMPLATE",
                "Template file for generating the report") do |template|
        opts[:template] = template
      end

      parser.on("-r", "--resources RESOURCES",
                "Directory that holds the report resources") do |resources|
        opts[:resources] = resources
      end

      parser.on("-c", "--context CONTEXT",
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
    $config[:resources_dir] = $options[:resources].to_pn if $options[:resources]
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
        if $config[:resources_dir]
          if $config[:resources_dir].directory?
            "Using resources directory at path #{$config[:resources_dir].as_tok}".pinf
          else
            "Invalid resources directory at path #{config[:resources_dir].as_tok}: not a directory".perr
          end
        else
          "No resources will be available for use inside the report".pwrn
          true
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
          if "Path for output file #{$config[:output_file].as_tok} already exists".pwrn ask_continue: true
            $config[:output_file].rmtree
            "Report will be generated at path #{$config[:output_file].as_tok}".pinf
          else
            "Invalid report path #{$config[:output_file].as_tok}: already exists".perr
          end
        else
          "Report will be generated at path #{$config[:output_file].as_tok}".pinf
        end
      }
    ].do_all
  },
  -> () {
    Dir.mktmpdir("report-va-") do |tmp_dir|
      tmp_dir = tmp_dir.to_pn
      return [
        -> () {
          render_dir($config[:template_dir],
                     tmp_dir,
                     context: { context: $config[:context] },
                     templatized_regex: /\.tex$/,
                     verbose: true)
        },
        -> () {
          render_dir($config[:resources_dir],
                     tmp_dir.join("resources"),
                     verbose: true)
        },
        -> () {
          tmp_dir.cd do
            "latexmk".run "-pdf", "-xelatex",
                          "-latexoption=-shell-escape",
                          tmp_dir.join("main.tex"),
                          interactive: true
          end
        },
        -> () {
          FileUtils.cp(tmp_dir.join("main.pdf"), $config[:output_file])
          "Created output report at #{$config[:output_file].as_tok}".psuc
          true
        }
      ].do_all
    end
  }
].do_all auto_exit_code: true
