#!/usr/bin/env ruby
# Usage: ruby scripts/add_file_to_xcodeproj.rb <relative_file_path> <target_name> [<target_name>...]
# Idempotently registers an existing file into the given targets of the project.
require 'xcodeproj'

file_path = ARGV[0]
target_names = ARGV[1..-1]
abort "usage: add_file_to_xcodeproj.rb <file> <target> [<target>...]" if file_path.nil? || target_names.empty?

project = Xcodeproj::Project.open('OST Tracker.xcodeproj')

dir = File.dirname(file_path)
group = project.main_group.find_subpath(dir, true)
group.set_source_tree('SOURCE_ROOT') if group.source_tree.nil?

abs = File.expand_path(file_path)
file_ref = group.files.find { |f| f.real_path.to_s == abs } || group.new_reference(abs)

target_names.each do |name|
  target = project.targets.find { |t| t.name == name }
  abort "target not found: #{name}" unless target
  already = target.source_build_phase.files_references.include?(file_ref)
  target.add_file_references([file_ref]) unless already
end

project.save
puts "Registered #{file_path} -> #{target_names.join(', ')}"
