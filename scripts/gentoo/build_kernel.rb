$config = {}

[ -> {
    ensure_root
  },
  -> {
    $config[:boot_dir] = "/boot".to_pn
    $config[:kernel_parent_dir] = "/usr/src".to_pn

    avail_kernels = Pathname.glob($config[:kernel_parent_dir].join("linux*")).
                             map { |kn| kn.basename }.
                             map(&:to_s).
                             sort

    options = parse_args do |parser, opts|
      parser.on("--kernel [KERNEL]", avail_kernels,
                "select the kernel (available: `#{avail_kernels}`)") do |kernel|
        opts[:kernel_name] = kernel
      end
    end

    $config[:kernel_dir] = $config[:kernel_parent_dir].join(
      options[:kernel_name] || "linux"
    ).realpath
    $config[:kernel_name] = $config[:kernel_dir].basename.gsub "linux-", ""

    true
  },
  -> {
    "make".run dir: $config[:kernel_dir],
               interactive: true,
               msg: "compiling.."
  },
  -> {
    "make".run "modules_install",
               dir: $config[:kernel_dir],
               interactive: true,
               msg: "installing kernel modules.."
  },
  -> {
    "make".run "install",
               dir: $config[:kernel_dir],
               interactive: true,
               msg: "installing kernel image.."
  },
  -> {
    "dracut".run "--force",
                 $config[:boot_dir].join("initrd-#{$config[:kernel_name]}"),
                 interactive: true,
                 msg: "generating the initramfs.."
  }
].do_all auto_exit_code: true


# vim: set filetype=ruby :
