require "tmpdir"

options = parse_args do |parser, options|
  parser.on("-i",
            "--input-file INPUT_FILE",
            "Input pkcs12 file with password") do |input_file|
    options[:input_file] = input_file
  end

  parser.on("-o",
            "--output-file OUTPUT_FILE",
            "Input pkcs12 file without password") do |output_file|
    options[:output_file] = output_file
  end
end

at_exit { options[:tmp_dir].rmtree if options[:tmp_dir] }

[
  -> {
    status   = options[:input_file]  || "invalid input file".perr
    status &&= options[:output_file] || "invalid output file".perr
    status ||= options.phelp && false
  },
  -> {
    options[:tmp_dir] = Dir.mktmpdir.to_pn
    options[:tmp_pwd] = "TemporaryPassword"
    options[:tmp_cert_file] = options[:tmp_dir].join("certificate.crt")
    options[:tmp_ca_file] = options[:tmp_dir].join("ca-cert.ca")
    options[:tmp_key_file] = options[:tmp_dir].join("priv.key")
    options[:tmp_key_pwdless_file] = options[:tmp_dir].join("priv-nopwd.key")
    options[:tmp_pem_file] = options[:tmp_dir].join("pem.pem")
  },
  -> {
    options[:pwd] = "prompt password".ask allow_empty: true
    true
  },
  -> {
    "openssl".run "pkcs12", "-clcerts", "-nokeys",
                  "-in", options[:input_file],
                  "-out", options[:tmp_cert_file],
                  "-password", "pass:#{options[:pwd]}",
                  "-passin", "pass:#{options[:pwd]}"
  },
  -> {
    "openssl".run "pkcs12", "-cacerts", "-nokeys",
                  "-in", options[:input_file],
                  "-out", options[:tmp_ca_file],
                  "-password", "pass:#{options[:pwd]}",
                  "-passin", "pass:#{options[:pwd]}"
  },
  -> {
    "openssl".run "pkcs12", "-nocerts",
                  "-in", options[:input_file],
                  "-out", options[:tmp_key_file],
                  "-password", "pass:#{options[:pwd]}",
                  "-passin", "pass:#{options[:pwd]}",
                  "-passout", "pass:#{options[:tmp_pwd]}"
  },
  -> {
    "openssl".run "rsa",
                  "-in", options[:tmp_key_file],
                  "-out", options[:tmp_key_pwdless_file],
                  "-passin", "pass:#{options[:tmp_pwd]}"
  },
  -> {
    options[:tmp_pem_file].write([
      options[:tmp_key_pwdless_file].read,
      options[:tmp_cert_file].read,
      options[:tmp_ca_file].read
    ].join("\n"))
  },
  -> {
    "openssl".run "pkcs12", "-export", "-nodes",
                  "-CAfile", options[:tmp_ca_file],
                  "-in", options[:tmp_pem_file],
                  "-out", options[:output_file]
  }
].do_all


# vim: set filetype=ruby :
