Dir.chdir("DUNGEON EXECUTABLE")

require "#{Dir.pwd}/DE_Central.rb"

Dungeon_Admin.new
Dungeon_Admin.admin.start

puts "\nPress 'Enter' to terminate..."
gets