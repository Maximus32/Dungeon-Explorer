

#------------------------------------------------------------------------------
# ASSEMBLY TOOLBOX
#==============================================================================
# Module included by assembler classes
#------------------------------------------------------------------------------
module Assembly_Toolbox

	# Sub-coordinate constants
	SUB_NONE  = -1
	SUB_UP    =  0
	SUB_RIGHT =  1
	SUB_LEFT  =  2
	SUB_DOWN  =  3
	SUB_BELOW =  4
	SUB_ABOVE =  5
	
	SUB_VERTS = [SUB_UP, SUB_DOWN]
	SUB_HORZS = [SUB_RIGHT, SUB_LEFT]
	SUB_ZAXIS = [SUB_ABOVE, SUB_ABOVE]
	
	SUB_AXES = [SUB_VERTS, SUB_HORZS, SUB_ZAXIS]
	
	MODEL_SUB_COORDS = [SUB_LEFT, SUB_UP, SUB_ABOVE]
	
	#--------------------------------------------------------------------------
	# > Checks if the specified sub-coordinate fits with this model
	# > Else it will have to be flipped during door placement
	#--------------------------------------------------------------------------
	def model_sub_coord?(sub_coord)
		MODEL_SUB_COORDS.include?(sub_coord)
	end
	#--------------------------------------------------------------------------
	# > Adjusts the specified coordinate and sub-coordinate if they do not
	#   fit the model, moving the coordinate by one and flipping the sub-coord-
	#   inate
	#--------------------------------------------------------------------------
	def modeled_coord_pair(coord, sub_coord)
		if !model_sub_coord?(sub_coord)		
			coord = Assembly.move_coord(sub_coord, coord.dup)
			sub_coord = Assembly.flipped_sub(sub_coord)
		end
		
		puts [coord, sub_coord].to_s
		
		return [coord, sub_coord]
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY DOOR
#==============================================================================
# A melifluous form of a door object
# 
# Has no assigned destination, rather, a directional sub-coordinate that
# defines which room this door leads into (an assembly is non-quantum)
# 
# The reciprocality of the door is maintained by the '@dir' variable and an
# assembly door is always assigned to a single room without regard to its
# '@dir' (i.e. a room can have a one-way assembly door going *from* it's
# destination)
# 
# When converting from an assembly to a dungeon, the direction and sub-coord-
# inate are discarded and a proper destination room is assigned from room
# coordinates
#------------------------------------------------------------------------------
class Assembly_Door < Door
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :dir
	attr_reader :sub_coord
	
	#--------------------------------------------------------------------------
	# > Initialization with LS, direction, sub-coordinate values specified
	#--------------------------------------------------------------------------
	def initialize(ls = LS.new, dir = 2, sub_coord = 0)
		super(-1, ls)
		
		@dir = dir
		@sub_coord = sub_coord
	end
	#--------------------------------------------------------------------------
	# > Assigns the direction (0 for one-way to destination, 1 for one-way from
	#   destination, 2 for bidirectional)
	#--------------------------------------------------------------------------
	def set_dir(dir)
		@dir = dir
	end
	#--------------------------------------------------------------------------
	# > Sets the directional sub-coordinate
	#--------------------------------------------------------------------------
	def set_sub_coord(sub_coord)
		@sub_coord = sub_coord
	end
	#--------------------------------------------------------------------------
	# > Flips the directional sub-coordinate
	#--------------------------------------------------------------------------
	def flip
		@sub_coord = Assembly.flipped_sub(@sub_coord)
	end
	#--------------------------------------------------------------------------
	# > Door data copy
	#--------------------------------------------------------------------------
	def dup
		Assembly_Door.new(@ls.dup, @dir, @sub_coord)
	end
	#--------------------------------------------------------------------------
	# > Compiles a standard door
	#   
	# > The lock specification is copied
	# > The destination room is assigned based on the two parameters and
	#   properties of this door
	#   
	# > If a door must be placed in another room to make it valid, a "fixed"
	#   room ID and data code are returned--along with the door--to be inter-
	#   preted by the Assembler
	#--------------------------------------------------------------------------
	def compile(room_id, new_room_id)
		door = Door.new(-1, @ls.dup)
		
		package = nil
		
		# Assigns the new room ID as either the destination room or the fixed
		# current room
		# Then assigns a package to be interpreted by the Assembler
		package =
		if !one_way?
			Door_Compilation_Package.new(door, new_room_id, :copy)
		elsif one_way? && !forward?
			door.set_dest(room_id)
			Door_Compilation_Package.new(door, new_room_id, :replace)
		else
			door.set_dest(new_room_id)
			Door_Compilation_Package.new(door, new_room_id, :stay)
		end
		
		# Returns the package containing the door
		package
	end
	#--------------------------------------------------------------------------
	# > Checks if this is a one-way door
	#--------------------------------------------------------------------------	
	def one_way?
		@dir < 2
	end
	#--------------------------------------------------------------------------
	# > Checks if this door leads out of the room (bi-directional is OK)
	#--------------------------------------------------------------------------
	def forward?
		@dir == 0 || @dir == 2
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY ROOM
#==============================================================================
# A melifluous form of a room object
# 
# Assigned 6 spaces for doors initially (corresponding to assembly sub-coord-
# inate directions) as well as a unique ID that is preserved no matter where
# the room is placed
# Doors are also Assembly Doors, rather than standard doors
# 
# When converting from an assembly to a dungeon, the 'nil' doors are discarded
# and the ID is unassigned
#------------------------------------------------------------------------------
class Assembly_Room < Room
	
	#--------------------------------------------------------------------------
	# > Class variables
	#--------------------------------------------------------------------------
	@@current_id = 0
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :id
	
	attr_accessor :tag
	
	#--------------------------------------------------------------------------
	# > Initialized with a unique ID
	#--------------------------------------------------------------------------
	def initialize
		super([nil, nil, nil, nil, nil, nil])
		
		@id = @@current_id
		@tag = nil
		
		@@current_id += 1
	end
	#--------------------------------------------------------------------------
	# > Compiles a standard room, copying parameters and discarding 'nil' doors
	#   
	# > Doors themselves are compiled later on
	#--------------------------------------------------------------------------
	def compile
		Room.new(@doors.compact!, @events, @unused)
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY
#==============================================================================
# A melifluous (what a great word) form of a dungeon object
# 
# Maintains a dynamic, 3-D array of rooms that are displayed by a special type
# of dungeon printer
# 
# Features several methods for creating and removing dungeon components, and
# maintains a cursor controlled by the User that guides how and where these are
# placed
# 
# Completion of an assembly creates a non-quantum dungeon from the rooms
# array
#------------------------------------------------------------------------------
class Assembly
	
	# Mixins
	include Assembly_Toolbox
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :rooms
	attr_reader :cursor
	attr_reader :sub_cursor
	
	#--------------------------------------------------------------------------
	# > Initialization
	#--------------------------------------------------------------------------
	def initialize
		@rooms = [[[nil]]]
		@cursor = [0, 0, 0]
		@sub_cursor = SUB_NONE
		@ee_coords = { :e => nil, :x => nil }
	end
	#--------------------------------------------------------------------------
	# > Assigns the printer for this assembly
	#--------------------------------------------------------------------------
	def assign_printer(asm_printer)
		@asm_printer = asm_printer
	end
	
	#--------------------------------------------------------------------------
	# ASSEMBLY PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns the room at the specified coordinate
	#--------------------------------------------------------------------------
	def room_at(coord = @cursor)
		return nil if at_min_bounds?(coord)
		
		fl_arr = floor_rooms[coord[1]]
		return nil unless fl_arr
		
		return fl_arr[coord[2]]
	end
	#--------------------------------------------------------------------------
	# > Returns the door at the specified coordinate and sub-coordinate,
	#   adjusting the sub-coordinate to fix the model, if necessary
	#--------------------------------------------------------------------------
	def door_at(sub_coord, coord = @cursor)
		coord, sub_coord = modeled_coord_pair(coord.dup, sub_coord)
		
		room_at(coord).doors[sub_coord]
	end
	#--------------------------------------------------------------------------
	# > Returns the object at the specified coordinate and sub-coordinate
	#   
	# > May be a door or a room, depending on the type of selection
	#--------------------------------------------------------------------------
	def object_at(coord = @cursor, sub_coord = @sub_cursor)
		if sub_coord != SUB_NONE
			door_at(sub_coord, coord)
		else room_at(coord)
		end
	end
	#--------------------------------------------------------------------------
	# > Current FL #
	#--------------------------------------------------------------------------
	def floor_no
		@cursor[0]
	end
	#--------------------------------------------------------------------------
	# > 2-D array of rooms consisting of the current floor
	#--------------------------------------------------------------------------
	def floor_rooms
		@rooms[floor_no]
	end
	#--------------------------------------------------------------------------
	# > Assembler grid boundaries
	#--------------------------------------------------------------------------
	def min_row; return -1;             end
	def min_col; return -1;             end
	def max_row; floor_rooms.length;    end
	def max_col; floor_rooms[0].length; end
	#--------------------------------------------------------------------------
	# > Checks if the specified coord is at the top or left side
	#--------------------------------------------------------------------------
	def at_min_bounds?(coord = @cursor)
		coord[1] == min_row || coord[2] == min_col
	end
	#--------------------------------------------------------------------------
	# > Centers the cursor, setting the sub-cursor to -1
	#--------------------------------------------------------------------------
	def center
		@sub_cursor = SUB_NONE
	end
	#--------------------------------------------------------------------------
	# > Checks if selecting a center coordinate
	#--------------------------------------------------------------------------
	def center_select?
		@sub_cursor == SUB_NONE
	end
	#--------------------------------------------------------------------------
	# > Checks if selecting a threshold coordinate
	#--------------------------------------------------------------------------
	def thresh_select?
		@sub_cursor != SUB_NONE
	end
	#--------------------------------------------------------------------------
	# > Checks if can move from a threshold indicated by 'sub_coord' in the
	#   specified direction (i.e. they lie on the same axis)
	#--------------------------------------------------------------------------
	def moveable_thresh?(dir_coord, sub_coord = @sub_cursor)
		return true if sub_coord == SUB_NONE
		
		[SUB_VERTS, SUB_HORZS].any? { |subs|
			subs.include?(dir_coord) && subs.include?(sub_coord)
		}
	end
	#--------------------------------------------------------------------------
	# > Checks if two sub-coordinates are pointing in the same direction
	#--------------------------------------------------------------------------
	def movement_aligned?(dir_coord, sub_coord = @sub_cursor)
		return true if sub_coord == SUB_NONE
		
		dir_coord == sub_coord
	end
	#--------------------------------------------------------------------------
	# > Determines if the specified threshold (indicated in the direction of
	#   the specified sub-coordinate) is complete; that is, it is between two
	#   existing rooms
	#   
	# > Only valid thresholds can be selected by the cursor
	#--------------------------------------------------------------------------
	def complete_threshold?(sub_coord, coord = @cursor)
		!room_at(coord).nil? && !room_at(move_coord(sub_coord, coord.dup)).nil?
	end
	#--------------------------------------------------------------------------
	# > Returns the ID for a new event
	#   
	# > Event IDs are added incrementally, with missing IDs being "filled in"
	#--------------------------------------------------------------------------
	def new_event_id
		new_id = 1
		succ = false
		
		until succ
			succ = true
			
			all_events.each { |event|
				if event.id == new_id
					new_id += 1
					break succ = false
				end
			}
		end
		
		return new_id
	end
	#--------------------------------------------------------------------------
	# > Returns a list of all rooms in this assembly
	#--------------------------------------------------------------------------
	def all_rooms
		rooms = []
		
		each_room { |room| rooms.push(room) }
		
		rooms
	end
	#--------------------------------------------------------------------------
	# > Returns the event of the specified ID
	#--------------------------------------------------------------------------
	def get_event(event_id)
		each_event { |event| return event if event.id == event_id }
		
		return nil
	end
	#--------------------------------------------------------------------------
	# > Returns a list of all events in this assembly
	#--------------------------------------------------------------------------
	def all_events
		events = []
		
		each_event { |event| events.push(event) }
		
		events
	end
	#--------------------------------------------------------------------------
	# > Iterates across all rooms
	#	
	# > By default, excludes 'nil' elements
	#--------------------------------------------------------------------------
	def each_room(include_nil = false)
		@rooms.each { |floor|
			floor.each { |rooms_arr|
				rooms_arr.each { |room| yield room if include_nil || room }
			}
		}
	end
	#--------------------------------------------------------------------------
	# > Iterates across all events
	#--------------------------------------------------------------------------
	def each_event
		each_room { |room| room.events.each { |event| yield event } }
	end
	#--------------------------------------------------------------------------
	# > Count of valid rooms
	#--------------------------------------------------------------------------
	def size
		count = 0
		
		each_room { |room| count += 1 }
		
		count
	end
	
	#--------------------------------------------------------------------------
	# CURSOR MOVEMENT & SELECTION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Cursor move up
	#--------------------------------------------------------------------------
	def cursor_move_up
		if @cursor[1] > min_row
			cursor_move(SUB_UP)
			reprint
		end
	end
	#--------------------------------------------------------------------------
	# > Cursor move right
	#--------------------------------------------------------------------------
	def cursor_move_right
		if @cursor[2] < max_col
			cursor_move(SUB_RIGHT)
			reprint
		end
	end
	#--------------------------------------------------------------------------
	# > Cursor move left
	#--------------------------------------------------------------------------
	def cursor_move_left
		if @cursor[2] > min_col
			cursor_move(SUB_LEFT)
			reprint
		end
	end
	#--------------------------------------------------------------------------
	# > Cursor move down
	#--------------------------------------------------------------------------
	def cursor_move_down
		if @cursor[1] < max_row
			cursor_move(SUB_DOWN)
			reprint
		end
	end
	#--------------------------------------------------------------------------
	# > Moves the cursor specified direction, changing coordinate values for
	#   different cases
	# 	- Center selected and valid threshold? -> move to that threshold
	#   - Center selected and invalid thresh?  -> move to next center coord
	#   - At moveable threshold?               -> move to next center coord
	#--------------------------------------------------------------------------
	def cursor_move(dir_coord)
		if center_select? && complete_threshold?(dir_coord)
			@sub_cursor = dir_coord
		elsif moveable_thresh?(dir_coord)
			move_coord(dir_coord) if movement_aligned?(dir_coord)
			center
		end
	end
	
	def move_floor_up
	end
	
	def move_floor_down
	end
	
	#--------------------------------------------------------------------------
	# CLASS METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Moves the specified cursor in the direction of the sub-coordinate
	#   
	# > Modifies the coordinate and also returns it
	#--------------------------------------------------------------------------
	def self.move_coord(sub_coord, coord)
		case sub_coord
		when SUB_UP    then coord[1] += -1
		when SUB_RIGHT then coord[2] +=  1
		when SUB_LEFT  then coord[2] += -1
		when SUB_DOWN  then coord[1] +=  1
		end
		
		coord
	end
	#--------------------------------------------------------------------------
	# > Member method version
	#--------------------------------------------------------------------------
	def move_coord(sub_coord = @sub_cursor, coord = @cursor)
		Assembly.move_coord(sub_coord, coord)
	end
	#--------------------------------------------------------------------------
	# > Converts the specified sub-coordinate into a 3-element array represen-
	#   ting a unit coordinate difference in the direction of the sub-coordin-
	#   ate
	#--------------------------------------------------------------------------
	def self.convert_sub_coord(sub_coord)
		Assembly.move_coord(sub_coord, [0, 0, 0])
	end
	#--------------------------------------------------------------------------
	# > Returns the "flipped" version of the specified sub-coordinate
	#--------------------------------------------------------------------------
	def self.flipped_sub(sub_coord)
		puts "SUB COORD: #{sub_coord}"
		
		SUB_AXES.each { |axis|	
			index = axis.index(sub_coord)
			next unless index
			
			return axis[1 - index]
		}
	end
	
	#--------------------------------------------------------------------------
	# ASSEMBLY ROOM MODIFICATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Places the room at the specified coordinates
	#   
	# > Resizes the rooms array and printer automatically, unless otherwise
	#   specified
	#--------------------------------------------------------------------------
	def place_room(room, coord, resize)
		resize_rooms_array(coord) if resize
		
		@rooms[coord[0]][coord[1]][coord[2]] = room
		
		@asm_printer.print_room(room, print_coord(coord))
		
		refresh
	end
	#--------------------------------------------------------------------------
	# > Removes a room at the specified coordinates
	#--------------------------------------------------------------------------
	def remove_room(coord)
		# TODO: resize rooms by subtracting columns/rows!
		
		@rooms[coord[0]][coord[1]][coord[2]] = nil
		
		@asm_printer.unprint_room(print_coord(coord))
		
		refresh
	end
	
	#--------------------------------------------------------------------------
	# ROOM TAGGING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Interprets a tag command (assignment, clearing) at the specified room
	#   coordinates
	#--------------------------------------------------------------------------
	def tag_command(command, coord = @cursor.dup)
		tag = nil
		
		# Assigns the tag to be assigned/cleared
		if command == :c
			tag = room_at(coord).tag
			return unless tag
		else tag = command
		end
		
		# Assigns and clears the tag
		unassign_ee(tag)
		assign_ee(tag, coord)
	end
	#--------------------------------------------------------------------------
	# > Unassigns an entrance/exit tag
	#--------------------------------------------------------------------------
	def unassign_ee(tag)
		return unless @ee_coords[tag]
		
		object_at(@ee_coords[tag]).tag = nil
		
		reprint_object_at(@ee_coords[tag], SUB_NONE, false)
		
		@ee_coords[tag] = nil
	end
	#--------------------------------------------------------------------------
	# > Assigns an entrance/exit tag at the specified coordinate
	#--------------------------------------------------------------------------
	def assign_ee(tag, coord)
		room_at(coord).tag = tag
		
		reprint_object_at(coord, SUB_NONE)
		
		@ee_coords[tag] = coord
	end
	
	#--------------------------------------------------------------------------
	# ASSEMBLY RESIZING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Resizes the current floor of the rooms array to ensure that the
	#   specified coordinate fits inside
	#   Also adjusts the coordinate in respect to this change
	#   
	# > Also calls on the printer to resize the page to match that of the new
	#   floor
	#--------------------------------------------------------------------------
	def resize_rooms_array(coord)
		up, right, left, down = [0, 0, 0, 0]
		
		# Handles if row is at top or bottom edge
		# Adds a new row of rooms
		if coord[1] == min_row
			append_row(-1)
			coord[1] += 1
			up += 1
		elsif coord[1] == max_row
			append_row(1)
			down += 1
		end
		
		# Handles if column is at left or right edge
		# Adds a new column of rooms
		if coord[2] == min_col
			append_column(-1)
			coord[2] += 1
			left += 1
		elsif coord[2] == max_col
			append_column(1)
			right += 1
		end
		
		# Resizes the printer
		@asm_printer.resize(up, right, left, down)
	end
	#--------------------------------------------------------------------------
	# > Expands the floor rooms array by one in the horizontal direction
	#--------------------------------------------------------------------------
	def append_column(dir)
		if dir > 0
			floor_rooms.each { |rooms_arr| rooms_arr.push(nil) }
		else floor_rooms.each { |rooms_arr| rooms_arr[0, 0] = nil }
		end
	end
	#--------------------------------------------------------------------------
	# > Expands the floor rooms array by one in the vertical direction
	#--------------------------------------------------------------------------
	def append_row(dir)
		if dir > 0
			floor_rooms.push(new_row)
		else floor_rooms[0, 0] = [new_row]
		end
	end
	#--------------------------------------------------------------------------
	# > Creates an empty row to append to the floor rooms array
	#--------------------------------------------------------------------------
	def new_row
		row = []
		max_col.times { row.push(nil) }
		row
	end
	
	#--------------------------------------------------------------------------
	# ASSEMBLY REFRESH
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Refreshes the assembly, calling for a reprint
	#--------------------------------------------------------------------------
	def refresh
		reprint
	end
	
	#--------------------------------------------------------------------------
	# PRINTING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Calls on the assembly Printer to reprint the dungeon
	#   
	# > Called whenever the dungeon is modified or the cursor is moved
	#--------------------------------------------------------------------------
	def reprint
		@asm_printer.actualize_printout
	end
	#--------------------------------------------------------------------------
	# > Calls on the assembly Printer to individually reprint each room in the
	#   dungeon
	#   
	# > Called whenever the entire dungeon is modified, like when an Assembly
	#   is loaded
	#--------------------------------------------------------------------------
	def full_reprint
		for row in (min_row...max_row)
			for col in (min_col...max_col)
				reprint_object_at([0, row, col], SUB_NONE, false)
			end
		end
		
		reprint
	end
	#--------------------------------------------------------------------------
	# > Calls on the assembly Printer to reprint the object at the specified
	#   coordinates
	#   
	# > Unlike 'reprint' which only reactualizes the printout, this method
	#   calls on the printer to reconstruct the blocks to the object and modify
	#   the document permanately
	#   
	# > Will automatically reactualize the printout as well
	#--------------------------------------------------------------------------
	def reprint_object_at(coord = @cursor, sub_coord = @sub_cursor, actualize = true)
		obj = object_at(coord, sub_coord)
		
		return unless obj
		
		p_coord = print_coord(coord)
		
		if obj.is_a?(Assembly_Room)
			@asm_printer.print_room(obj, p_coord)
		elsif obj.is_a?(Assembly_Door)
			@asm_printer.print_door(obj, p_coord[1..2])
		end
		
		reprint if actualize
	end
	#--------------------------------------------------------------------------
	# > Returns the printing-adjusted coord (i.e. the origin for an assembling
	#   dungeon is at the center whereas for a page it is at the top left)
	#   
	# > If no coordinate is specified, the cursor is used instead
	#--------------------------------------------------------------------------
	def print_coord(coord = @cursor)
		print_c = coord.dup
		
		print_c[1] += 1
		print_c[2] += 1
		
		print_c
	end
	
	#--------------------------------------------------------------------------
	# COMPILATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Compilation refers to the creating of a standard dungeon from non-
	#   standard dungon-like objects
	#   
	# > For an assembly, the rooms and metadata are collected and compiled into
	#   a basic dungeon object
	# > The doors are then compiled in the context of this object and the fully
	#   fledged dungeon is returned
	#--------------------------------------------------------------------------
	def compile(name)
		valid_compilation?
		
		puts "Beginning room compilation..."
		rooms = []
		each_room { |asm_room|
			rooms.push(asm_room.compile)
			
			sleep 0.2
			puts "\tRoom compiled successfully"
		}
		
		sleep 1
		puts "All rooms compiled\n\n"
		
		sleep 2
		puts "Metadata assigned\n\n"
		dungeon = Non_Quantum_Dungeon.new(name, rooms, get_metadata)
		
		sleep 1
		puts "Beginning door compilation..."
		compile_doors(dungeon)
		
		sleep 1
		puts "All doors compiled\n\n"
		
		dungeon
	end
	#--------------------------------------------------------------------------
	# > Checks if the Assembly is valid for Compilation, raising errors if not
	#	so
	#--------------------------------------------------------------------------
	def valid_compilation?
		@ee_coords.each { |tag, coord|
			if coord.nil? || room_at(coord).nil?
				raise Compilation_Error.new(0)
			end
		}
	end
	#--------------------------------------------------------------------------
	# > Returns an array of metadata intended for a dungeon compilation
	#--------------------------------------------------------------------------
	def get_metadata
		length = max_row
		width = max_col
		area = length * width
		
		# Derive room IDs manually using assembly dimensions
		tagged_IDs = @ee_coords.values.collect { |coord|
			coord[0] * area + coord[1] * width + coord[2]
		}
		
		[tagged_IDs, 1, length, width].flatten
	end
	#--------------------------------------------------------------------------
	# > Doors are compiled from within the dungeon
	#   
	# > For each door, the destination coordinates are assigned and the room
	#   placement is corrected
	# > This is handled through a special struct-like object
	#--------------------------------------------------------------------------
	def compile_doors(dungeon)
		dungeon.each_room_with_id { |room, room_id|
			room_coord = dungeon.coordinate(room_id)
			
			sleep 0.2
			puts "\tCompiling doors in room ##{room_id}..."
			
			# Creates a doors array that is added on to by evaluating packages
			# returned by compiled doors
			doors = []
			room.each_door { |asm_door|
				next if !asm_door.is_a?(Assembly_Door)
				
				new_coord = Assembly.move_coord(asm_door.sub_coord, room_coord)
				new_room_id = dungeon.index(new_coord)
				
				pkg = asm_door.compile(room_id, new_room_id)
				
				evaluate_package(room_id, pkg, dungeon, doors)
				
				sleep 0.2
				puts "\t\tDoor compiled successfully"
			}
			
			# The list of doors is added to the current room
			room.append_doors(doors) unless doors.empty?
			
			# Delete assembly doors from the dungeon
			room.doors.delete_if { |door| door.is_a?(Assembly_Door) }
		}
	end
	#--------------------------------------------------------------------------
	# > Evaluate the specified compilation package in the context of the
	#   dungeon, current room ID, and list of doors
	#   
	# > Adds the package's door to the current doors array (if any), as well as
	#	to any other rooms
	#--------------------------------------------------------------------------
	def evaluate_package(this_room_id, pkg, dungeon, doors)
		
		# Adds the door to the current room, going into the destination room
		if pkg.add_current?
			pkg.door.set_dest(pkg.room_id)
			doors.push(pkg.door)
		end
		
		# Adds the door to the destination room, going into the current room
		if pkg.add_other?
			other_door = pkg.door.dup
			other_door.set_dest(this_room_id)
			dungeon.room_at(pkg.room_id).add_door(other_door)
		end
	end
	#--------------------------------------------------------------------------
	# > Returns an array of strings detailing this assembly's size, containing
	#   the number of rooms, floors, and events
	#--------------------------------------------------------------------------
	def size_sformat
		["#{1} floors", "#{max_row} x #{max_col} area", "#{size} rooms",
			"#{all_events.length} events"]
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns a string representation of the assembly, printing the
	#   contents of the current floor rooms array
	#--------------------------------------------------------------------------
	def to_s
		str = ""
		
		floor_rooms.each { |rooms_arr|
			str += (rooms_arr.collect { |room| (room ? room.to_s : "*") }).join(", ")
			str += "\n"
		}
		
		str
	end
end

#------------------------------------------------------------------------------
# DOOR COMPILATION PACKAGE
#==============================================================================
# Struct-like class that is returned by the 'compile' method of an assembly
# door
# 
# Contains a standard door, along with a code specifying if this door should be
# copied or moved
#------------------------------------------------------------------------------
class Door_Compilation_Package
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :door
	attr_reader :room_id
	attr_reader :command

	#--------------------------------------------------------------------------
	# > Initialization with member variables specified
	#   
	# > The command parameter takes on three values with the following effects
	#   - :stay    -> the door is added to the current room
	#   - :replace -> the door is removed and added to the room of 'room_id'
	#   - :copy    -> the door is added to the current room and that of 'room_id'
	#--------------------------------------------------------------------------
	def initialize(door, room_id, command)
		@door = door
		@command = command
		@room_id = room_id
	end
	#--------------------------------------------------------------------------
	# > Checks if the command specifies that the door should be added to the
	#   current room
	#--------------------------------------------------------------------------
	def add_current?
		@command == :stay || @command == :copy
	end
	#--------------------------------------------------------------------------
	# > Checks if the command specifies that the door should be added to
	#   another room
	#--------------------------------------------------------------------------
	def add_other?
		@command == :replace || @command == :copy
	end
	#--------------------------------------------------------------------------
	# > String representation
	#--------------------------------------------------------------------------
	def to_s
		"#{@door} : #{@room_id}; #{@command}"
	end
end

#------------------------------------------------------------------------------
# COMPILATION ERROR
#==============================================================================
# Exception thrown in the context of Assembly Compilation
#------------------------------------------------------------------------------
class Compilation_Error < Generic_Error
	
	#--------------------------------------------------------------------------
	# > Error prefix
	#--------------------------------------------------------------------------
	def header
		"COMPILATION ERROR"
	end
	#--------------------------------------------------------------------------
	# > List of messages
	#--------------------------------------------------------------------------
	def messages
		[
			"Entrance/exit rooms have not been completely assigned"
		]
	end
end