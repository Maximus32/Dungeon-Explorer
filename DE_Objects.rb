#------------------------------------------------------------------------------
# DUNGEON
#==============================================================================
# A Dungeon can be thought of as a mathematical graph with nodes as rooms and
# paths as doors to rooms
# 
# The most abstract dungeon cannot be easily visualized, so other dungeons with
# restrictions on the layout of their rooms are implemented
#------------------------------------------------------------------------------
class Dungeon
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :name
	
	attr_reader :rooms
	#--------------------------------------------------------------------------
	# > Dungeon initialization with specified rooms, metadata, and a name
	#--------------------------------------------------------------------------
	def initialize(name = "", rooms = [], meta = nil)
		@name = name
		@rooms = rooms
		
		assign_metadata(meta) if meta
	end
	#--------------------------------------------------------------------------
	# > Metadata assignment
	#   
	# > Overridden for more specific classes of dungeon
	#--------------------------------------------------------------------------
	def assign_metadata(meta)
		@enter_room_ID = meta[0].to_i
		@exit_room_ID = meta[1].to_i
	end
	#--------------------------------------------------------------------------
	# > Get metadata
	#--------------------------------------------------------------------------
	def get_metadata
		[@enter_room_ID, @exit_room_ID]
	end
	
	#--------------------------------------------------------------------------
	# ROOM ACCESS & MODIFICATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Adds a room to this dungeon
	#--------------------------------------------------------------------------
	def add_room(room)
		@rooms.push(room)
	end
	#--------------------------------------------------------------------------
	# > Room access
	#--------------------------------------------------------------------------
	def room_at(room_id)
		@rooms[room_id]
	end
	#--------------------------------------------------------------------------
	# > Room iteration
	#--------------------------------------------------------------------------
	def each_room
		@rooms.each { |room| next if room.unused?; yield room }
	end
	#--------------------------------------------------------------------------
	# > Room iteration with indexing
	#--------------------------------------------------------------------------
	def each_room_with_id
		@rooms.each_with_index { |room, id| next if room.unused?; yield room, id }
	end
	#--------------------------------------------------------------------------
	# > List of used rooms
	#--------------------------------------------------------------------------
	def used_rooms
		@rooms.select { |room| !room.unused? }
	end
	#--------------------------------------------------------------------------
	# > List of all doors
	#--------------------------------------------------------------------------
	def all_doors
		doors = []
		
		each_room { |room|
			room.each_door { |door|
				doors.push(door) unless doors.include?(door)
			}
		}
		
		doors
	end
	
	#--------------------------------------------------------------------------
	# EVENT ACCESS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Iterates across all events
	#--------------------------------------------------------------------------
	def each_event
		all_events.each { |event| yield event }
	end
	#--------------------------------------------------------------------------
	# > Returns a list of all events in this assembly
	#--------------------------------------------------------------------------
	def all_events
		events = []
		
		each_room { |room| events = events + room.events }
		
		events
	end
	#--------------------------------------------------------------------------
	# > Count of all events
	#--------------------------------------------------------------------------
	def event_count
		count = 0
		
		each_event { |event| count += 1 }
		
		count
	end
	
	#--------------------------------------------------------------------------
	# ???
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Determines if the specified door is reciprocal in the context of its
	#   room
	#   
	# > This is true if the destination room has a door_b with a destination
	#   room of door_a's current room and door_a and door_b have the same LS
	#--------------------------------------------------------------------------
	def reciprocal_door?(door_a, from_room_id)
		room_at(door_a.dest).doors.each { |door_b|
			next if door_b.dest != from_room_id
			next if door_b.ls != door_a.ls
			
			return true
		}
		
		return false
	end
	
	#--------------------------------------------------------------------------
	# OBJECT METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Freezes the dungeon object as well as the array of rooms, the events
	#   and doors of each room, and the rooms themselves
	#--------------------------------------------------------------------------
	def freeze
		super
		
		@rooms.freeze
		@rooms.each { |room|
			room.events.each { |event| event.freeze }
			room.events.freeze
			room.doors.freeze
			room.freeze
		}
	end
	#--------------------------------------------------------------------------
	# > Returns a copy of this dungeon
	#   
	# > Because DE_IO's 'read_dungeon' only returns immutable dungeons,
	#   duplicates are used for traversals and assembling RTAs in which changes
	#   to dungeon events are made
	#   
	# > Works for any sub-class of dungeon
	#--------------------------------------------------------------------------
	def dup
		rooms = @rooms.collect { |room| room.dup }
		
		(self.class).new(@name.dup, rooms, get_metadata)
	end
	
	#--------------------------------------------------------------------------
	# DUNGEON PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Indicates whether this type of dungeon can be printed
	#--------------------------------------------------------------------------
	def visualizable?
		return false
	end
	#--------------------------------------------------------------------------
	# > Checks whether the specified room ID points to the room that marks this
	#   dungeon's entrance
	#--------------------------------------------------------------------------
	def entrance?(room_id)
		@enter_room_ID == room_id
	end
	#--------------------------------------------------------------------------
	# > Checks whether the specified room ID points to the room that marks this
	#   dungeon's exit
	#--------------------------------------------------------------------------
	def exit?(room_id)
		@exit_room_ID == room_id
	end
	#--------------------------------------------------------------------------
	# > Returns an array of strings detailing this dungeon's "size"
	#   
	# > Defined in sub-classes
	#--------------------------------------------------------------------------
	def size_sformat
	end
end

#------------------------------------------------------------------------------
# EUCLIDEAN DUNGEON
#==============================================================================
# A dungeon whose rooms can be arranged in a 3-dimensional grid in discrete
# Euclidean space
# 
# This can be acheived by making every door go from a room A with coordinates
# (x, y, z) to a room B with coordinates (x ± 1, y, z), (x, y ± 1, z), or (x,
# y, z ± 1) (i.e. doors can be "drawn" between rooms that are "drawn" next to
# each other)
# 
# The z-axis represents "floors" and the x- and y-axes represent rows and col-
# umns (or lengths) respectively
# 
# Does not exclude "Quantum" dungeons so that a given coordinate can point to
# multiple rooms
# Also referred to as a "Cartesian" dungeon and an "Enumerable" dungeon
#------------------------------------------------------------------------------
class Euclidean_Dungeon < Dungeon
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :width
	attr_reader :length
	attr_reader :height
	
	#--------------------------------------------------------------------------
	# > Also assigns cartesian dimensions
	#--------------------------------------------------------------------------
	def assign_metadata(meta)
		super(meta)
		
		@height, @length, @width = meta[2..4]
	end
	#--------------------------------------------------------------------------
	# > Obtains dungeon metadata, augmented by dimensions
	#--------------------------------------------------------------------------
	def get_metadata
		super + [@height, @length, @width]
	end
	#--------------------------------------------------------------------------
	# > Number of rooms per "floor"
	#--------------------------------------------------------------------------
	def area
		@width * @length
	end
	#--------------------------------------------------------------------------
	# > Takes a raw room ID (index in the rooms array) and converts it to
	#   cartesian coordinates
	#--------------------------------------------------------------------------
	def coordinate(room_id)
		floor = room_id / area
		row = room_id % area / @width
		col = room_id % area % @width
		
		[floor, row, col]
	end
	#--------------------------------------------------------------------------
	# > Converts each raw room ID (index), converts it to coordinates, and
	#   returns the difference
	#--------------------------------------------------------------------------
	def coordinate_difference(room_id_1, room_id_2)
		coord_2 = coordinate(room_id_2)
		coordinate(room_id_1).each_with_index { |coord, i|
			coord_2[i] = coord - coord_2[i]
		}
		
		coord_2
	end
	#--------------------------------------------------------------------------
	# > Takes a cartesian coordinate and converts it to a room ID
	#--------------------------------------------------------------------------
	def index(coord)
		coord[0] * area + coord[1] * @width + coord[2]
	end
	#--------------------------------------------------------------------------
	# > Euclidean dungeons are not necessarily printable
	#--------------------------------------------------------------------------
	def visualizable?
		return false
	end
	#--------------------------------------------------------------------------
	# > Returns an array of strings detailing this dungeon's size, containing
	#   the number of rooms, floors, and events
	#--------------------------------------------------------------------------
	def size_sformat
		["#{@height} floors", "#{used_rooms.length} rooms", "#{event_count} events"]
	end
end

#------------------------------------------------------------------------------
# NON-QUANTUM DUNGEON
#==============================================================================
# A Euclidean dungeon such that each coordinate points to at most one room
# Most considerable dungeons are of this type
# 
# This is the only type of Dungeon that can be visualized and printed
# Also referred to as a "one-to-one" dungeon and a "visualizable" dungeon
#------------------------------------------------------------------------------
class Non_Quantum_Dungeon < Euclidean_Dungeon
	
	
	def visualizable?
		return true
	end
end

#------------------------------------------------------------------------------
# DUNGEON
#==============================================================================
# Type Map constant that is dependent on the declaration of alternate dungeon
# types
#------------------------------------------------------------------------------
class Dungeon
	
	# Constants
	D_TYPE_MAP = {
		"Eu" => Euclidean_Dungeon,
		"NQ" => Non_Quantum_Dungeon,
	}
end

#------------------------------------------------------------------------------
# ROOM
#==============================================================================
# Building block of a dungeon, maintains doors pointing to other rooms and a
# list of events contained within
#------------------------------------------------------------------------------
class Room
	
	#--------------------------------------------------------------------------
	# > Public varaibles
	#--------------------------------------------------------------------------
	attr_reader :doors
	attr_reader :events
	
	#--------------------------------------------------------------------------
	# > Initialization with doors, events, and the unused flag specified
	#--------------------------------------------------------------------------
	def initialize(doors = [], events = [], unused = false)
		@doors = doors
		@events = events
		
		@unused = unused
	end
	#--------------------------------------------------------------------------
	# > Adds a door to this room
	#--------------------------------------------------------------------------
	def add_door(door)
		@doors.push(door)
	end
	#--------------------------------------------------------------------------
	# > Adds more doors to the room
	#--------------------------------------------------------------------------
	def append_doors(mordors)
		@doors = @doors + mordors
	end
	#--------------------------------------------------------------------------
	# > Assigns the entire door list
	#--------------------------------------------------------------------------
	def assign_doors(doors)
		@doors = doors
	end
	#--------------------------------------------------------------------------
	# > Adds an event to this room
	#--------------------------------------------------------------------------
	def add_event(event)
		@events.push(event)
	end
	#--------------------------------------------------------------------------
	# > Door iteration
	#--------------------------------------------------------------------------
	def each_door
		@doors.each { |door| yield door }
	end
	#--------------------------------------------------------------------------
	# > Creates an unused room, used in place of 'nil' for properly constructed
	#   dungeons
	#--------------------------------------------------------------------------
	def self.empty_room
		Room.new([], [], true)
	end
	#--------------------------------------------------------------------------
	# > Returns the "unused" flag
	#--------------------------------------------------------------------------
	def unused?
		@unused
	end
	#--------------------------------------------------------------------------
	# > Checks if this room has the specified event or event ID
	#--------------------------------------------------------------------------
	def has_event?(param)
		if param.is_a?(Event)
			@events.include?(event)
		else @events.any? { |event| event.id == param}
		end
	end
	#--------------------------------------------------------------------------
	# > Room data copy
	#--------------------------------------------------------------------------
	def dup
		doors = @doors.collect { |door| door.dup }
		events = @events.collect { |event| event.dup }
		Room.new(doors, events, @unused)
	end
end

#------------------------------------------------------------------------------
# DOOR
#==============================================================================
# An object assigned to a room that provides access to other rooms during a
# traversal
# 
# A door is assigned a destination room ID and an LS (Lock Specification) that
# details how it can be unlocked
# A door with a "clear" LS will never be locked and essentially connects two
# rooms
#------------------------------------------------------------------------------
class Door
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :dest
	attr_reader :ls
	#--------------------------------------------------------------------------
	# > Door initialization specifying a destination room ID and an LS
	#--------------------------------------------------------------------------
	def initialize(dest = -1, ls = LS.new)
		@dest = dest
		@ls = ls
	end
	#--------------------------------------------------------------------------
	# > Sets the destination room
	#--------------------------------------------------------------------------
	def set_dest(dest)
		@dest = dest
	end
	#--------------------------------------------------------------------------
	# > Sets the lock specification
	#--------------------------------------------------------------------------
	def set_ls(ls)
		@ls = ls
	end
	
	#--------------------------------------------------------------------------
	# DOOR PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Determines if this door can be unlocked
	#--------------------------------------------------------------------------
	def loackable?
		return !@ls.clear?
	end
	#--------------------------------------------------------------------------
	# > Determines if this door is locked
	#--------------------------------------------------------------------------
	def locked?
		loackable? && @ls.aligned?
	end
	#--------------------------------------------------------------------------
	# > Determines if the door is unlocked
	#--------------------------------------------------------------------------
	def unlocked?
		!locked?
	end
	#--------------------------------------------------------------------------
	# > Door data copy
	#--------------------------------------------------------------------------
	def dup
		Door.new(@dest, @ls.dup)
	end
	#--------------------------------------------------------------------------
	# > Door string representation
	#--------------------------------------------------------------------------
	def to_s
		"#{@dest}" + (@ls.clear? ? "" : "-#{@ls.sformat(1)}")
	end
end

#------------------------------------------------------------------------------
# LS (Lock Specification)
#==============================================================================
# An object assigned to a door detailing how the door can be unlocked and
# accessible during a traversal
# 
# Uses "event-state" pairs: a list of events and their appropriate states
# needed to "align" the LS and open its parent door
# For example, a door needing key 2 and switch 3 pulled to state 2 would have
# an LS with an event-state pair array of [[2, 1], [3, 2]]
#------------------------------------------------------------------------------
class LS
	
	# Mixins
	include Enumerable
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :es_pairs
	
	#--------------------------------------------------------------------------
	# > LS initialization specifying a list of event-state pairs
	#--------------------------------------------------------------------------
	def initialize(event_state_pairs = [])
		@es_pairs = event_state_pairs
	end
	
	#--------------------------------------------------------------------------
	# LS MODIFICATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Adds an Event-State pair to this LS
	#   
	# > Can specify the Event and its state or them paired together in an Array
	#--------------------------------------------------------------------------
	def add_es_pair(*params)
		if params.length == 1
			@es_pairs.push(params[0])
		else @es_pairs.push(params)
		end
	end
	#--------------------------------------------------------------------------
	# > Removes the event state pair with the specified event ID
	#--------------------------------------------------------------------------
	def remove_es_pair(event_id)
		@es_pairs.delete_if { |es_pair| es_pair[0] == event_id }
	end
	
	#--------------------------------------------------------------------------
	# LS PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Determines if this LS actually specifies any event-state pairs
	#--------------------------------------------------------------------------
	def clear?
		@es_pairs.empty?
	end
	#--------------------------------------------------------------------------
	# > Equivalence of LSs is attributed to their 'ES_pairs'
	#--------------------------------------------------------------------------
	def ==(ls_d)
		self.es_pairs == ls_d.es_pairs
	end
	#--------------------------------------------------------------------------
	# > Returns the event ID from the event-state pair at the specified index
	#--------------------------------------------------------------------------
	def event_id(index)
		@es_pairs[index][0]
	end
	#--------------------------------------------------------------------------
	# > Checks if this LS has the specified event ID
	#--------------------------------------------------------------------------
	def has_event?(event_id)
		@es_pairs.any? { |es_pair| es_pair[0] == event_id }
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Iteration across event-state pairs
	#--------------------------------------------------------------------------
	def each
		@es_pairs.each { |es_pair| yield es_pair[0], es_pair[1] }
	end
	#--------------------------------------------------------------------------
	# > Formats this LS according to the specified mode
	#   
	# > 0 (printing horz. doors) -> a string of event-state pairs
	# > 1 (writing)  -> a string of event-state pairs (different delimitters)
	# > 2 (printing vert. doors) -> two strings of events and their states
	#--------------------------------------------------------------------------
	def sformat(mode = 0)
		case mode
		when 0
			ls_strs = @es_pairs.collect { |es_pair| es_pair.join("-") }
			
			return ls_strs.join(",")
		when 1
			ls_strs = @es_pairs.collect { |es_pair| es_pair.join(":") }
			
			return ls_strs.join("-")
		when 2
			ls_strs = [[], []]
			
			# Separate events and their states
			@es_pairs.each { |es_pair|
				ls_strs[0].push(es_pair[0])
				ls_strs[1].push(es_pair[1])
			}
			
			ls_strs[0] = ls_strs[0].join(",")
			ls_strs[1] = ls_strs[1].join(",")
			
			return ls_strs
		end
	end
	#--------------------------------------------------------------------------
	# > LS data copy
	#--------------------------------------------------------------------------
	def dup
		LS.new(@es_pairs.dup)
	end
end

#------------------------------------------------------------------------------
# EVENT
#==============================================================================
# An object assigned to a room that has a fixed number of states and can take
# on one state at a time
# 
# An event's state must be changed to unlock certain doors during a traversal
# 
# An event may be collectable, such as a key, in which case, its state need
# inly be changed once
#------------------------------------------------------------------------------
class Event

	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :id
	attr_reader :state
	attr_reader :state_count
	
	#--------------------------------------------------------------------------
	# > Initialization with id, # of states, and initial state specified
	#--------------------------------------------------------------------------
	def initialize(id, state_count, initial_state)
		@id = id
		@state_count = state_count
		
		@collectable = false
		
		set_state(initial_state)
	end
	#--------------------------------------------------------------------------
	# > Sets the state of this event with error checking
	#--------------------------------------------------------------------------
	def set_state(state)
		if state < 0 || state >= @state_count
			#TODO: throw error!
		end
		
		@state = state
	end
	#--------------------------------------------------------------------------
	# > Reterns whether this event can be "collected" as an item
	#--------------------------------------------------------------------------
	def collectable?
		@collectable
	end
	#--------------------------------------------------------------------------
	# > Formats this event as an event ID followed by its current state if
	#   non-collectable
	#   
	# > The mode specifies the separator to use for switches (0 for printing,
	#   1 for writing to a file)
	#--------------------------------------------------------------------------
	def sformat(mode = 0)
		event_str = @id.to_s
		
		unless collectable?
			sep = (mode == 0 ? '-' : ':')
			event_str << "#{sep}#{@state}"
		end
		
		event_str
	end
	#--------------------------------------------------------------------------
	# > Formats this event as its type and ID followed by the number of states,
	#   if a switch
	#   
	# > Used in assemblies
	#--------------------------------------------------------------------------
	def sformat_asm
		event_str = "(ID #{@id}) "
		
		event_str += self.class.to_s
		event_str += " of #{@state_count} states" unless collectable?
		
		event_str
	end
	#--------------------------------------------------------------------------
	# > String representation
	#--------------------------------------------------------------------------
	def to_s
		sformat
	end
end

#------------------------------------------------------------------------------
# SWITCH EVENT
#==============================================================================
# An event with two or more states that cannot be collected
# 
# Mimics a switch in a dungeon, that can remotely activate doors, but close
# others, and cannot be moved
#------------------------------------------------------------------------------
class Switch < Event
	def initialize(id, state_count, initial_state = 0)
		super(id, state_count, initial_state)
		
		@collectable = false
	end
end

#------------------------------------------------------------------------------
# ITEM EVENT
#==============================================================================
# An event with exactly two states that can be collected
# 
# Mimics an item or key in a dungeon, that can be obtained to gain access to
# new rooms
#------------------------------------------------------------------------------
class Item < Event
	def initialize(id)
		super(id, 2, 0)
		
		@collectable = true
	end
	#--------------------------------------------------------------------------
	# > "Collecting" an item during a traversal sets it's state to 1
	#--------------------------------------------------------------------------
	def collect
		set_state(1)
	end
end

class Path
	
	def initialize(param)
		if param.is_a?(Room)
			@room_list = [param]
		elsif param.is_a?(Array)
			@room_list = param
		end
	end
end

class RA
	
	def initialize(room, event_state_pairs)
		@room = room
		@es_pairs = event_state_pairs
	end
end
