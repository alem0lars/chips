config = "spawn-web-apps".get_config

[
  -> () { # check external requirements
    $exit_code = 1
    "missing program `chromium`".perr unless "chromium".check_program
    true
  },
  -> () { # config normalization
    $exit_code = 2
    # normalize `config[:apps]`
    config[:apps] ||= []
    "no apps were specified".perr if config[:apps].empty?
    config[:apps].each_with_index do |app, idx|
      # normalize `app[:name]`
      app[:name] ||= ""
      "missing name for app at index #{idx.as_tok}".perr if app[:name].empty?
      # normalize `app[:profile]` and `app[:profile_dir]`
      if app[:profile] && app[:profile_dir]
        "cannot specify both #{profile.as_tok} and #{profile_dir.as_tok}".perr
      end
      # => `app[:profile]` -> `app[:profile_dir]`
      app[:profile_dir] = "~/.config/chromium/#{app[:profile]}" if app[:profile]
      app[:profile_dir] = app[:profile_dir].to_pn.expand_path
      "missing profile directory".perr unless app[:profile_dir].to_pn.directory?
      # => `app[:profile_dir]` -> `app[:profile]`
      app[:profile] ||= app[:profile_dir].basename
      "missing profile for app".perr if app[:profile].empty?

      # find and normalize `app[:manifest]` and `app[:id]`
      extensions_dir = app[:profile_dir].join("Extensions")
      manifests_pattern = extensions_dir.join("**", "manifest.json")
      manifests_info = Dir.glob(manifests_pattern).map do |manifest_file|
        manifest_file = manifest_file.to_pn
        manifest = JSON.parse(manifest_file.read).deep_symbolize_keys
        if manifest[:app] && manifest[:name] == app[:name]
          {
            manifest: manifest,
            id: manifest_file.relative_path_from(extensions_dir).dirname.dirname.basename
          }
        end
      end.compact
      "found #{manifests_info.length.as_tok} #{"!= 1".as_tok} apps matching #{app[:name].as_tok}".perr if manifests_info.length != 1
      manifest_info = manifests_info.first
      app[:manifest] = manifest_info[:manifest]
      app[:id] = manifest_info[:id]
    end

    true
  },
  -> () { # arguments normalization (errors: exit_code=3)
    $exit_code = 3
    _options = parse_args
  },
  -> () { # spawn web apps (errors: exit_code=4)
    $exit_code = 4
    config[:apps].each do |app|
      # 1: Find
      "spawning app #{app[:name].as_tok}".pinf
      "/usr/lib64/chromium-browser/chromium-launcher.sh".run(
        "--profile-directory=#{app[:profile]}",
        "--app-id=#{app[:id]}",
        detached: true
      )
    end
  }
].do_all


# vim: set filetype=ruby :
