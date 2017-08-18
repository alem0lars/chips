config = "abkp".get_config

[
  -> () { # check external requirements (errors: exit_code=1)
    "missing program `attic`".perr exit_code: 1 unless "attic".check_program
    true
  },
  -> () { # config normalization (errors: exit_code=2)
    # normalize `config[:remote]`
    config[:remote] ||= {}
    config[:remote][:username] ||= ENV["USER"]
    config[:remote][:host] ||= "localhost"
    # normalize `config[:excludes]`
    config[:excludes] ||= %w(*.pyc *.svn *.git)
    # normalize `config[:keep]`
    config[:keep] ||= {}
    config[:keep][:daily] ||= 7
    config[:keep][:weekly] ||= 4
    config[:keep][:monthly] ||= 6

    config[:backups] ||= []
    config[:backups].each do |backup|
      # normalize `backup[:excludes]`
      backup[:excludes] ||= []
      # normalize `backup[:dir]`
      "missing backup directory".perr exit_code: 2 unless backup[:dir]
      backup[:dir] = backup[:dir].to_pn
      unless backup[:dir].directory?
        "directory #{backup[:dir]} doesn't exist".perr  exit_code: 2
      end
      # normalize `backup[:keep]`
      backup[:keep] ||= {}
      # normalize `backup[:repo]`
      "missing backup repository".perr exit_code: 2 unless backup[:repo]
      # normalize `backup[:name]`
      "missing backup name".perr exit_code: 2 unless backup[:name]
      # normalize `backup[:archive_name]`
      unless backup[:archive_name]
        hostname = `hostname`.strip
        backup[:archive_name] = "#{hostname}-#{backup[:name]}-#{Time.now.strftime("%Y-%m-%d-%H-%M")}"
      end
    end
    true
  },
  -> () { # arguments normalization (errors: exit_code=3)
    avail_backup_names = config[:backups].map { |backup| backup[:name] }

    options = parse_args do |parser, opts|
      parser.on("--only x,y,z", Array,
                "perform only specific backups " +
                "(available: `#{avail_backup_names}`)") do |backup_names|
                  if backup_names.all? { |bn| avail_backup_names.include?(bn) }
                    opts[:backup_names] = backup_names
                  else
                    "invalid backup names".perr
                  end
                end
    end

    config[:selected_backup_names] = options[:backup_names] || avail_backup_names
  },
  -> () { # perform backup (errors: exit_code=4)
    if "perform backups #{config[:selected_backup_names].as_tok}".ask type: :bool
      config[:backups].each do |backup|
        if config[:selected_backup_names].include? backup[:name]
          "performing backup #{backup[:name].as_tok}".pinf
          excludes = (config[:excludes] + backup[:excludes])
            .compact
            .uniq
            .inject([]) { |acc, exclude| acc + ["-e", exclude] }

          repo = "#{config[:remote][:username]}@#{config[:remote][:host]}:#{backup[:repo]}"
          archive = "#{repo}::#{backup[:archive_name]}"

          keep = backup[:keep].deep_merge(config[:keep])

          "attic".run "create",
            "--stats",
            archive,
            backup[:dir],
            *excludes,
            interactive: true,
            retry_on_error: true

          "attic".run "prune",
            "-v",
            repo,
            "-d", keep[:daily],
            "-w", keep[:weekly],
            "-m", keep[:monthly],
            interactive: true,
            retry_on_error: true
        end
      end
    end
    true
  }
].do_all

# vim: set filetype=ruby :
