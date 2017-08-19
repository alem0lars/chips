config = "gafs".get_config

[
  -> () { # config normalization
    # normalize `config[:archs]`
    config[:kvm] = config.key?(:kvm) ? config[:kvm] : false
    # normalize `config[:archs]`
    config[:archs] ||= %w(i386 x86_64)
    # normalize `config[:qemu_cmds]`
    config[:qemu_programs] = Hash[config[:archs].map do |arch|
      [arch, "qemu-system-#{arch}"]
    end.flatten]
  },
  -> () { # arguments normalization
    options = parse_args do |parser, opts|
      parser.on("-a", "--architecture ARCHITECTURE",
                "specify architecture " +
                "(available #{config[:archs].as_tok})") do |arch|
        if config[:archs].include? arch
          opts[:arch] = arch
        else
          ("invalid architecture #{arch.as_tok}: not included in " +
            config[:archs].as_tok).perr
        end
      end
    end

    config[:arch] = options[:arch]
  },
  -> () { # check external requirements
    config[:qemu_programs].each do |arch, program|
      unless req.check_program
        "missing program #{program.as_tok} for architecture #{arch.as_tok}".perr
      end
    end
    true
  },
  -> () {
    # TODO parse and compose config disk_path memory config_path create_vm
    if config[:create_vm]
      # TODO create image for VM: qemu-img create -f qcow2 -o backing_file=winxp.img test01.img
      program = config[:qemu_programs][config[:arch]]
      args = [
        config[:disk_path],
        "-m", config[:memory],
        "-readconfig", config[:config_path]
      ]
      args << "-enable-kvm" if config[:kvm]
      # TODO add arguments for disposable
    end

    program.run(*args, detached: true)

    # TODO ssh into vm
  }
].do_all auto_exit_code: true
