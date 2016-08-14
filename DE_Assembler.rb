require "#{Dir.pwd}/DE_Assembly_Objects.rb"

class Dungeon_Assembler
	
end

#------------------------------------------------------------------------------
# MANUAL ASSEMBLER
#==============================================================================
# Assembles a dungeon according wholly to User-inputed commands
# 
# The User controlls the cursor of an assembly
# Selecting objects opens contextual menus that require typed commands; such
# circumstances are handled by a special Operator class
#------------------------------------------------------------------------------
class Dungeon_ManualAssembler < Dungeon_Assembler
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :assembly
	
	#--------------------------------------------------------------------------
	# > Member variable assignment and manager setup
	#--------------------------------------------------------------------------
	def initialize
		
		
		# Mixins
		self.class.include Assembly_Toolbox
	end
	#--------------------------------------------------------------------------
	# > Initializes Manager classes
	#--------------------------------------------------------------------------
	def setup_managers
		@asm_printer = Assembly_Printer.new(self, @assembly)
		@asm_op      = Assembly_Operator.new(self, @assembly)
	end
	#--------------------------------------------------------------------------
	# > Begins an assembly, either from scratch or by editing the specified one
	#   
	# > Calls on the printer to start printing and opens the Operator for User
	#   input
	#--------------------------------------------------------------------------
	def start(assembly = nil)
		@assembly = (assembly ? assembly : Assembly.new)
		
		setup_managers
		@assembly.assign_printer(@asm_printer)
		
		@asm_op.announce(:open_title)
		@asm_op.announce(:open_print)
		@asm_printer.start_print
		
		@asm_op.announce(:open_oprtr)
		
		# If starting from scratch, places a single room into the assembly
		# Else the current assembly is fully reprinted
		unless assembly
			place_room(Assembly_Room.new, @assembly.cursor, false)
		else @assembly.full_reprint
		end
		
		# Run testing code
		#do_testing unless assembly
		
		@asm_op.open
		@asm_op.run until @asm_op.closed?
		
		@asm_op.announce(:closing)
		
		# Create a duplicate of the assembly and discard of member variables
		# TODO: assembly duplication?
		asm_dup = @assembly.dup
		@assembly = nil
		@asm_printer = nil
		@asm_op      = nil
		
		return asm_dup
	end
	#--------------------------------------------------------------------------
	# > Debugging
	#--------------------------------------------------------------------------
	def do_testing
		
		# Create sample objects for testing
		place_room(Assembly_Room.new, [0, 0, 1])
		place_room(Assembly_Room.new, [0, 1, 1])
		place_room(Assembly_Room.new, [0, 1, 0])
		
		@assembly.room_at([0, 0, 1]).add_event(Switch.new(1, 2))
		
		@assembly.room_at([0, 0, 0]).doors[1] = Assembly_Door.new(LS.new([[1, 1]]), 2, 1)
		
		@assembly.room_at([0, 0, 1]).doors[3] = Assembly_Door.new(LS.new, 2, 3)
		@assembly.room_at([0, 1, 0]).doors[1] = Assembly_Door.new(LS.new, 2, 1)
		
		@assembly.tag_command(:x)
		@assembly.tag_command(:e, [0, 1, 0])
		
		@assembly.reprint_object_at
		
		#compile_assembly("test")
	end
	
	#--------------------------------------------------------------------------
	# ASSEMBLY METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Places the room at the specified coordinates
	#   
	# > Resizes the rooms array and printer automatically, unless otherwise
	#   specified
	#--------------------------------------------------------------------------
	def place_room(room, coord = @assembly.cursor, resize = true)
		@assembly.place_room(room, coord, resize)
	end
	#--------------------------------------------------------------------------
	# > Removes a room at the specified coordinates
	#--------------------------------------------------------------------------
	def remove_room(coord = @assembly.cursor)
		@assembly.remove_room(coord)
	end
	#--------------------------------------------------------------------------
	# > Calls on the assembly to compile itself, producing a new standard
	#   dungeon with the specified name
	#   
	# > The dungeon is made immutable and assigned to the Administrator
	#--------------------------------------------------------------------------
	def compile_assembly(name)
		@asm_op.announce(:compile_begin)
		
		dungeon = @assembly.compile(name)
		
		dungeon.freeze
		@asm_op.announce(:compile_finish)
		
		Dungeon_Admin.admin.workspace.insert_next(dungeon)
		
		@asm_op.set_menu(:yn_exit)
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY MENU REPOSITORY
#==============================================================================
# Module that stores static menu data used to create menus when called on by
# the Operator
#------------------------------------------------------------------------------
module Assembly_Menu_Repository
	
	require "#{Dir.pwd}/DE_Assembly_Objects.rb"
	include Assembly_Toolbox
	
	#--------------------------------------------------------------------------
	# > Assigns current directiory and includes other modules
	#--------------------------------------------------------------------------
	def self.init	
		require "#{Dir.pwd}/DE_Assembly_Objects.rb"
		
		include Assembly_Toolbox
	end
	
	#--------------------------------------------------------------------------
	# DYNAMIC MENU CREATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates a menu, retrieving predefined information assigned by the
	#   specified menu name
	#--------------------------------------------------------------------------
	def get_menu(name)
		@name = name
		
		# Attempt to get a Y/N menu
		menu = yn_menu
		return menu if menu
		
		# Construct a default menu
		Menu.new(@name, command_list, message, *open_close_methods)
	end
	#--------------------------------------------------------------------------
	# > Returns the list of commands for the current menu
	#   
	# > Menu commands are nearly always internal calls to the Operator, except
	#   in certain cases where it is much more efficient to communicate with
	#   other classes (i.e. cursor movement)
	#--------------------------------------------------------------------------
	def command_list
		case @name
		when :background then [
				Command.new(:w,  @assembly.method(:cursor_move_up)),
				Command.new(:a,  @assembly.method(:cursor_move_left)),
				Command.new(:s,  @assembly.method(:cursor_move_down)),
				Command.new(:d,  @assembly.method(:cursor_move_right)),
				Command.new(:q,  @assembly.method(:move_floor_down)),
				Command.new(:e,  @assembly.method(:move_floor_up)),
				
				Command.new(:space,        method(:on_background_select)),
				Command.new(:back_slash,   method(:on_background_back))
			]
		when :assembly then [
				Command.new(:compile,      method(:on_compile_assembly), [String]),
				Command.new(:exit,         method(:on_assembly_exit)),
				
				Command.new(:back_slash,   method(:cancel))
			]
		when :room then [
				Command.new(:d,            method(:on_room_select_doors)),
				Command.new(:e,            method(:on_room_select_events)),
				Command.new(:s,            method(:on_room_select_tags)),
				Command.new(:x,            method(:on_room_remove)),
				
				Command.new(:back_slash,   method(:on_room_back))
			]
		when :room_tags then [
				Command.new(:e,            method(:on_tag_command), [], [:e]),
				Command.new(:x,            method(:on_tag_command), [], [:x]),
				Command.new(:c,            method(:on_tag_command), [], [:c]),
				
				Command.new(:back_slash,   method(:cancel))
			]
		when :events then [
				Command.new(:space,        method(:on_events_select_place)),
				
				Command.new(:back_slash,   method(:cancel))
			]
		when :event_place then [
				Command.new(:i,            method(:on_place_event)),
				Command.new(:s,            method(:on_place_event), [Integer]),
				Command.new(:x,            method(:on_delete_event)),
				
				Command.new(:back_slash,   method(:cancel))
			]
		when :doors then [
				Command.new(:space,        method(:on_door_create)),
				Command.new(:w,            method(:on_modify_door), [], [SUB_UP]),
				Command.new(:a,            method(:on_modify_door), [], [SUB_LEFT]),
				Command.new(:d,            method(:on_modify_door), [], [SUB_RIGHT]),
				Command.new(:s,            method(:on_modify_door), [], [SUB_DOWN]),
				Command.new(:q,            method(:on_modify_door), [], [SUB_BELOW]),
				Command.new(:e,            method(:on_modify_door), [], [SUB_ABOVE]),
				
				Command.new(:back_slash,   method(:cancel))
			]
		when :door_edit_dest then [
				Command.new(:w,            method(:door_edit), [], [:dest, SUB_UP]),
				Command.new(:a,            method(:door_edit), [], [:dest, SUB_LEFT]),
				Command.new(:d,            method(:door_edit), [], [:dest, SUB_RIGHT]),
				Command.new(:s,            method(:door_edit), [], [:dest, SUB_DOWN]),
				Command.new(:q,            method(:door_edit), [], [:dest, SUB_BELOW]),
				Command.new(:e,            method(:door_edit), [], [:dest, SUB_ABOVE]),
				
				Command.new(:back_slash,   method(:on_door_edit_cancel))
			]
		when :door_edit_dir then [
				Command.new(:s,            method(:door_edit), [], [:dir, 0]),
				Command.new(:d,            method(:door_edit), [], [:dir, 1]),
				Command.new(:f,            method(:door_edit), [], [:dir, 2]),
				
				Command.new(:back_slash,   method(:on_door_edit_cancel))
			]
		when :door_edit_ls then [
				Command.new(:add,          method(:door_edit), [Integer, Integer], [:ls, true]),
				Command.new(:del,          method(:door_edit), [Integer],  [:ls, false]),
				
				Command.new(:d,            method(:on_door_complete)),
				Command.new(:back_slash,   method(:on_door_edit_cancel))
			]
		when :door_edit_all then [
				Command.new(:dir,          method(:on_door_all_edit_dir)),
				Command.new(:ls,           method(:on_door_all_edit_ls)),
				Command.new(:x,            method(:on_door_delete)),
				
				Command.new(:back_slash,   method(:on_door_complete))
			]
		else []
		end
	end
	#--------------------------------------------------------------------------
	# > Returns the opening message for the current menu
	#--------------------------------------------------------------------------
	def message
		case @name
		when :assembly
			"ASSEMBLY MENU -\n" +
			"Type and enter 'compile:name' to compile the assembly into a dungeon with the specified name\n" +
			"Type and enter 'exit' to exit the assembler\n" +
			"Type and enter '\\' to go back\n"
		when :room
			"ROOM EDITING -\n" +
			"   'd' -> modify doors\n" +
			"   'e' -> modify events\n" +
			"   's' -> assign entrace/exit\n" +
			"   'x' -> delete room\n" +
			"   '\\' -> cancel\n"
		when :room_tags
			"EDIT ROOM TAGS -\n" +
			"	'e' -> assign this room to the entrance\n" +
			"	'x' -> assign this room to the exit\n" +
			"	'c' -> unassign this room's tags\n" +
			"   '\\' -> go back\n"
		when :events
			"ROOM EVENTS -\n" +
			"	'space' -> add new event\n" +
			"	#      -> edit event of #\n" +
			"	'\\'     -> cancel\n"
		when :event_place
			"ADD/MODIFY EVENT -\n" +
			"Type and enter 'i' for item\n" +
			"Type and enter 's:#' for a switch with # states\n" +
			"Type and enter 'x' to delete this event\n" +
			"Type and enter '\\' to cancel\n"
		when :doors
			"ROOM DOORS -\n" +
			"	'space'  -> add new door\n" +
			"	'wasdqe' -> edit door in the specifed direction\n" +
			"	'\\'      -> cancel\n"
		when :door_edit_dest
			"EDIT DOOR DESTINATION -\n" +
			"	'wasdqe' -> select destination room in the specified direction\n" +
			"	'\\'      -> go back\n"
		when :door_edit_dir
			"EDIT DOOR DIRECTION -\n" +
			"	's' -> one-way going to destination\n" +
			"	'd' -> one-way coming from destination\n" +
			"	'f' -> bidirectional\n" +
			"	'\\' -> go back\n"
		when :door_edit_ls
			"EDIT DOOR LOCK SPEC. -\n" +
			"Type and enter 'add:e_id,state' to add the specified event-state pair to the LS\n" +
			"Type and enter 'del:e_id' to delete the specified event-state pair from the LS\n" +
			"Type and enter 'd' to finish\n" +
			"Type and enter '\\' to go back\n"
		when :door_edit_all
			"EDIT DOOR PROPERTIES -\n" +
			"Type and enter 'dir' to modify the direction\n" +
			"Type and enter 'ls' to modify the lock specification\n" +
			"Type and enter 'x' to delete this door\n" +
			"Type and enter '\\' to save changes and go back\n"
		else ""
		end
	end
	#--------------------------------------------------------------------------
	# > Returns the opening and closing methods for the current menu
	#--------------------------------------------------------------------------
	def open_close_methods
		case @name
		when :room          then [method(:on_room_select), method(:on_room_unselect)]
		when :events        then [method(:on_events), nil]
		when :event_place   then [method(:event_place_open), nil]
		else [nil, nil]
		end
	end
	#--------------------------------------------------------------------------
	# > Returns the specified Y/N menu
	#--------------------------------------------------------------------------
	def yn_menu
		case @name
		when :yn_fix_thresh
			YesNo_Menu.new(:yn_fix_thresh,
				"A door must be placed between two rooms\n" +
				"Would you like to add a new room adjacent to this one?",
				method(:fix_bad_thresh),
				method(:end_door_dialog)
			)
		when :yn_exit
			YesNo_Menu.new(:yn_exit,
				"Would you like to exit the assembler at this time?\n" +
				"All work will be saved in the current Workspace",
				method(:close),
				method(:cancel)
			)
		end
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY OPERATOR
#==============================================================================
#------------------------------------------------------------------------------
class Assembly_Operator < Keystroke_Operator
	
	#--------------------------------------------------------------------------
	# > Initialization with a reference to the assembler and its assembly
	#   
	# > Also creates an "Interaction" object used to moniter keystrokes for
	#   more dynamic input
	#--------------------------------------------------------------------------
	def initialize(assembler, assembly)
		
		# Mixins
		Assembly_Menu_Repository.init
		self.class.include Assembly_Menu_Repository
		
		@asm = assembler
		@assembly = assembly
		@static_menus = false
		
		super(Assembly_Handler.new(self), nil, :background, false)
	end
	#--------------------------------------------------------------------------
	# > Announcements hash
	#--------------------------------------------------------------------------
	def announcements
		{
			:open_title     => Announcement.new(
				"%-----------------------%\n" +
				 "| DUNGEON ASSEMBLER 1.0 |\n" +
				 "%-----------------------%\n\n"),
			:open_asm       => Announcement.new("Creating assembly and sub-manager classes...", 1),
			:open_print     => Announcement.new("Opening assembly printer...", 1),
			:open_oprtr     => Announcement.new("Opening operator...", 1, 2),
			:closing        => Announcement.new("Closing assembler...", 1),
			
			:room_place     => Announcement.new("Room placed at coordinates %s"),
			:room_remove    => Announcement.new("Room removed at coordinates %s"),
			
			:event_place    => Announcement.new("Event of ID %s placed"),
			:event_edit     => Announcement.new("Type 'i' for item, and 's:#' for a switch with " +
				"# states\nType '\\' to cancel"),
			:event_remove_succ => Announcement.new("Event of ID %s was removed"),
			
			:door_place     => Announcement.new("Door successfully placed"),
			:door_update    => Announcement.new("Door successfully updated"),
			:door_delete    => Announcement.new("Door was removed"),
			
			:compile_begin  => Announcement.new("\n\nDUNGEON COMPILATION\n" +
				"-----------------------\n" +
				"Beginning compilation...\n\n", 0, 2),
			:compile_finish => Announcement.new("\nCompilation complete!\n" +
				"Compiled dungeon loaded to the Administrator\n\n")
		}
	end
	
	#--------------------------------------------------------------------------
	# BACKGROUND MENU
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > When a selection is made in the "background" (i.e. the grid of the
	#   assembler)
	#   
	# > Processing is dependent upon sub-cursor selection and the object at the
	#   cursor
	#--------------------------------------------------------------------------
	def on_background_select
		center = @assembly.center_select?
		object = @assembly.object_at
		
		puts "ASSEMBLY CURSORS"
		puts @assembly.cursor.to_s
		puts @assembly.sub_cursor.to_s
		
		puts "SELECTED ROOM: #{@assembly.room_at}"
		puts "SELECTED OBJECT: #{@assembly.object_at}"
		
		# If center select, add or modify a room
		# If thresh. select, add or modify a door
		add_menu(:room)         if  center &&  object
		on_place_room           if  center && !object
		on_modify_door(object)  if !center &&  object
		on_door_create          if !center && !object
	end
	#--------------------------------------------------------------------------
	# > Opens the assembler menu
	#--------------------------------------------------------------------------
	def on_background_back
		add_menu(:assembly)
	end
	
	#--------------------------------------------------------------------------
	# ASSEMBLER MENU
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Requests the assembler to compile the assembly
	#--------------------------------------------------------------------------
	def on_compile_assembly(name)
		@asm.compile_assembly(name)
	end
	#--------------------------------------------------------------------------
	# > Opens the menu asking if the User would like to exit the assembler
	#--------------------------------------------------------------------------
	def on_assembly_exit
		add_menu(:yn_exit)
	end
	
	#--------------------------------------------------------------------------
	# ROOM MENUS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Calls on the assembler to place a room at the cursor
	#--------------------------------------------------------------------------
	def on_place_room
		@asm.place_room(Assembly_Room.new)
		announce(:room_place, @assembly.cursor[1..2])
	end
	#--------------------------------------------------------------------------
	# > Upon opening to the room editing menu, save the selected room
	#--------------------------------------------------------------------------
	def on_room_select
		@assembly.reprint_object_at
		
		@room = @assembly.room_at
	end
	#--------------------------------------------------------------------------
	# > Go to "Doors" menu
	#--------------------------------------------------------------------------
	def on_room_select_doors
		add_menu(:doors)
	end
	#--------------------------------------------------------------------------
	# > Go to "Events" menu
	#--------------------------------------------------------------------------
	def on_room_select_events
		add_menu(:events)
	end
	#--------------------------------------------------------------------------
	# > Go to "Tags" menu
	#--------------------------------------------------------------------------
	def on_room_select_tags
		add_menu(:room_tags)
	end
	#--------------------------------------------------------------------------
	# > Calls on the assembler to remove the room at the cursor
	#   
	# > Reverts to the background menu
	#--------------------------------------------------------------------------
	def on_room_remove
		@asm.remove_room
		announce(:room_remove, @assembly.cursor[1..2])
		
		cancel
	end
	#--------------------------------------------------------------------------
	# > Reverts to the background menu
	#--------------------------------------------------------------------------
	def on_room_back
		@assembly.reprint
		@room = nil
		
		@object_creation = false
		
		cancel
	end
	#--------------------------------------------------------------------------
	# > ???
	#--------------------------------------------------------------------------
	def on_tag_command(command)
		@assembly.tag_command(command)
		
		cancel
	end
	#--------------------------------------------------------------------------
	# > Upon closing to the background menu, reprint the selected room
	#--------------------------------------------------------------------------
	def on_room_unselect
		@room = nil
	end
	
	#--------------------------------------------------------------------------
	# EVENT MENUS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Opening Proc for the "events" menu
	#   
	# > Displays a list of events in this room before the menu is opened for
	#   input
	#--------------------------------------------------------------------------
	def on_events
		puts "\nEvents in selected room:"
		
		# Display list of events and assigns temporary menu commands
		@room.events.each_with_index { |event, i|
			index = (i + 1).to_s
			
			puts "##{index}: #{event.sformat_asm}"
			
			comm = Command.new(index, method(:on_modify_event), [], [i])
			current_menu.add_command(comm)
		}
	end
	#--------------------------------------------------------------------------
	# > Goes to the event placement menu
	#--------------------------------------------------------------------------
	def on_events_select_place
		add_menu(:event_place)
	end
	#--------------------------------------------------------------------------
	# > Displays event being modified upon opening the edit/add event menu
	#--------------------------------------------------------------------------
	def event_place_open
		return unless @event
		
		puts "Modifying Event of ID #{@event.id}"
	end
	#--------------------------------------------------------------------------
	# > Creates and places an event, determining it's type from the specified
	#   parameters
	#   
	# > May be a new event or one to replace an existing one, depending on the
	#   context of the last menu
	#--------------------------------------------------------------------------
	def on_place_event(states = -1)
		unless states == -1 || states > 1
			raise Assembly_Error.new(0)
			cancel
		end
		
		# Checks if this is a new event, or a replacement for an old one
		@object_creation = @event.nil?
		
		# Determine event ID from the assembly or as specified
		ev_id =
		if @object_creation then @assembly.new_event_id
		else @event.id
		end
		
		# Creates the event from the parameters
		event = create_event(states, ev_id)
		
		# Either appends the event to the room or replaces the old one
		if @object_creation
			@room.add_event(event)
		else replace_event(event)
		end
		
		announce(:event_place, event.id)
		@object_creation = false
		cancel
	end
	#--------------------------------------------------------------------------
	# > Creates an event with the given parameters, inferring the type
	#--------------------------------------------------------------------------
	def create_event(states, ev_id)
		event = (states > 0 ? Switch.new(ev_id, states, 0) : Item.new(ev_id))
	end
	#--------------------------------------------------------------------------
	# > Replaces the event in the room with the same event ID
	#--------------------------------------------------------------------------
	def replace_event(new_event)
		index = @room.events.index { |event| event.id == new_event.id }
		
		@room.events[index] = new_event
		
		@event = nil
	end
	#--------------------------------------------------------------------------
	# > Deletes the currently selected event, if any
	#--------------------------------------------------------------------------
	def on_delete_event
		if @event
			@room.events.delete(@event)
			
			announce(:event_remove_succ, @event.id)
		end
		
		@event = nil
		
		cancel
	end
	#--------------------------------------------------------------------------
	# > Opens the event creation dialogue, but specifies an event to replace
	#   in the current room
	#--------------------------------------------------------------------------
	def on_modify_event(index)
		@event = @room.events[index]
		
		add_menu(:event_place)
	end
	
	#--------------------------------------------------------------------------
	# DOOR MENUS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates a new door to be placed in the selected room and begins the
	#   creation process
	#--------------------------------------------------------------------------
	def on_door_create
		@door = Assembly_Door.new
		@object_creation = true
		
		add_menu(:door_edit_dest)
	end
	#--------------------------------------------------------------------------
	# > Supplied with either a sub-coordinate or a door itself, gets the
	#   specified door at the and opens the menu to modify its properties
	#   
	# > Does nothing if no door is there
	#--------------------------------------------------------------------------
	def on_modify_door(param = @assembly.sub_cursor)
		@door =
		if param.is_a?(Integer)
			@assembly.door_at(param)
		else param
		end
		
		return if !@door
		
		add_menu(:door_edit_all)
	end
	#--------------------------------------------------------------------------
	# > Assigns the specified value to the specified door property from within
	#   an error-handling block
	#   
	# > Processes the next menu to be opened
	#--------------------------------------------------------------------------
	def door_edit(property, *values)
		begin
			case property
			when :dest then edit_door_dest(values[0])
			when :dir  then @door.set_dir(values[0])
			when :ls   then edit_door_ls(*values)
			end
		rescue Assembly_Error => error
			@handler.handle(error)
			return
		end
		
		# If editing an old door, simply return to the last menu
		# Else creating a new door, so proceed to the next menu
		if !@object_creation then cancel
		else set_menu((property == :dest ? :door_edit_dir : :door_edit_ls))
		end
	end
	#--------------------------------------------------------------------------
	# > Edits the current door's destination by assigning its sub-coordinate
	#   
	# > Raises an error if the specified threshold is incomplete (it does not
	#   bridge two rooms) or if it is invalid (it does not coincide with the
	#   door's direction)
	#--------------------------------------------------------------------------
	def edit_door_dest(sub_coord)
		@door.set_sub_coord(sub_coord)
		
		# Invalid and incomplete thresholds identifies differently for
		# different modes of selection
		if @assembly.thresh_select?
			raise Assembly_Error.new(5) if !@assembly.moveable_thresh?(sub_coord)
			raise Assembly_Error.new(4) if !@assembly.complete_threshold?(@assembly.sub_cursor)
		else raise Assembly_Error.new(4) if !@assembly.complete_threshold?(sub_coord)
		end
	end
	#--------------------------------------------------------------------------
	# > Fixes a "bad threshold" (only one room) by adding a new room to the
	#   empty side
	#   
	# > Called from the ':yn_fix_thresh' menu, returns handling to the previous
	#   menu when finished
	#--------------------------------------------------------------------------
	def fix_bad_thresh(sub_coord = @door.sub_coord)
		
		# Check which side of the threshold is missing a room
		# Assign that "side" to the coordinate
		coord = @assembly.cursor.dup
		unless @assembly.room_at(coord).nil?
			Assembly.move_coord(sub_coord, coord)
		end
		
		# Place a room at the invalid coordinates and close the current y/n
		# menu to resume door editing/creation
		@asm.place_room(Assembly_Room.new, coord)
		set_menu(:door_edit_dir)
	end
	#--------------------------------------------------------------------------
	# > Edits the current door's LS, adding or removing the specified event-
	#   state pair
	#   
	# > Does a preliminary check for validity
	#--------------------------------------------------------------------------
	def edit_door_ls(adding, event_id, state = -1)
		valid_es_pair?(adding, event_id, state)
		
		# Adds or removes the pair
		if adding
			@door.ls.add_es_pair(event_id, state)
		else @door.ls.remove_es_pair(event_id)
		end
	end
	#--------------------------------------------------------------------------
	# > Checks if the specified event-state pair is valid for addition to or
	#   deletion from an LS, raising different errors if not so
	#   
	# > Checks that the event exists, has a large enough state count, and is
	#   (not) already specified within the LS
	#--------------------------------------------------------------------------
	def valid_es_pair?(adding, event_id, state)
		if !(adding ^ @door.ls.has_event?(event_id))
			raise Assembly_Error.new(3, (adding ? "already": "not"), event_id)
		end
		
		event = @assembly.get_event(event_id)
		
		raise Assembly_Error.new(1, event_id) if !event 
		raise Assembly_Error.new(2, event_id, event.state_count) if state >= event.state_count
	end
	#--------------------------------------------------------------------------
	# > Processes a cancellation on one of the door editing menus
	#   
	# > If editing an existing door, return to the super-editing menu
	# > Else if on the first editing menu, cancel the door creation, else go
	#   back to that last editing menu
	#--------------------------------------------------------------------------
	def on_door_edit_cancel
		return cancel unless @object_creation
		
		name = current_menu.name
		if name == :door_edit_dest then end_door_dialog
		else set_menu((name == :door_edit_dir ? :door_edit_dest : :door_edit_dir))
		end
	end
	#--------------------------------------------------------------------------
	# > Goes to the direction door editing menu
	#--------------------------------------------------------------------------
	def on_door_all_edit_dir
		add_menu(:door_edit_dir)
	end
	#--------------------------------------------------------------------------
	# > Goes to the LS door editing menu
	#--------------------------------------------------------------------------
	def on_door_all_edit_ls
		add_menu(:door_edit_ls)
	end
	#--------------------------------------------------------------------------
	# > Add the door to the assembly, dispose of the door, and return to the
	#   doors menu
	#   
	# > Displays announcement depedning on the context of door editing
	#--------------------------------------------------------------------------
	def on_door_complete
		place_door
		
		announce((@object_creation ? :door_place : :door_update))
		end_door_dialog
	end
	#--------------------------------------------------------------------------
	# > Places the current door into the selected room of the assembly
	#   according to the current model of door placement
	#   
	# > If the sub-coordinate of a door does not align with the current room,
	#   the room location of the door is changed and the door's sub-coordinate
	#   is flipped
	#--------------------------------------------------------------------------
	def place_door
		
		FIX THIS
		
		coord =
		if !model_sub_coord?(@assembly.sub_cursor)
			@door.flip
			modeled_coord_pair(@assembly.cursor, @assembly.sub_cursor)[0]
		else @assembly.cursor
		end
		room = @assembly.room_at(coord)
		
		room.doors[@door.sub_coord] = @door.dup
		
		@assembly.reprint_object_at(coord)
	end
	#--------------------------------------------------------------------------
	# > Deletes the current door from the assembly
	#--------------------------------------------------------------------------
	def on_door_delete
		@room.doors[@door.sub_coord] = nil
		
		@assembly.reprint_object_at
		@assembly.reprint_object_at(@assembly.cursor, @door.sub_coord)
		
		announce(:door_delete)
		
		end_door_dialog
	end
	#--------------------------------------------------------------------------
	# > Disposes of/resets door-related variables and returns to the last menu
	#--------------------------------------------------------------------------
	def end_door_dialog
		@door = nil
		@object_creation = false
		
		cancel
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY ERROR
#==============================================================================
# Exception thrown in the context of an Assembly
#------------------------------------------------------------------------------
class Assembly_Error < Generic_Error
	
	#--------------------------------------------------------------------------
	# > List of messages
	#--------------------------------------------------------------------------
	def messages
		[
			"State count must be greater than 1",
			"The event of ID %s does not exist",
			"The event of ID %s has a maximum of %s states",
			"The event of ID %s is %s included in this LS",
			"A door cannot be placed there",
			"A door cannot be placed there, please select another direction"
		]
	end
end

#------------------------------------------------------------------------------
# ASSEMBLY HANDLER
#==============================================================================
# Exception handler for assembly errors
#------------------------------------------------------------------------------
class Assembly_Handler < Handler
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	CMPL_ERROR_MSG = "Assembly compilation was canceled..."
	
	#--------------------------------------------------------------------------
	# > Initialization with the Assembly Operator specified
	#--------------------------------------------------------------------------
	def initialize(asm_op)
		@asm_op = asm_op
	end
	#--------------------------------------------------------------------------
	# > Allows for more specific handling for some errors, depending on the
	#   type
	#--------------------------------------------------------------------------
	def handle(error)
		super(error)
		
		handle_asm_error(error)  if error.is_a?(Assembly_Error)
		handle_cmpl_error(error) if error.is_a?(Compilation_Error)
	end
	#--------------------------------------------------------------------------
	# > Assembly Error handling
	#--------------------------------------------------------------------------
	def handle_asm_error(error)
		case error.errno
		when 4 then handle_bad_thresh
		end
	end
	#--------------------------------------------------------------------------
	# > Compilation Error handling
	#--------------------------------------------------------------------------
	def handle_cmpl_error(error)
		puts CMPL_ERROR_MSG
		
		@asm_op.reset_menu
	end
	#--------------------------------------------------------------------------
	# > Handles a "bad" threshold which has only one room
	#   
	# > Opens a menu that asks to place a new room
	#--------------------------------------------------------------------------
	def handle_bad_thresh
		@asm_op.set_menu(:yn_fix_thresh)
	end
	
	#--------------------------------------------------------------------------
	# > List of handled error types
	#--------------------------------------------------------------------------
	def handled_types
		super << Assembly_Error << Compilation_Error
	end
end