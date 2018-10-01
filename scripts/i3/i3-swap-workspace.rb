config = "i3-swap-workspace".get_config

[
  -> () { # Check external requirements
    "i3-msg".check_program!
    true
  },
  -> () { # Arguments & Configuration normalization
    config[:saved_workspaces_symbol] = "_"

    true
  },
  -> () {
    output = StringIO.new
    "i3-msg".run "-t", "get_workspaces", output: output
    workspaces = JSON.parse(output.string).map{ |h| h.deep_symbolize_keys }

    focused = workspaces.select { |w| w[:focused] }.first

    if focused[:name].start_with? config[:saved_workspaces_symbol] # Restore
      md = /^#{config[:saved_workspaces_symbol]}([^#{config[:saved_workspaces_symbol]}]+)#{config[:saved_workspaces_symbol]}(.+)$/.match(focused[:name])
      if md
        dst_num = md[1].to_i
        dst_workspace = workspaces.find { |w| w[:num] == dst_num }
        if dst_workspace
          # Save target workspace before restoring (to prevent overwrite)
          "i3-msg".run "workspace #{dst_workspace[:name]}"
          "i3-swap-workspace".run
          "i3-msg".run "workspace #{focused[:name]}"
          "i3-msg".run "rename workspace #{focused[:name]} to #{dst_workspace[:name]}"
        else
          # The target workspace doesn't exist, just restore
          "i3-msg".run "rename workspace #{focused[:name]} to #{dst_num}"
        end
      else
        "Failed to load workspace information: bad format!".perr
      end
    else
      # Find a temporary workspace name, with the following format:
      #   _<old_num>_<saved_idx>
      tmp_workspace_name = nil
      saved_idx = 0
      loop do
        tmp_workspace_name = "#{config[:saved_workspaces_symbol]}#{focused[:num]}#{config[:saved_workspaces_symbol]}#{saved_idx}"
        break unless workspaces.find { |w| w[:name] == tmp_workspace_name }
        saved_idx += 1
      end

      "i3-msg".run "rename workspace #{focused[:name]} to #{tmp_workspace_name}"
      "i3-msg".run "workspace #{focused[:name]}"
    end
  }
].do_all auto_exit_code: true
