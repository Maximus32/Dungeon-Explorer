
#------------------------------------------------------------------------------
# DUNGEON CRAWLER
#==============================================================================
#------------------------------------------------------------------------------
class Dungeon_Crawler
	
	#--------------------------------------------------------------------------
	# > Requires files
	#--------------------------------------------------------------------------
	def initialize
		require "#{Dir.pwd}/DE_Crawler_Objects.rb"
		require "#{Dir.pwd}/DE_Crawler_Generators.rb"
	end
	#--------------------------------------------------------------------------
	# > ???
	#--------------------------------------------------------------------------
	def start(dungeon)
		@@dungeon = Crawl_Dungeon.new(dungeon)
		@@dungeon.finalize
		
		@@path_generator = Path_Generator.new(*@@dungeon.get_metadata[0..1])
		
		setup_managers
		
		puts traverse.to_s
	end
	#--------------------------------------------------------------------------
	# > Initializes Manager classes
	#--------------------------------------------------------------------------
	def setup_managers
		@crawler_op = Crawler_Operator.new(self)
	end
	
	def traverse
		src_path = @@path_generator.make_single_path
		
		trvsl_gen = ThreeS_SP_Trvsl_Gen.new(src_path, :source)
		traversal = trvsl_gen.make_traversal
		
		return traversal
	end
	
	def find_solution
	end
	
	def self.dungeon
		@@dungeon
	end
	
	def self.path_gen
		@@path_generator
	end
end

#------------------------------------------------------------------------------
# CRAWLER OPERATOR
#==============================================================================
#------------------------------------------------------------------------------
class Crawler_Operator < Word_Operator
	
	#--------------------------------------------------------------------------
	# > Initialization with a reference to the assembler and its assembly
	#   
	# > Also creates an "Interaction" object used to moniter keystrokes for
	#   more dynamic input
	#--------------------------------------------------------------------------
	def initialize(crawler)
		@crawler = crawler
		
		super(Crawler_Handler.new, nil, :crawler, false) # TODO: STATIC MENUS??
	end
end

#------------------------------------------------------------------------------
# CRAWLER ERROR
#==============================================================================
# Exception thrown in the context of a crawling process like traversal or path
# fabrication
#------------------------------------------------------------------------------
class Crawler_Error < Generic_Error
	
	#--------------------------------------------------------------------------
	# > List of messages
	#--------------------------------------------------------------------------
	def messages
		[
			"Path Fabrication: Could not fabricate a path between rooms %d and %d"
		]
	end
end

#------------------------------------------------------------------------------
# CRAWLER HANDLER
#==============================================================================
# Exception handler for crawler errors
#------------------------------------------------------------------------------
class Crawler_Handler < Handler
	
	#--------------------------------------------------------------------------
	# > List of handled error types
	#--------------------------------------------------------------------------
	def handled_types
		super << Crawler_Error
	end
end