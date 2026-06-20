#!/usr/bin/env ruby
# Adds a source file to the OST Tracker project and to the named targets'
# compile phase. Idempotent: safe to run again.
require 'xcodeproj'

path = ARGV[0]
target_names = ARGV[1..-1]
abort "usage: add_file_to_targets.rb <path> <target>..." if path.nil? || target_names.empty?

project_path = 'OST Tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
abs = File.expand_path(path)

changed = false
ref = project.files.find { |f| f.real_path.to_s == abs }
if ref.nil?
  ref = project.main_group.new_file(path)
  changed = true
end

target_names.each do |name|
  target = project.targets.find { |t| t.name == name }
  abort "no target named #{name}" if target.nil?
  already = target.source_build_phase.files_references.include?(ref)
  unless already
    target.add_file_references([ref])
    changed = true
  end
  puts "#{already ? 'already in' : 'added to'} #{name}: #{path}"
end

# Only write when something actually changed — keeps the diff minimal and the
# script idempotent (Xcodeproj#save rewrites the whole file otherwise).
project.save if changed

