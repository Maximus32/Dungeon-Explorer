
#------------------------------------------------------------------------------
# CRAWL DUNGEON
#==============================================================================
# Dungeon-like object used in dungeon crawling
# 
# Actually a sub-class of dungeon with more capabilities that makes traversal
# and path fabrication easier
# For example, crawl dungeons are composed of crawl rooms, which maintain a
# reference to their ID
#------------------------------------------------------------------------------
class Crawl_Dungeon < Dungeon
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_accessor :event_hash
	
	#--------------------------------------------------------------------------
	# > ??
	#--------------------------------------------------------------------------
	def initialize(dungeon)
		rooms = []
		
		dungeon.each_room_with_id { |room, id|
			rooms.push(Crawl_Room.new(room, id))
		}
		
		super(dungeon.name.dup, rooms, dungeon.get_metadata)
	end
	#--------------------------------------------------------------------------
	# > Signals to lower objects to fully complete their initialization
	#   
	# > Also completes various tasks, such as building the event hash
	#--------------------------------------------------------------------------
	def finalize
		build_event_hash
		
		each_room { |room| room.finalize }
	end
	#--------------------------------------------------------------------------
	# > Builds a hash that stores events hashed to their ID
	#--------------------------------------------------------------------------
	def build_event_hash
		@event_hash = {}
		
		each_event { |event| @event_hash[event.id] = event }
	end
	
	def apply_ls(ls)
		ls.each { |event_id, state| @event_hash[event_id].set_state(state) }
	end
	#--------------------------------------------------------------------------
	# > Returns a room from the dungeon matching the specified information
	#   
	# > For code
	#   - :ev_id -> room containing the event of the specified ID
	#--------------------------------------------------------------------------
	def get_room(code, param)
		case code
		when :ev_id
			each_room { |room| return room if room.has_event?(param) }
		end
	end
end

#------------------------------------------------------------------------------
# CRAWL ROOM
#==============================================================================
# Room used in dungeon crawling
# 
# Maintains a reference to its ID (index in the dungeon room's list) as well
# as a collection of crawl doors
#------------------------------------------------------------------------------
class Crawl_Room < Room
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :id
	
	#--------------------------------------------------------------------------
	# > Initialization from a given standard room and ID within the context of
	#   its dungeon
	#--------------------------------------------------------------------------
	def initialize(std_room, id)
		@id = id
		
		doors = std_room.doors.collect { |door| Crawl_Door.new(door) }
		events = std_room.events.collect { |event| event.dup }
		super(doors, events)
	end
	#--------------------------------------------------------------------------
	# > Called from the crawl dungeon object to complete object creation
	#--------------------------------------------------------------------------
	def finalize
		each_door { |door| door.finalize }
	end
end

#------------------------------------------------------------------------------
# CRAWL DOOR
#==============================================================================
# Door used in dungeon crawling
# 
# Maintains an object reference to its destination room (useful for linked-
# list-like traversal)
#------------------------------------------------------------------------------
class Crawl_Door < Door
	
	SFORMAT_OPEN = "open door"
	SFORMAT_LOCKABLE = "door of LS (%s)"
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :dest_room
	
	#--------------------------------------------------------------------------
	# > Initialization with a standard door specifeid  in the context of its
	#   dungeon
	#--------------------------------------------------------------------------
	def initialize(std_door)
		super(std_door.dest, Crawl_LS.new(std_door.ls))
	end
	#--------------------------------------------------------------------------
	# > Called from the crawl dungeon object to complete object creation
	#   
	# > Destination room is assigned to a crawl room within the dungeon
	#--------------------------------------------------------------------------
	def finalize
		@dest_room = Dungeon_Crawler.dungeon.room_at(@dest)
	end
	#--------------------------------------------------------------------------
	# > String formatting
	#--------------------------------------------------------------------------
	def sformat
		if @ls.clear? then SFORMAT_OPEN
		else sprintf(SFORMAT_LOCKABLE, self.to_s)
		end
	end
end

#------------------------------------------------------------------------------
# CRAWL LS
#==============================================================================
# An LS within the context of a list of dungeon event-state pairs, giving it
# the ability to check its alignment
#------------------------------------------------------------------------------
class Crawl_LS < LS
	
	#--------------------------------------------------------------------------
	# > Initialization with a standard LS and the dungeon specified
	#--------------------------------------------------------------------------
	def initialize(std_ls)
		super(std_ls.es_pairs)
	end
	#--------------------------------------------------------------------------
	# > Checks if every event-state pair of this LS matches the event hash of
	#   the dungeon
	#--------------------------------------------------------------------------
	def aligned?
		return true if clear?
		
		!self.any? { |event_id, state|
			Dungeon_Crawler.dungeon.event_hash[event_id].state != state
		}
	end
	#--------------------------------------------------------------------------
	# > String formatting for traversal specifications
	#--------------------------------------------------------------------------
	def sformat(mode = 3)
		return super(mode) if mode < 3
		
		es_strs = self.collect { |event_id, state|
			"event #{event_id} to state #{state}"
		}
		
		es_strs.join(", ")
	end
end

#------------------------------------------------------------------------------
# PATH STEP
#==============================================================================
# A room paired with a door from another room that leads into this one and any
# events to modify in the room
# 
# The basic element of a path: an array of path steps represents a path
#------------------------------------------------------------------------------
class Path_Step
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :room
	attr_reader :door
	attr_reader :ls
	
	#--------------------------------------------------------------------------
	# > Initialization with the room, previous door, and LS specified
	#   
	# > A missing door implies an "entry" to a dungeon, or the start of a path
	#--------------------------------------------------------------------------
	def initialize(room, door = nil, ls = nil)
		@room = room
		@door = door
		@ls = ls
	end
	#--------------------------------------------------------------------------
	# > Checks if the LS is trivial (i.e. 'nil' or clear)
	#--------------------------------------------------------------------------
	def ls_trivial?
		!@ls || @ls.clear?
	end
end

#------------------------------------------------------------------------------
# PATH
#==============================================================================
# Represents a mutable sequence of rooms connected by doors, detailing events
# to change in a room (path steps)
# 
# Used in traversals and RTA construction
#------------------------------------------------------------------------------
class Path
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_reader :sequence
	
	#--------------------------------------------------------------------------
	# > Initialization with an array of path steps specified
	#--------------------------------------------------------------------------
	def initialize(path_steps = [])
		@sequence = path_steps
	end
	
	#--------------------------------------------------------------------------
	# SEQUENCE ACCESS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Sequence indexing
	#--------------------------------------------------------------------------
	def [](index)
		@sequence[index]
	end
	#--------------------------------------------------------------------------
	# > Start and end room reference
	#--------------------------------------------------------------------------
	def start;  @sequence[0];     end
	def end;    @sequence[-1];    end
	def length; @sequence.length; end
	#--------------------------------------------------------------------------
	# > Appends a room or path to the sequence
	#--------------------------------------------------------------------------
	def append(path_step)
		@sequence.push(path_step)
	end
	#--------------------------------------------------------------------------
	# > Adds a path to this one, concatenating their sequences
	#--------------------------------------------------------------------------
	def +(path)
		@sequence = @sequence + path.sequence
	end
	#--------------------------------------------------------------------------
	# > Inserts a path into this one at the specified index
	#--------------------------------------------------------------------------
	def insert(index, path)
		@sequence[index, 0] = path.sequence
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > String representation, a list of rooms with doors to take
	#--------------------------------------------------------------------------
	def to_s
		str = ""
		
		@sequence.each { |path_step|
			str += "Visit room: #{path_step.room.id}"
			
			str += " via #{path_step.door.sformat}" if path_step.door
			
			str += " and set #{path_step.ls.sformat}" unless path_step.ls_trivial?
			
			str += "\n"
		}
		
		str
	end
end

#------------------------------------------------------------------------------
# TRAVERSAL 
#==============================================================================
# Identical to a path except that it is immuatble and has been procured from a
# traversal generator
#------------------------------------------------------------------------------
class Traversal
	
	#--------------------------------------------------------------------------
	# > ???
	#--------------------------------------------------------------------------
	def initialize(path)
		@path = path
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > String formatting, a list of rooms with events to change
	#--------------------------------------------------------------------------
	def sformat(condensed = true)
		str = ""
		
		@path.sequence.each_with_index { |path_step, index|
			next if condensed && path_step.ls_trivial? &&
				(1..(@path.length - 2)) === index
			
			str += "Visit room: #{path_step.room.id}"
			
			str += " and set #{path_step.ls.sformat}" if !path_step.ls_trivial?
			
			str += "\n"
		}
		
		str
	end
	#--------------------------------------------------------------------------
	# > String representation
	#--------------------------------------------------------------------------
	def to_s
		sformat
	end
end