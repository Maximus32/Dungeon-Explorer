#------------------------------------------------------------------------------
# PATH GENERATOR
#==============================================================================
# Object maintained by a crawler used to generate paths
# 
# Maintains a reference to the crawler's working dungeon and a set of modi-
# fiable start and end room IDs
# 
# Employs the reverse backtracker algorithm for path generation
#------------------------------------------------------------------------------
class Path_Generator
	
	#--------------------------------------------------------------------------
	# > Public variables
	#--------------------------------------------------------------------------
	attr_accessor :start_id
	attr_accessor :end_id
	
	#--------------------------------------------------------------------------
	# > Initialization with a dungeon and start and end room IDs specified
	#--------------------------------------------------------------------------
	def initialize(start_room_id, end_room_id)
		assign_start_end(start_room_id, end_room_id)
		
		require "#{Dir.pwd}/DE_Crawler_Objects.rb"
	end
	#--------------------------------------------------------------------------
	# > Setter for start and end room IDs
	#--------------------------------------------------------------------------
	def assign_start_end(start_room_id, end_room_id)
		@start_id = start_room_id
		@end_id = end_room_id
	end
	#--------------------------------------------------------------------------
	# > Resets instance variables, generates the clearlist, and assigns the
	#   room ID to LS hash
	#--------------------------------------------------------------------------
	def begin_generation(room_ls_hash)
		@sequence = []
		@completed_paths = []
		
		@clearlist = dungeon.rooms.collect { |room| false }
		@room_ls_hash = room_ls_hash
	end
	
	#--------------------------------------------------------------------------
	# SINGLE PATHS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates a single path between the start and end rooms
	#   
	# > A hash of room IDs to LSs can be specified to mark the path as to alter
	#   events within rooms during a traversal
	#--------------------------------------------------------------------------
	def make_single_path(room_ls_hash = {})
		begin_generation(room_ls_hash)
		
		success = step_single_path(dungeon.room_at(@start_id))
		raise Crawler_Error.new(0, @start_id, @end_id) if !success
		
		return Path.new(@sequence)
	end
	#--------------------------------------------------------------------------
	# > Step in a single-path fabrication
	#   
	# > First updates the clearlist, returning if within a previously visited
	#   room
	# > Proceeds to add the room to the sequence, and recursively step into
	#   other rooms
	#   
	# > If at the destination room, a success is returned
	# > If all doors have been checked, mark as a dead end and backtrack
	#--------------------------------------------------------------------------
	def step_single_path(room, door = nil)
		return if update_clearlist(room)
		
		@sequence.push(Path_Step.new(room, door, @room_ls_hash[room.id]))
		
		# Check if at destination and return on success
		return true if room.id == @end_id
		
		# Recursively check next rooms
		# On a single success, return upwards successively
		room.doors.each { |next_door|
			success = step_single_path(next_door.dest_room, next_door)
			return true if success
		}
		
		# Dead end
		@sequence.pop
		
		return false
	end
	#--------------------------------------------------------------------------
	# > Sets the specified room as cleared and returns the value of the
	#   clearlist before it was altered
	#--------------------------------------------------------------------------
	def update_clearlist(room)
		cleared = @clearlist[room.id]
		
		@clearlist[room.id] = true
		
		return cleared
	end
	
	#--------------------------------------------------------------------------
	# MULTIPLE PATHS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates an array of paths between the start and end rooms
	#   
	# > If no completed paths are found, a wall trapping error is raised
	#   
	# > Uses an exhastive reverse backtracking algorithm
	#--------------------------------------------------------------------------
	def make_paths(room_ls_hash = {})
		begin_generation(room_ls_hash)
		
		step_multi_path(dungeon.room_at(@start_id))
		raise Crawler_Error.new(0, @start_id, @end_id) if @completed_paths.empty?
		
		return @completed_paths
	end
	#--------------------------------------------------------------------------
	# > Step in a multiple-path generation
	#   
	# > Identical to single-path stepping except that the dungeon is checked
	#   exhaustively (i.e. no returns) and upon retracting a room, it is marked
	#   as unvisited, as paths may overlap
	#--------------------------------------------------------------------------
	def step_multi_path(room, door = nil)
		return if update_clearlist(room)
		
		@sequence.push(Path_Step.new(room, door, @room_ls_hash[room.id]))
		
		# Check if at destination and if so,
		# transform this into a path and continue searching
		if room.id == @end_id
			@completed_paths.push(Path.new(@sequence))
		end
		
		# Recursively and continuously check next rooms
		room.doors.each { |next_door|
			success = step_single_path(next_door.dest_room, next_door)
		}
		
		# Dead end
		@sequence.pop
		@clearlist[room.id] = false
	end
	
	#--------------------------------------------------------------------------
	# > Short-name references to the static objects of the Dungeon Crawler
	#--------------------------------------------------------------------------
	def dungeon;  Dungeon_Crawler.dungeon;  end
end

#------------------------------------------------------------------------------
# TRAVERSAL GENERATOR
#==============================================================================
# Object maintained by a crawler used to generate traversals
# 
# Supplied with a path in the context of a dungeon and a traversal type, this
# class proceeds to create a "human" traversal of the path by inserting
# diverging sub-paths when confronted with locked doors
# These sub-paths serve to set the states of certain events and unlock doors
# 
# Traversal is broken down into two states: progression, which is stepping
# through doors and assigning sub-paths, and redirection, which is completing
# a sub-path or full traversal and describing the next mode of action
# Sub-paths are assigned types of "departing" and "returning" to describe such
# an action during redirection
# 
# Different traversal generators make use of differening algorithms
# Some characteristics of these algorithms are listed below
# - Sourced  -> Follows a source path beforehand or generates a path in
#               parallel?
# - Stubborn -> Attempts to reuse/return to previous paths or generate new
#               ones?
# - Pathing  -> Looks for only a single path or considers multiple options?
#------------------------------------------------------------------------------
class Traversal_Generator
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	MAX_DEPTH = 30
	MAX_LENGTH = 200
	
	#--------------------------------------------------------------------------
	# > Class variables
	#--------------------------------------------------------------------------
	@@depth = 0  # Records stack depth for error checking
	
	#--------------------------------------------------------------------------
	# > Initialization with the source path and traversal type specified
	#--------------------------------------------------------------------------
	def initialize(path, type)
		@path = path
		@type = type
		
		require "#{Dir.pwd}/DE_Crawler_Objects.rb"
	end
	#--------------------------------------------------------------------------
	# > Base call from the crawler to generate a new traversal of the entire
	#   dungeon
	#   
	# > Returns a completed traversal object
	#--------------------------------------------------------------------------
	def make_traversal
		Traversal.new(make_sub_traversal)
	end
	#--------------------------------------------------------------------------
	# > Defined in sub-classes
	#--------------------------------------------------------------------------
	def make_sub_traversal
		
	end
end

#------------------------------------------------------------------------------
# "THREE-S" SINGLE PATH TRAVERSAL GENERATOR
#==============================================================================
# The algorithm used by this class is a semi-stubborn, sourced, single-pathed
# traversal algorithm
# Stubbornness => Will always attempt to return to previous paths, but will
#                 generate new paths to do so
# Sourcedness  => Generates a source path before a traversal and steps along
#                 this path
# Pathing      => Generates single paths in a "first-come-first-serve" style;
#                 truly single path in that it does not consider multiple paths
#------------------------------------------------------------------------------
class ThreeS_SP_Trvsl_Gen < Traversal_Generator
	
	#--------------------------------------------------------------------------
	# > Class Variables
	#--------------------------------------------------------------------------
	@@path_requests
	
	#--------------------------------------------------------------------------
	# > Continuously steps the traversal, checking for divergences, and
	#   generating sub-paths in response
	#   
	# > Returns a completed path object upon completion
	#--------------------------------------------------------------------------
	def make_sub_traversal
		@single = true
		
		@index = 0
		
		@@depth += 1
		raise "ERROR: stack too deep!!" if @@depth > MAX_DEPTH
		
		@success = false
		
		step_traversal until @success
		@@depth -= 1
		
		@path
	end
	#--------------------------------------------------------------------------
	# > In a single step of a traversal, any specified event-states are modi-
	#   fied, and the traversal can either progress, or be redirected,
	#   depending on if the current room matches that of the destination
	#--------------------------------------------------------------------------
	def step_traversal
		raise "ERROR: Traversal too long!!" if @path.length > MAX_LENGTH
		
		@c_room = c_step.room
		
		# Sets events to specified states
		apply_ls
		
		# Processing for progression and redirection
		if at_dest?
			on_redirection
		else on_progression
		end
	end
	#--------------------------------------------------------------------------
	# > Applies an LS to the current room, switching event states if needed
	#--------------------------------------------------------------------------
	def apply_ls
		c_ls = c_step.ls
		
		dungeon.apply_ls(c_ls) if c_ls && !c_ls.clear?
	end
	
	#--------------------------------------------------------------------------
	# TRAVERSAL PROGRESSION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > The main state of a traversal process, consisting of stepping through
	#   doors into other rooms
	#   
	# > In the case of a locked door, the door's LS is hashed to the rooms its
	#   events are located in, and a new traversal is generated in the context
	#   of this hash
	# > This new traversal is called a "departing" traversal and serves to
	#   diverge from the main path to set the states of various events
	#--------------------------------------------------------------------------
	def on_progression
		ls = n_step.door.ls
		
		if !ls.aligned?
			ls_hash = generate_ls_hash(ls)
			append_new_traversal(@c_room.id, ls_hash.keys[0], :departing,
				ls_hash)
		else @index += 1
		end
	end
	#--------------------------------------------------------------------------
	# > Generates the "LS hash" from a given LS, which is an object that splits
	#   the specified LS into smaller LSs that are hashed to the room IDs their
	#   events are found in
	# > For a single path traversal, there can only be one LS per door, so the
	#   hash is always of size 1
	#--------------------------------------------------------------------------
	def generate_ls_hash(ls)
		{dungeon.get_room(:ev_id, ls.event_id(0)).id => Crawl_LS.new(ls)}
	end
	
	#--------------------------------------------------------------------------
	# TRAVERSAL REDIRECTION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > The secondary state of a traversal, consisting of rerouting the current
	#   traversal after having reached its destination
	#   
	# > In the case of a source traversal, the dungeon has been successfully
	#   traversed and processing is naturally returned to the crawler
	# > In the case of a departing traversal, a returning traversal is assigned
	#   to bring focus back to the source traversal
	# > In the case of a returning traversal, processing is naturally returned
	#   to the previous traversal
	#--------------------------------------------------------------------------
	def on_redirection
		if departing?
			append_new_traversal(@c_room.id, start_room.id, :returning)
		end
		
		@success = true
	end
	
	#--------------------------------------------------------------------------
	# GENERAL METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Creates a new traversal from the specified parameters, appending the
	#   generated path to the current one and advancing the index appropriately
	#--------------------------------------------------------------------------
	def append_new_traversal(start_id, end_id, type, ls_hash = {})
		path_gen.assign_start_end(start_id, end_id)
		
		path = path_gen.make_single_path(ls_hash)
		
		# Update path requests and check for event trapping
		update_path_requests(path)
		
		# Recursively traverse the path and append result to this traversal
		new_trvsl = ThreeS_SP_Trvsl_Gen.new(path, type).make_sub_traversal
		@path.insert(@index, new_trvsl)
		
		@index += new_trvsl.length
	end
	#--------------------------------------------------------------------------
	# > Updates the path requests array and checks for event trapping, halting
	#   progress of this traversal if found
	#--------------------------------------------------------------------------
	def update_path_requests(path)
		raise Crawler_Error(1, *path.start_end_ids) if event_trap?(path)
		
		@@path_requests.push(path)
	end
	#--------------------------------------------------------------------------
	# > Checks for event trapping by checking this path for equivalence to
	#   previously requested paths
	# > If a duplicate is found, this traversal is guaranteed to be endlessly
	#   looping due to event trapping and an error is raised
	#--------------------------------------------------------------------------
	def event_trap?
		@@path_requests.any? { |prev_path| path == prev_path }
	end
	
	#--------------------------------------------------------------------------
	# > Current and next path step
	#--------------------------------------------------------------------------
	def c_step; @path[@index];     end
	def n_step; @path[@index + 1]; end
	#--------------------------------------------------------------------------
	# > Starting room of this traversal
	#--------------------------------------------------------------------------
	def start_room
		@path.start.room
	end
	#--------------------------------------------------------------------------
	# > Destination room of this traversal
	#--------------------------------------------------------------------------
	def dest_room
		@path.end.room
	end
	#--------------------------------------------------------------------------
	# > Type checks
	#--------------------------------------------------------------------------
	def source?;    @type == :source;    end
	def departing?; @type == :departing; end
	#--------------------------------------------------------------------------
	# > Checks if at the destination room
	#--------------------------------------------------------------------------
	def at_dest?
		@c_room.id == dest_room.id
	end
	#--------------------------------------------------------------------------
	# > Short-name references to the static objects of the Dungeon Crawler
	#--------------------------------------------------------------------------
	def path_gen; Dungeon_Crawler.path_gen; end
	def dungeon;  Dungeon_Crawler.dungeon;  end
end

#------------------------------------------------------------------------------
# VSS SINGLE PATH TRAVERSAL GENERATOR
#==============================================================================
# The algorithm used by this class is a very-stubborn, sourced, single-pathed
# traversal algorithm
# Stubbornness => Will always attempt to return to previous paths, using
#                 previously generated paths
# Sourcedness  => Generates a source path before a traversal and steps along
#                 this path
# Pathing      => Generates single paths in a "first-come-first-serve" style;
#                 truly single path in that it does not consider multiple paths
#------------------------------------------------------------------------------
class VSS_SP_Trvsl_Gen < Traversal_Generator
	
end

#------------------------------------------------------------------------------
# PS SINGLE PATH TRAVERSAL GENERATOR
#==============================================================================
# The algorithm used by this class is a pliant, sourced, single-pathed
# traversal algorithm
# Stubbornness => Will always generate new paths (i.e. has no "returning" sub-
#                 paths)
# Sourcedness  => Generates a source path before a traversal and steps along
#                 this path
# Pathing      => Generates single paths in a "first-come-first-serve" style;
#                 truly single path in that it does not consider multiple paths
#------------------------------------------------------------------------------
class PS_SP_Trvsl_Gen < Traversal_Generator
	
end