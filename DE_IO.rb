#------------------------------------------------------------------------------
# DUNGEON IO
#==============================================================================
# Module that handles the reading and writing of dungeon information from and
# to files
# 
# Handles low-level user input and output that does not concern the Operator
# i.e. displaying the contents of a file, results of file operations
# 
# Can be considered a manager of the Administrator class, although it takes the
# form of a module to imitate the class behaviors of the IO and File classes
#------------------------------------------------------------------------------
module Dungeon_IO
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	DUNGEONS_FOLDER = "/Dungeons/"
	
	#--------------------------------------------------------------------------
	# > Creates the handler for this module
	#--------------------------------------------------------------------------
	def self.init
		@handler = IO_Handler.new
	end
	#--------------------------------------------------------------------------
	# > The directory where dungeon files are stored
	#--------------------------------------------------------------------------
	def self.directory
		Dir.pwd + DUNGEONS_FOLDER
	end
	
	#--------------------------------------------------------------------------
	# DUNGEON INPUT & READING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates a new dungeon by reading the specified text file
	#   
	# > A dungeon file is headed by a line of metadata, followed by lines
	#   describing rooms (room IDs are assigned by line numbers)
	#--------------------------------------------------------------------------
	def self.read_dungeon(dungeon_name)
		filename = "#{dungeon_name}.txt"
		
		dungeon = nil
		
		begin
			line_no = 0
			
			raise SystemCallError.new("") if !File.exist?(directory + filename)
			file = File.new(directory + filename)
			
			file.each { |line|
				line = line.chomp("\n")
				
				if line_no == 0
					dungeon = build_dungeon(dungeon_name, line)
				elsif line.empty?
					dungeon.add_room(Room.empty_room)
				else dungeon.add_room(interpret_room_line(line))
				end
				
				line_no += 1
			}
		rescue => error
			@handler.handle(IO_Error.generate(error, name, line_no))
			return false
		ensure file.close if file
		end
		
		# Check for formatting errors not detectable during
		# reading and proceed to assign values to instance variables
		#check_dungeon_formatting(name, dungeon, meta_info, event_ref)
		#assign_instance_variables(name, dungeon, meta_info, event_ref)
		#@admin.append_context(:dungeon)
		
		sleep 1
		puts "The dungeon was successfully read!\n"
		
		# Returns an immutable dungeon
		dungeon.freeze
		return dungeon
	end
	#--------------------------------------------------------------------------
	# > Interprets the specified line as parameters used to create an empty
	#   dungeon
	#   
	# > Includes the type of the dungeon and its metadata
	#--------------------------------------------------------------------------
	def self.build_dungeon(name, line)
		type, metadata = line.split(" ")
		metadata = metadata.split(":").collect { |c| (c =~ /\d/ ? c.to_i : c) }
		
		Dungeon::D_TYPE_MAP[type].new(name, [], metadata)
	end
	#--------------------------------------------------------------------------
	# > Intreprets the specified line as a room within to the dungeon
	#   
	# > Formats and returns the completed room
	#--------------------------------------------------------------------------
	def self.interpret_room_line(line)
		room = Room.new
		
		room_info = line.split(" ")
		room_info[0, 0] = nil if line[0] == " "  # Handling for when no doors are specified
		
		# The first set of terms represents the array of doors leading out of the room
		interpret_doors(room, room_info[0]) if room_info[0]
		
		# The second set of terms represents the events within the room
		interpret_events(room, room_info[1]) if room_info[1]
		
		return room
	end
	#--------------------------------------------------------------------------
	# > Interprets the specified string as an array of doors which are added to
	#   the room
	#   
	# > For a given 'door_str', the first term is the destination room ID with
	#   following terms being event-state pairs making up the LS of the door
	#--------------------------------------------------------------------------
	def self.interpret_doors(room, info)
		info.split(",").each { |door_str|
			door = Door.new
			ls = LS.new
			
			# Set destination room and modify the LS
			door_str.split("-").each_with_index { |str, i|
				if i == 0
					door.set_dest(str.to_i)
				else ls.add_es_pair(str.split(":").collect { |c| c.to_i } )
				end
			}
			
			# Assign the LS to this door
			door.set_ls(ls)
			
			room.add_door(door)
		}
	end
	#--------------------------------------------------------------------------
	# > Interprets the specified string as an array of events which are added
	#   to the room
	#   
	# > For a given 'event_str', the first term is the event ID with the
	#   following terms describing the states of the event
	#--------------------------------------------------------------------------
	def self.interpret_events(room, info)
		info.split(",").each { |event_str|
			str = event_str.split(":")
			
			# If the 'state_count' is 0 or 1 (or not specified), an Item is
			# created, else a Switch is created
			id = str[0].to_i
			state_count = str[1].to_i
			event =
			if state_count > 1
				init_state = (str[2] ? str[2].to_i : 0)
				Switch.new(id, state_count, )
			else Item.new(id)
			end
			
			room.add_event(event)
		}
	end
	
	#--------------------------------------------------------------------------
	# DUNGEON OUTPUT & WRITING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Writes the specified dungeon to a text file
	#--------------------------------------------------------------------------
	def self.write_dungeon(dungeon)
		file = File.new(directory + "#{dungeon.name}.txt", 'w')
		
		# Prints dungeon type and metadata
		file.print(Dungeon::D_TYPE_MAP.invert[dungeon.class])
		file.puts(" " + dungeon.get_metadata.join(":"))
		
		dungeon.each_room { |room|
			next puts "" if room.unused?
			
			file.print((room.doors.collect { |door| door.to_s }).join(","))
			file.puts(" " + (room.events.collect { |event| event.to_s }).join(","))
		}
		
		sleep 1
		puts "The dungeon was successfully written to a file!\n"
		
		file.close
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Displays a dungeon printout file to the console
	#--------------------------------------------------------------------------
	def self.display_dungeon_printout(filename)
		File.open(filename + ".txt") { |file|
			file.each { |line| puts line }
		}
	end
end

class IO_Error < Generic_Error
	
	#--------------------------------------------------------------------------
	# > Takes a specified type of Ruby exception and generates an IO Error from
	#   its type and the specified parameters
	#--------------------------------------------------------------------------
	def self.generate(super_error, name, line_no)
		if super_error.is_a?(SystemCallError)
			IO_Error.new(0, name)
		else IO_Error.new(1, name, line_no)
		end
	end
	#--------------------------------------------------------------------------
	# > List of error messages
	#--------------------------------------------------------------------------
	def messages
		[
			"Dungeon Reading: The dungeon by the name of '%s' does not exist",
			"Dungeon Reading: The file specified by the dungeon of name '%s' is malformed on line %d",
			""
		]
	end
end

class IO_Handler < Handler
	
	#--------------------------------------------------------------------------
	# > Displays extra message
	#--------------------------------------------------------------------------
	def handle(error)
		super(error)
		
		puts "The dungeon was not read successfully,\n" +
			"returning to the main menu..."
	end
	#--------------------------------------------------------------------------
	# > List of handled error types
	#--------------------------------------------------------------------------
	def handled_types
		super << IO_Error
	end
	
end