ensure_root

options = parse_args

[ -> { "eix-sync".run "-q", msg: "synchronizing.." },
  -> { "emerge".run "--update", "--newuse", "--deep", "--with-bdeps=y",
                    "@world", "@system",
                    msg: "updating packages.." },
  -> { "emerge".run "--depclean", msg: "cleaning unused dependencies.." },
  -> { "revdep-rebuild".run msg: "rebuilding reverse dependencies.." },
  -> { "python-updater".run msg: "updating python packages.." },
  -> { "haskell-updater".run msg: "updating haskell packages.." },
  -> { "perl-cleaner".run "--all", msg: "rebuilding perl packages.." }
].do_all


# vim: set filetype=ruby :
