#------------------------------------------------------------------------------
# DUNGEON PRINTER
#==============================================================================
# Object that handles the "printing" of dungeon-like objects (i.e. creating a
# visual representation using ASCII characters in a text file)
# 
# A dungeon-like object may be a dungeon itself, or a collection of rooms and
# doors, or other things
# 
# Manipulates strings by use of blocks, pages, and documents which are written
# to by successive printing calls
# Actual printing is handled heirarchially by the various printing objects
# themselves 
# 
# A finished printout is written to an IO source
#------------------------------------------------------------------------------
class Dungeon_Printer
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	
	# Numerical constants
	BLOCK_WIDTH = 18
	BLOCK_LENGTH = 14
	SPC_LENGTH = 3
	
	#--------------------------------------------------------------------------
	# > Requires the "DE_Print_Objects.rb" file which defines objects used for
	#   printing
	#   
	# > Also passes information to the Block Templates module and creates the
	#   printing handler
	#--------------------------------------------------------------------------
	def initialize
		require "#{Dir.pwd}/DE_Print_Objects.rb"
		
		Block_Templates.init(BLOCK_LENGTH, BLOCK_WIDTH)
		
		@handler = Printing_Handler.new
	end
	
	#--------------------------------------------------------------------------
	# DUNGEON PRINTING METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates an empty Document
	#--------------------------------------------------------------------------
	def create_document
		@document = Document.new
	end
	
	#--------------------------------------------------------------------------
	# ACTUALIZATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Wirtes the document to an IO source, such as a file or stream
	#--------------------------------------------------------------------------
	def actualize_printout(io)
		@document.each { |page|
			io.puts(page.to_s)
			
			# Adds spaces between pages
			SPC_LENGTH.times { io.puts("") }
		}
	end
end

#------------------------------------------------------------------------------
# SIMPLE PRINTER
#==============================================================================
# Object that handles the exact printing of dungeons
# 
# Supplied with a dungeon, quickly and exhaustively fills a document with its
# contents
# 
# A finished printout is written to a file and can be displayed from the
# dungeon IO module
#------------------------------------------------------------------------------
class Simple_Printer < Dungeon_Printer

	#--------------------------------------------------------------------------
	# DUNGEON PRINTING METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Prints the specified dungeon to a new document
	#   
	# > Rooms are translated to blocks in pages and doors and events are
	#   printed to these blocks
	#   
	# > This is a one-call printing that keeps no memory of the printed data
	#--------------------------------------------------------------------------
	def print_dungeon(dungeon, filename = nil)
		raise if !dungeon.visualizable?
		
		@dungeon = dungeon
		
		# Create a document of the appropriate dimensions
		create_document
		
		# Carry out actual printing
		print_rooms
		print_events
		print_doors
		
		# Create a text file and write the document to it
		filename ||= default_filename
		actualize_printout(filename)
		
		sleep 2
		puts "Dungeon printed to file successfully!"
		
		@document = nil
		@dungeon = nil
	end
	#--------------------------------------------------------------------------
	# > Creates a Document containing a blank page for each floor of the
	#   dungeon
	#--------------------------------------------------------------------------
	def create_document
		super
		
		@dungeon.height.times {
			page = Page.blank_page(@dungeon.width, @dungeon.length,
				BLOCK_WIDTH, BLOCK_LENGTH)
			@document.append(page)
		}
	end
	#--------------------------------------------------------------------------
	# > Prints the outlines of the rooms using block replacement printing
	#--------------------------------------------------------------------------
	def print_rooms
		@dungeon.rooms.each_with_index { |room, room_id|
			next if room.unused?
			
			# Assign special character
			special =
			if    @dungeon.entrance?(room_id) then "E"
			elsif @dungeon.exit?(room_id)     then "X"
			else                                   "_"
			end
			
			# Create and print the block
			print_room(room_id, special, @dungeon.coordinate(room_id))
		}
	end
	#--------------------------------------------------------------------------
	# > Prints a room of the dungeon
	#--------------------------------------------------------------------------
	def print_room(room_id, special, coord)
		block = Block_Templates.room_block(room_id, special)
		@document.print_block_replace(block, coord)
	end
	#--------------------------------------------------------------------------
	# > Prints the events of the dungeon by iterating over rooms and printing
	#   to each room block in the page
	#--------------------------------------------------------------------------
	def print_events
		@dungeon.rooms.each_with_index { |room, room_id|
			next if room.unused?
			
			# Gather room events
			events = @dungeon.room_at(room_id).events
			next if events.empty?
			
			
			# Create and print the block
			block = Block_Templates.events_block(events)
			begin
				@document.print_block_edit(block, @dungeon.coordinate(room_id),
					[1, 1])
			rescue Printing_Error => error
				@handler.handle(error)
			end
		}
	end
	#--------------------------------------------------------------------------
	# > Prints each door to each room of the dungeon
	#--------------------------------------------------------------------------
	def print_doors
		@dungeon.rooms.each_with_index { |room, room_id|
			room.doors.each { |door|
				print_door(door, room_id)
			}
		}
	end
	#--------------------------------------------------------------------------
	# > Prints a door of the dungeon, locating the appropriate block and page
	#   using its room ID
	#   
	# > Sends information to the page, including the door's LS, coordinate
	#   difference between rooms, and its reciprocality from the other room
	#--------------------------------------------------------------------------
	def print_door(door, from_room_id)
		to_room_id = door.dest
		
		# Obtain needed parameters
		c_diff = @dungeon.coordinate_difference(to_room_id, from_room_id)
		rcpr = @dungeon.reciprocal_door?(door, from_room_id)
		p_coord = @dungeon.coordinate(from_room_id)
		
		begin
			@document.page(p_coord[0]).print_door(p_coord[1..2], door.ls,
				c_diff, rcpr)
		rescue Printing_Error => error
			@handler.handle(error)
		end
	end
	
	#--------------------------------------------------------------------------
	# ACTUALIZATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Wirtes the document to a file, printing by pages at a time
	#--------------------------------------------------------------------------
	def actualize_printout(filename)
		file = File.new("#{filename}.txt", "w")
		
		super(file)
		
		file.close
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Default filename for when none is specified
	#--------------------------------------------------------------------------
	def default_filename
		"#{@dungeon.name} - PRINTOUT"
	end
	#--------------------------------------------------------------------------
	# > Page measurements
	#--------------------------------------------------------------------------
	def page_width;  @dungeon.width * BLOCK_WIDTH;   end
	def page_length; @dungeon.length * BLOCK_LENGTH; end
	def page_area;   page_width * page_length;       end
	def spacer_area; page_width * SPC_LENGTH;        end
end

#------------------------------------------------------------------------------
# ASSEMBLY PRINTER
#==============================================================================
# Object that handles the printing of an assembly
# 
# Supplied with an assembler, recieves calls to add, delete, and modify rooms,
# doors, and events
# 
# A printout is actualized each time a modifcation is made to the data being
# worked on by the assembler
# The current page (dungeon floor) is printed to the console
#------------------------------------------------------------------------------
class Assembly_Printer < Dungeon_Printer
	
	#--------------------------------------------------------------------------
	# > Initialization with a refernce to the assembler and its assembly
	#   specified
	#--------------------------------------------------------------------------
	def initialize(assembler, assembly)
		super()
		
		@asm = assembler
		@assembly = assembly
	end
	
	#--------------------------------------------------------------------------
	# DUNGEON PRINTING METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Starts an assembly printing, creating the inital document
	#--------------------------------------------------------------------------
	def start_print
		create_document
	end
	#--------------------------------------------------------------------------
	# > Creates a Document containing a blank page for each floor of the
	#   dungeon
	#--------------------------------------------------------------------------
	def create_document
		@document = Document.new
		@document.append(Page.blank_page(*page_dim, BLOCK_WIDTH, BLOCK_LENGTH))
	end
	#--------------------------------------------------------------------------
	# > The dimensions of a given page are those of the assembly with an
	#   extra 1 block added above and below
	#--------------------------------------------------------------------------
	def page_dim
		[@assembly.max_row + 2, @assembly.max_col + 2]
	end
	#--------------------------------------------------------------------------
	# > Returns the page corresponding to the current floor being worked on in
	#   the assembler
	#--------------------------------------------------------------------------
	def current_page
		@document.page(@assembly.floor_no)
	end
	#--------------------------------------------------------------------------
	# > Called from the assembler when the dimensions of the rooms array
	#   changes
	#--------------------------------------------------------------------------
	def resize(up, right, left, down)
		current_page.resize(up, right, left, down)
	end
	#--------------------------------------------------------------------------
	# > Unlike a Simple Printer that handles the rooms, events, and doors
	#   separately, the basic unit of an assembly Printer is a room (actually
	#   an assembly room, which has an assigned ID)
	#   
	# > Supplied with a room object, proceeds to print this room, along with
	#   its events and doors, to the document
	#--------------------------------------------------------------------------
	def print_room(room, coord)
		
		# Create and print the room block
		special = (room.tag ? room.tag.to_s.upcase : '_')
		block = Block_Templates.room_block(nil, special)
		@document.print_block_replace(block, coord)
		
		# Print doors
		room.doors.each { |door| print_door(door, coord[1..2]) if door }
		
		return if room.events.empty?
		
		# Create and print the events block
		block = Block_Templates.events_block(room.events)
		
		#puts block.to_s
		
		begin @document.print_block_edit(block, coord, [1, 1])
		rescue Printing_Error => error
			@handler.handle(error)
		end
	end
	#--------------------------------------------------------------------------
	# > Prints a door of the assembly, creating the appropriate block using its
	#   parameters
	#--------------------------------------------------------------------------
	def print_door(door, p_coord)
		to_room_id = door.dest
		
		# Obtain needed parameters
		sub_coord = door.sub_coord
		dir = door.dir
		
		puts door.ls.sformat
		
		begin current_page.print_asm_door(p_coord, door.ls, sub_coord, dir)
		rescue Printing_Error => error
			@handler.handle(error)
		end
	end
	#--------------------------------------------------------------------------
	# > Removes the room at the specified coordinates
	#--------------------------------------------------------------------------
	def unprint_room(coord)
		@document.print_block_replace(current_page.blank_block, coord)
	end
	
	#--------------------------------------------------------------------------
	# ACTUALIZATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Writes the current page of the document to the console
	#   
	# > To actualize the cursor without directly modifying the printing
	#   document, a copy of the current page is made, to which the cursor is
	#   printed
	#   
	# > The copied page is then written to the console and disposed of
	#--------------------------------------------------------------------------
	def actualize_printout
		pg_copy = current_page.dup
		
		# Obtain cursor block parameters
		cursor_block = Print_Block.new("%- - %", "%    %", "% - -%")
		
		#cursor_block = Block_Templates.cursor_block(??)
		bip_coord = Block_Templates.cursor_block_coord(@assembly.sub_cursor)
		
		# Print the cursor to the copied page
		begin pg_copy.print(cursor_block, @assembly.print_coord[1..2], bip_coord, :center)
		rescue Printing_Error => error
			@handler.handle(error)
		end
		
		# Writes the copied page w/ printed cursor block to the console
		puts(pg_copy.to_s)
	end
end

#------------------------------------------------------------------------------
# PRINTING ERROR
#==============================================================================
# Exception thrown in the context of a printing process
#------------------------------------------------------------------------------
class Printing_Error < Generic_Error
	
	#--------------------------------------------------------------------------
	# > List of messages
	#--------------------------------------------------------------------------
	def messages
		[
			"Block Printing: Block %s of %d exceeded -> requested from %d to %d\n" +
				"\tBlock requested to print:\n%s",
			"Sub-block Creation: Block %s of %d exceeded -> requested from %d to %d" +
				"\tBlock requested to print:\n%s",
			"Page block-edit Printing: Page %s of %d exceeded -> requested from %d to %d",
			"Page block-edit Printing: %s must be of length 2 -> specified length of %d",
			"Page block-replace Printing: Page %s of %d exceeded -> requested coordinate at %d"
		]
	end
end

#------------------------------------------------------------------------------
# PRINTING HANDLER
#==============================================================================
# Exception handler for printing errors
#------------------------------------------------------------------------------
class Printing_Handler < Handler
	
	#--------------------------------------------------------------------------
	# > Displays the error and its backtrace and exits the program
	#   unconditionally
	#   
	# > Printing errors are DANGEROUS man!
	#--------------------------------------------------------------------------
	def handle(error)
		super(error)
		
		puts error.backtrace
		
		exit(1)
	end
	#--------------------------------------------------------------------------
	# > List of handled error types
	#--------------------------------------------------------------------------
	def handled_types
		super << Printing_Error
	end
end