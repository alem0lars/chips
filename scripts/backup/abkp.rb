config = "abkp".get_config

_ = parse_args

[ -> () { # check external requirements
    "missing program `attic`".perr exit_code: 1 unless "attic".check_program
    true
  },
  -> () { # config normalization
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
  -> () { # perform backup
    config[:backups].each do |backup|
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
                  *excludes
      "attic".run "prune",
                  "-v",
                  repo,
                  "-d", keep[:daily],
                  "-w", keep[:weekly],
                  "-m", keep[:monthly]
    end
    true
  }
].do_all

# vim: set filetype=ruby :
