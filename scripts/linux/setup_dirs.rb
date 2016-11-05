#!/usr/bin/env ruby


require "shellwords"
require "fileutils"


def error(msg)
  puts "Error: #{msg}"
  exit(-1)
end

def run_cmd(cmd, dryrun: false)
  dryrun ? puts(cmd) : system(cmd)
end

def set_facl(path, perm,
             subject: nil, name: nil, recursive: false, dryrun: false)
  subject = "u" if subject == :owner
  subject = "g" if subject == :group
  subject = "o" if subject == :other
  error("Invalid subject: #{subject}") unless %w(u g o).include?(subject)

  spec = "#{subject}:#{name ? name : ''}:#{perm}"

  run_cmd("setfacl -d #{recursive ? "-R" : ""} -m #{Shellwords.escape(spec)} #{Shellwords.escape(path)}",
          dryrun: dryrun)
end


def setup_dir(path, owner: nil, group: nil, perms: {}, acl: false, dryrun: false)
  path = path.to_s
  owner = owner.to_s
  group = group.to_s

  perms = perms.to_s if perms.is_a?(Symbol)
  perms = perms.split(//) if perms.is_a?(String)
  perms = {
    other: perms.pop, group: perms.pop, owner: perms.pop
  } if perms.is_a?(Array)

  FileUtils.mkdir_p(path,
                    noop: dryrun, verbose: true) unless File.directory?(path)
  FileUtils.chown(owner, group, path, noop: dryrun, verbose: true)
  FileUtils.chmod("#{perms[:owner]}#{perms[:group]}#{perms[:other]}".to_i(8),
                  path, noop: dryrun, verbose: true)

  if acl
    set_facl(path, perms[:owner],
             subject: :owner, name: owner, dryrun: dryrun) if perms[:owner]
    set_facl(path, perms[:group],
             subject: :group, name: group, dryrun: dryrun) if perms[:group]
    set_facl(path, perms[:other],
             subject: :other, dryrun: dryrun) if perms[:other]
  end
end

def gpasswd(user, group, dryrun: false)
  run_cmd("gpasswd -a #{Shellwords.escape(user)} #{Shellwords.escape(group)}", dryrun: dryrun)
end

def group_add(group, dryrun: false)
  run_cmd("groupadd #{Shellwords.escape(group)}", dryrun: dryrun)
end


# Entry point
def main(args, dryrun: false)
  args.each do |info|
    allow = info.delete(:allow)
    group_add(info[:group]) if info[:group]
    setup_dir(info.delete(:path), info.merge(dryrun: dryrun))
    if allow
      error("Can't allow: #{allow}") unless info[:group]
      allow.each { |user| gpasswd(user, info[:group], dryrun: dryrun) }
    end
  end
end

main [
  { path: "/vm" },
  { path: "/vm/virtualbox" },
  { path: "/data/backup" },
  { path: "/data/tmp" },
  { path: "/data/documents" },
  { path: "/data/graphics" },
  { path: "/data/graphics/wallpapers" },
  { path: "/data/audio" },
  { path: "/data/audio/music" },
  { path: "/data/video" },
  { path: "/data/video/movies" },
  { path: "/data/develop" },
  { path: "/data/develop/projects/personal" },
  { path: "/data/develop/projects/work" },
  { path: "/data/develop/projects/work/yoroi" },
  { path: "/data/develop/projects/university" },
  { path: "/data/develop/projects/university/unibo" },
  { path: "/data/develop/playground" },
  { path: "/data/downloads" },
  { path: "/data/shared" },
  { path: "/data/shared/unsafe" }
].map do |h|
  { owner: :root,
    group: :users,
    perms: "770",
    allow: %i(alem0lars)
  }.merge(h)
end
