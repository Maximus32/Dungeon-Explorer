require "C:/Users/Max/Max's Junk/Storage/Static Storage/Programming/Other/Generic_Classes.rb"

#------------------------------------------------------------------------------
# DUNGEON ADMINISTRATOR
#==============================================================================
# Administrative class called by the Runner to begin the program
# 
# Directs high-level managers such as the Crawler and Assembler and
# communicates with the Central Operator which recieves input for high-level
# user commands (i.e. program exit, file system reading/writing)
# 
# Also maintains the Workspace for storing temporary data while the program is
# running
#------------------------------------------------------------------------------
class Dungeon_Admin < Administrator
	
	# Required files
	require "#{Dir.pwd}/DE_IO.rb"
	require "#{Dir.pwd}/DE_Objects.rb"
	require "#{Dir.pwd}/DE_Crawler.rb"
	require "#{Dir.pwd}/DE_Assembler.rb"
	require "#{Dir.pwd}/DE_Printer.rb"
	
	# Constants
	
	# Class Variables
	@@admin = nil
	
	# Public variables
	attr_reader :workspace
	attr_reader :crawler
	attr_reader :assembler
	
	#--------------------------------------------------------------------------
	# > Object initialization
	#--------------------------------------------------------------------------
	def initialize
		@@admin = self
		
		setup_managers
		
		@workspace = Dungeon_Workspace.new(8)
	end
	#--------------------------------------------------------------------------
	# > Initializes manager classes
	#--------------------------------------------------------------------------
	def setup_managers
		@op = Central_Operator.new
		
		@crawler = Dungeon_Crawler.new
		@assembler = Dungeon_ManualAssembler.new
		
		Dungeon_IO.init
	end
	#--------------------------------------------------------------------------
	# > Opens the operator and begins User input
	#--------------------------------------------------------------------------
	def start
		puts "%==========================%\n" +
		     "% ~ DUNGEON EXPLORER 1.0 ~ %\n" +
			 "%==========================%\n\n"
		
		run_test_code
		
		@op.open
		@op.run until @op.closed?
		
		puts "END OF PROGRAM"
	end
	#--------------------------------------------------------------------------
	# > Run testing code
	#--------------------------------------------------------------------------
	def run_test_code
		#@workspace.insert_next(Dungeon_IO.read_dungeon("test"))
		#@op.on_print(0)
		#@crawler.start(@workspace.item(0, true))
		
		@op.open
		@op.on_assemble
	end
	#--------------------------------------------------------------------------
	# > Closes the operator, terminating the program
	#--------------------------------------------------------------------------
	def close
		@op.close
	end
	#--------------------------------------------------------------------------
	# > Reference to the 'admin' instance of this class
	#--------------------------------------------------------------------------
	def self.admin
		@@admin
	end
end

#------------------------------------------------------------------------------
# DUNGEON WORKSPACE
#==============================================================================
# Abstraction of a list of Dungeon-like objects
# 
# Maintained by the Administrator, in which it holds temporary dungeon data
# that can be manipulated, saved, and deleted
#------------------------------------------------------------------------------
class Dungeon_Workspace
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	PAGE_WIDTH = 4
	
	#--------------------------------------------------------------------------
	# > Initialization with a capacity specified
	#--------------------------------------------------------------------------
	def initialize(capacity)
		require "#{Dir.pwd}/DE_Print_Objects.rb"
		
		@slots = Array.new(capacity)
		@document = Document.new([Page_Templates.workspace_page(capacity)])
	end
	
	#--------------------------------------------------------------------------
	# CONTENTS ACCESS & MODIFICATION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Retrieves the item at the specified index
	#--------------------------------------------------------------------------
	def item(index, expecting = false, class_type = nil)
		valid_index?(index, expecting, class_type)
		
		@slots[index]
	end
	#--------------------------------------------------------------------------
	# > Inserts the specified object at the specified index, if possible
	#--------------------------------------------------------------------------
	def insert(object, index)
		valid_object?(object)
		valid_index?(index)
		
		@slots[index] = object
	end
	#--------------------------------------------------------------------------
	# > Inserts the specified object at the next available index
	#--------------------------------------------------------------------------
	def insert_next(object)
		for i in (0..@slots.length)
			next if @slots[i]
			
			@slots[i] = object
			return
		end
		
		raise Central_Error.new(2)
	end
	#--------------------------------------------------------------------------
	# > Deletes the object at the specified index
	#--------------------------------------------------------------------------
	def delete_at(index)
		valid_index?(index)
		
		@slots[index] = nil
	end
	#--------------------------------------------------------------------------
	# > Copies the object at 'from_index' into the slot at 'to_index'
	#--------------------------------------------------------------------------
	def copy(from_index, to_index)
		valid_index?(from_index, true)
		valid_index?(to_index)
		
		@slots[to_index] = @slots[from_index].dup
	end
	
	#--------------------------------------------------------------------------
	# PRINTING AND UPDATES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Displays the workspace to the console by use of a page with blocks
	#   allocated for each item
	#--------------------------------------------------------------------------
	def display
		update_page
		
		puts @document.page(0).to_s
	end
	#--------------------------------------------------------------------------
	# > Updates the visualization of the workspace by printing objects within
	#   slots to its page
	#--------------------------------------------------------------------------
	def update_page
		@slots.each_with_index { |object, i|
			block = Block_Templates.workspace_block(object, i)
			coord = [0, i / PAGE_WIDTH, i % PAGE_WIDTH]
			
			# Print-block replace the new blocks, overwriting the old ones
			@document.print_block_replace(block, coord)
		}
	end
	
	#--------------------------------------------------------------------------
	# WORKSPACE PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Number of slots
	#--------------------------------------------------------------------------
	def capacity
		@slots.length
	end
	#--------------------------------------------------------------------------
	# > Checks if the specified object is "dungeon-like"
	#--------------------------------------------------------------------------
	def valid_object?(object)
		raise Central_Error(0, object.class) unless valid_types.include?(object.class)
	end
	#--------------------------------------------------------------------------
	# > Valid "dungeon-like" objects
	#--------------------------------------------------------------------------
	def valid_types
		[Dungeon, Assembly]
	end
	#--------------------------------------------------------------------------
	# > Checks if the specified index is within bounds
	#   
	# > Also, if the 'expecting' flag is true, an error will be raised if no
	#   object of the specified type is found at the index
	#--------------------------------------------------------------------------
	def valid_index?(index, expecting = false, class_type = nil)
		raise Central_Error.new(1, index, @capacity) unless index >= 0 && index < @slots.length
		
		return unless expecting
		raise Central_Error.new(3, index) unless @slots[index]
		
		return unless class_type
		raise Central_Error.new(4, class_type, @slots[index].class) unless @slots[index].is_a?(class_type)
	end
end

#------------------------------------------------------------------------------
# CENTRAL MENU REPOSITORY
#==============================================================================
# Module that stores static menu data used to create menus when called on by
# the Operator
#------------------------------------------------------------------------------
module Central_Menu_Repository
	
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
	#--------------------------------------------------------------------------
	def command_list
		case @name
		when :main_menu then [
				Command.new(:load,     method(:on_load),     [String]),
				Command.new(:save,     method(:on_save),     [Integer]),
				Command.new(:crawl,    method(:on_crawl),    [Integer]),
				Command.new(:assemble, method(:on_assemble), [Integer], [], false, true),
				
				Command.new(:delete,   method(:on_delete),   [Integer]),
				Command.new(:copy,     method(:on_copy),     [Integer, Integer]),
				Command.new(:print,    method(:on_print),    [Integer]),
				
				Command.new(:exit,     method(:on_exit),     [])
			]
		else []
		end
	end
	
	#--------------------------------------------------------------------------
	# > Returns the opening message for the current menu
	#--------------------------------------------------------------------------
	def message
		case @name
		when :main_menu
			"MAIN MENU -\n" +
			"Type and enter 'LOAD filename' to load a dungeon of the specified filename from the system\n" +
			"Type and enter 'SAVE #' to save the #th object from the Workspace to a file on the system\n" +
			"Type and enter 'CRAWL #' to examine the #th object in the Workspace in the Crawler\n" +
			"Type and enter 'ASSEMBLE #' to load the #th object into the Assembler\n" +
				"\tCan also not specify # to create a new Assembly\n\n" +
			
			"Type and enter 'PRINT #' to print the #th object from the Workspace to a file\n" +
			"Type and enter 'DELETE #' to delete the #th object from the Workspace\n" +
			"Type and enter 'COPY #1,#2' to copy the #1th object in the Workspace to position #2\n" +
			"Type and enter 'PRINT #' to print the #th object in the Workspace to a file\n\n" +
			
			"Type and enter 'EXIT' to terminate the program\n\n"
		else ""
		end
	end
	#--------------------------------------------------------------------------
	# > Returns the opening and closing methods for the current menu
	#--------------------------------------------------------------------------
	def open_close_methods
		case @name
		when :main_menu then [method(:on_main_menu), nil]
		end
	end
	#--------------------------------------------------------------------------
	# > Returns the specified Y/N menu
	#--------------------------------------------------------------------------
	def yn_menu
		
	end
end

#------------------------------------------------------------------------------
# CENTRAL OPERATOR
#==============================================================================
# Operator that runs high-level commands that link to managers of the Admini-
# strator (i.e. assemblers, crawlers) and the Workspace
# 
# All sub-processes are run from here and return here when finished
#------------------------------------------------------------------------------
class Central_Operator < Word_Operator
	
	#--------------------------------------------------------------------------
	# > Initialization with a refernce to the assembler and its assembly
	#--------------------------------------------------------------------------
	def initialize
		
		# Mixins
		self.class.include Central_Menu_Repository
		
		super(Central_Handler.new(self), nil, :main_menu, false)
	end
	#--------------------------------------------------------------------------
	# > Announcements hash
	#--------------------------------------------------------------------------
	def announcements
		{
			:save_dungeon     => Announcement.new("Saving Dungeon to the Workspace...", 2),
			:save_assembly    => Announcement.new("Saving Assembly to the Workspace...", 1),
			:open_printer     => Announcement.new("Opening Dungeon printer...", 1),
			:display_printout => Announcement.new("Displaying Dungeon print-out...", 1)
		}
	end
	#--------------------------------------------------------------------------
	# > Shortcut reference to the Dungeon Administrator
	#--------------------------------------------------------------------------
	def admin
		Dungeon_Admin.admin
	end
	
	#--------------------------------------------------------------------------
	# MAIN MENU COMMANDS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns processing to this Operator (after being used by other classes)
	#--------------------------------------------------------------------------
	def return_processing
		sleep 2
		puts "\n\n----------------\n\n"
		
		reset_menu
	end
	#--------------------------------------------------------------------------
	# > Main menu opens
	#--------------------------------------------------------------------------
	def on_main_menu
		admin.workspace.display
	end
	#--------------------------------------------------------------------------
	# > Calls on the Dungeon IO module to load the dungeon with the specified
	#   filename
	#   
	# > The loaded dungeon is saved to the workspace
	#--------------------------------------------------------------------------
	def on_load(name)
		dungeon = Dungeon_IO.read_dungeon(name)
		
		if dungeon
			announce(:save_dungeon)
			admin.workspace.insert_next(dungeon)
		end
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > Calls on IO to write the specified workspace item to a file
	#--------------------------------------------------------------------------
	def on_save(index)
		Dungeon_IO.write_dungeon(admin.workspace.item(index, true, Dungeon))
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > Opens the crawler to analyze the specified dungeon
	#   
	# > Upon closing, ???
	#--------------------------------------------------------------------------
	def on_crawl(index)
		admin.crawler.start(admin.workspace.item(index, true, Dungeon))
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > Opens the assembler to build dungeons from user input
	#   
	# > Upon closing, the assembly is saved to the workspace
	#--------------------------------------------------------------------------
	def on_assemble(index = -1)
		assembly = nil
		assembly = admin.workspace.item(index, true, Assembly) if index >= 0
		
		assembly = admin.assembler.start(assembly)
		
		announce(:save_assembly)
		admin.workspace.insert_next(assembly)
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > Workspace deletion
	#--------------------------------------------------------------------------
	def on_delete(index)
		admin.workspace.delete_at(index)
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > Workspace copy
	#--------------------------------------------------------------------------
	def on_copy(from_index, to_index)
		admin.workspace.copy(from_index, to_index)
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > Creates a print file of the specified item in the Workspace and
	#   displays the print-out to the console
	#--------------------------------------------------------------------------
	def on_print(index)
		object = admin.workspace.item(index, true)
		
		filename = "Printout_#{object.name}"
		if object.is_a?(Dungeon)
			announce(:open_printer)
			Simple_Printer.new.print_dungeon(object, filename)
			
			announce(:display_printout)
			
			sleep 1
			Dungeon_IO.display_dungeon_printout(filename)
		end
		
		return_processing
	end
	#--------------------------------------------------------------------------
	# > On Operator exit
	#--------------------------------------------------------------------------
	def on_exit
		admin.close
	end
end

#------------------------------------------------------------------------------
# CENTRAL ERROR
#==============================================================================
# Exception thrown in the context of the workspace or the main menu
#------------------------------------------------------------------------------
class Central_Error < Generic_Error
	
	#--------------------------------------------------------------------------
	# > List of messages
	#--------------------------------------------------------------------------
	def messages
		[
			"Workspace: Specified object of type '%s' is not of an allowable type",
			"Workspace: Specified index of %d is out of bounds (workspace capacity is %d)",
			"Workspace: No available open slots to insert object",
			"Workspace: No object located at specified index %d",
			"Workspace: The command requires an object of type %s when one of type %s was specified"
		]
	end
end

#------------------------------------------------------------------------------
# CENTRAL HANDLER
#==============================================================================
# Exception handler for central errors
#------------------------------------------------------------------------------
class Central_Handler < Handler
	
	def initialize(operator)
		@operator = operator
	end
	
	def handled_types
		super << Central_Error
	end
end