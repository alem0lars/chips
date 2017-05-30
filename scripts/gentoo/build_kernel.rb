ensure_root

kernel_parent_dir = "/usr/src".to_pn

avail_kernels = Pathname.glob(kernel_parent_dir.join("linux*")).
                         map { |kn| kn.basename }.
                         map(&:to_s).
                         sort

options = parse_args do |parser, options|
  parser.on("--kernel [KERNEL]", avail_kernels,
            "select the kernel (available: `#{avail_kernels}`)") do |kernel|
    options[:kernel_name] = kernel
  end
end
options[:kernel_dir] = kernel_parent_dir.join(options[:kernel_name] || "linux").realpath
options[:kernel_name] = options[:kernel_dir].basename.gsub "linux-", ""

boot_dir   = "/boot".to_pn

[ -> { "make".run dir: options[:kernel_dir], msg: "compiling.." },
  -> { "make".run "modules_install", dir: options[:kernel_dir], msg: "installing kernel modules.." },
  -> { "make".run "install", dir: options[:kernel_dir], msg: "installing kernel image.." },
  -> { "dracut".run "--force", boot_dir.join("initrd-#{options[:kernel_name]}"), msg: "generating the initramfs.." }
].do_all


# vim: set filetype=ruby :
