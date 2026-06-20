#!/usr/bin/env ruby
# Usage: ruby scripts/remove_file_from_xcodeproj.rb <basename_or_relative_path>
# Removes a file's reference from the project (cascades to its PBXBuildFile
# entries in every target's Sources/Resources phase). Does NOT delete the file
# on disk — `git rm` that separately. Idempotent: no-op if the ref is absent.
require 'xcodeproj'

needle = ARGV[0] or abort 'usage: remove_file_from_xcodeproj.rb <basename_or_path>'
proj = Xcodeproj::Project.open('OST Tracker.xcodeproj')

refs = proj.files.select do |f|
  path = f.path.to_s
  real = (f.real_path.to_s rescue '')
  path == needle || path.end_with?("/#{needle}") || File.basename(path) == needle || real.end_with?(needle)
end

if refs.empty?
  puts "no project reference matched #{needle} (nothing to remove)"
else
  refs.each do |ref|
    puts "removing reference #{ref.path}"
    ref.remove_from_project
  end
  proj.save
  puts "removed #{refs.size} reference(s) for #{needle}"
end
