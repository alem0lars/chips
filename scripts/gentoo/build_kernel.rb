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

kernel_dir = kernel_parent_dir.join(options[:kernel_name] || "linux")
boot_dir   = "/boot".to_pn

[ -> { "make".run dir: kernel_dir, msg: "compiling.." },
  -> { "make".run "modules_install", dir: kernel_dir, msg: "installing kernel modules.." },
  -> { "make".run "install", dir: kernel_dir, msg: "installing kernel image.." },
  -> { "dracut".run "--force", boot_dir.join("initrd-#{uname}"), msg: "generating the initramfs.." }
].do_all


# vim: set filetype=ruby :
