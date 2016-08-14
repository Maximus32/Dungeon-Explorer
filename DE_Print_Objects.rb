#------------------------------------------------------------------------------
# PRINT BLOCK
#==============================================================================
# The basic unit of printing, representing a series of strings all of the same
# length to be displayed in a stack (see the example below)
# 
# Printing to a block uses another, smaller block which is overlain across the
# original
# 
# A block can be sliced into multiple sub-blocks
# 
# Blocks are arranged in pages which are stored in documents
#------------------------------------------------------------------------------
class Print_Block
	
	# Mixins
	include Enumerable
	
	#--------------------------------------------------------------------------
	# > Block Initalization
	#--------------------------------------------------------------------------
	# > Accepts 2-element arrays in the format '[str, i]' which represents
	#   the string 'str' repeated 'i' times
	#   Also accepts strings as themselves printed once
	#   
	# > For example: (["AAA", 2], ["BBB", 1], "CCC")
	#   
	# > Appears as:
	# 	  AAA
	# 	  AAA
	# 	  BBB
	# 	  CCC
	#   
	# > The last parameter may specify a formatting symbol which is used to
	#   allocate whitespace to make each string the same length
	#--------------------------------------------------------------------------
	def initialize(*params)
		@data = []
		
		# Specification of block formatting
		fomatter = :left_just
		fomatter = params.pop if params[-1].is_a?(Symbol)
		
		params.each { |datum|
			if datum.is_a?(Array)
				datum[1].times { @data.push(datum[0].dup) }
			else @data.push(datum)
			end
		}
		
		format_data(fomatter)
	end
	#--------------------------------------------------------------------------
	# > Inserts whitespace to make all strings the same length
	#--------------------------------------------------------------------------
	def format_data(formatting)
		req_length = (@data.max { |a, b| a.length <=> b.length }).length
		
		for i in (0...@data.length)
			length_diff = req_length - @data[i].length
			
			next if length_diff == 0
			
			case formatting
			when :left_just  then @data[i] << " " * length_diff
			when :right_just then @data[i][0, 0] = " " * length_diff
			when :center
				@data[i][0, 0] = " " * (length_diff / 2 + (length_diff % 2))
				@data[i] << " " * (length_diff / 2)
			end
		end
	end
	
	#--------------------------------------------------------------------------
	# BASIC PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Data reference
	#--------------------------------------------------------------------------
	def [](index)
		@data[index]
	end
	#--------------------------------------------------------------------------
	# > Data assignment
	#--------------------------------------------------------------------------
	def []=(index, str)
		@data[index] = str
	end
	#--------------------------------------------------------------------------
	# > Append a string
	#--------------------------------------------------------------------------
	def append(str)
		@data.push(str)
	end
	#--------------------------------------------------------------------------
	# > Insert a string within this block
	#--------------------------------------------------------------------------
	def insert(str, index)
		@data[index, 0] = str
	end
	#--------------------------------------------------------------------------
	# > Iteration through this block's strings
	#--------------------------------------------------------------------------
	def each
		@data.each { |str| yield str }
	end
	#--------------------------------------------------------------------------
	# > Length of one of the strings
	#--------------------------------------------------------------------------
	def width
		@data[0].length
	end
	#--------------------------------------------------------------------------
	# > Length of the @data array
	#--------------------------------------------------------------------------
	def length
		@data.length
	end
	
	#--------------------------------------------------------------------------
	# BLOCK PRINTING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Overlays a smaller block onto this one, replacing characters starting
	#   from the upper left point specified by 'coord'
	#   
	# > The specified block and coordinates must fit within this block
	#--------------------------------------------------------------------------
	def print(block, coord = [0, 0])
		w_start = coord[1]
		w_end   = coord[1] + block.width
		l_start = coord[0]
		l_end   = coord[0] + block.length
		
		# Raise error on out-of-bounds
		raise Printing_Error.new(0, "width", self.width, w_start, w_end, block) if w_end > self.width
		raise Printing_Error.new(0, "length", self.length, l_start, l_end, block) if l_end > self.length
		
		# Transfer substrings from each row of the smaller block to this one
		for row in (l_start...l_end)
			@data[row][w_start...w_end] = block[row - l_start][0...(w_end - w_start)]
		end
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Produces a block of the specified dimensions from the contents of this
	#   block starting at 'coord'
	#   
	#   'coord' and the dimensions must fit within the block
	#--------------------------------------------------------------------------
	def sub_block(coord, b_length, b_width)
		sub_blk	= Print_Block.nil_block(b_width, b_length)
		
		w_start = coord[1]
		w_end   = w_start + b_width
		l_start = coord[0]
		l_end   = l_start + b_length
		
		# Raise error on out-of-bounds
		raise Printing_Error.new(1, "width", self.width, w_start, w_end)  if w_end > self.width
		raise Printing_Error.new(1, "length", self.length, l_start, l_end) if l_end > self.length
		
		# Assign strings from rows of this block to the sub-block
		for row in (l_start...l_end)
			sub_blk[row - l_start] = @data[row][w_start...w_end]
		end
		
		sub_blk
	end
	#--------------------------------------------------------------------------
	# > String representation
	#--------------------------------------------------------------------------
	def to_s
		@data.join("\n")
	end
	#--------------------------------------------------------------------------
	# > Creates a new block of this block's strings duplicated
	#--------------------------------------------------------------------------
	def dup
		Print_Block.new(*@data.collect { |str| str.dup })
	end
	
	#--------------------------------------------------------------------------
	# SPECIAL BLOCK CONSTRUCTION METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# Creates a block of the specified dimensions filled with 'nil'
	#--------------------------------------------------------------------------
	def self.nil_block(b_width, b_length)
		nils = []
		b_width.times { nils.push(nil) }
		
		Print_Block.new([nils, b_length])
	end
	#--------------------------------------------------------------------------
	# Creates a block of the specified dimensions filled with space characters
	#--------------------------------------------------------------------------
	def self.blank_block(b_width, b_length)
		Print_Block.new([" " * b_width, b_length])
	end
end

#------------------------------------------------------------------------------
# BLOCK TEMPLATES
#==============================================================================
# Module containing methods used in the construction and implementation of
# blocks for dungeons
#------------------------------------------------------------------------------
module Block_Templates
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	WKSPC_BLK_WIDTH = 20
	WKSPC_BLK_LENGTH = 6
	
	#--------------------------------------------------------------------------
	# > Requires and assigns necessary classes and variables
	#--------------------------------------------------------------------------
	def self.init(block_length, block_width)
		require "#{Dir.pwd}/DE_Assembly_Objects.rb"
		
		@block_length = block_length
		@block_width = block_width
	end
	
	#--------------------------------------------------------------------------
	# HELPER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Converts a 2-element array of ratios to actual block-in-page
	#   coordinates
	#--------------------------------------------------------------------------
	def self.ratio_to_bip_coord(ratio_coord)
		bip_coord = ratio_coord.dup
		
		bip_coord[0] = (bip_coord[0] * (@block_length - 1)).ceil
		bip_coord[1] = (bip_coord[1] * (@block_width - 1)).ceil
		
		bip_coord
	end
	
	#--------------------------------------------------------------------------
	# BLOCKS FOR ROOMS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Block for a room
	#   
	# > Includes optional room number in the bottom right and any special
	#   1-character symbols in the bottom left
	#--------------------------------------------------------------------------
	def self.room_block(room_num, special = "_")
		room_num = (room_num ? room_num.to_s : "")
		room_num[0, 0] = ("_" * (4 - room_num.length))
		
		Print_Block.new(" _______________  ",
					   ["|               | ", Dungeon_Printer::BLOCK_LENGTH - 3],
					    "|#{special}__________#{room_num}| ",
						"                  ")
	end
	
	#--------------------------------------------------------------------------
	# BLOCKS FOR EVENTS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Block for an array of events
	#--------------------------------------------------------------------------
	def self.events_block(events)
		event_strs = events.collect { |event| event.sformat }
		Print_Block.new(*event_strs)
	end
	
	#--------------------------------------------------------------------------
	# BLOCKS FOR DOORS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Block for a door
	#   
	# > Calls on a specific sub-method according to the presence of an LS and
	#   the recipricosity of the door
	#--------------------------------------------------------------------------
	def self.door_block(ls, rcpr, c_diff)
		puts "LS: #{ls.sformat}"
		puts "LS CLEAR? #{ls.clear?}"
		
		return lockable_biway_door_blk(ls, c_diff)  if !ls.clear? &&  rcpr
		return lockable_oneway_door_blk(ls, c_diff) if !ls.clear? && !rcpr
		return clear_biway_door_blk(c_diff)         if  ls.clear? &&  rcpr
		return clear_oneway_door_blk(c_diff)        if  ls.clear? && !rcpr
	end
	#--------------------------------------------------------------------------
	# > Block for a locakble, bidirectional door
	#--------------------------------------------------------------------------
	def self.lockable_biway_door_blk(ls, c_diff)
		if c_diff[0] < 0
			Print_Block.new("(#{ls.sformat})", "*", "v", :center)
		elsif c_diff[0] > 0
			Print_Block.new("^", "*", "(#{ls.sformat})", :center)
		elsif c_diff[1] != 0
			ls_strs = ls.sformat(2)
			Print_Block.new("(#{ls_strs[0]})", "|", "(#{ls_strs[1]})", :center)
		elsif c_diff[2] != 0
			Print_Block.new("(#{ls.sformat})")
		end
	end
	#--------------------------------------------------------------------------
	# > Block for a lockable, one-directional door
	#--------------------------------------------------------------------------
	def self.lockable_oneway_door_blk(ls, c_diff)
		if c_diff[0] > 0
			Print_Block.new("^", "*", "(#{ls.sformat})", :center)
		elsif c_diff[0] < 0
			Print_Block.new("(#{ls.sformat})", "*", "v", :center)
		elsif c_diff[1] != 0
			ls_strs = ls.sformat(2)
			dir_str = (c_diff[1] > 0 ? "v" : "^")
			Print_Block.new("(#{ls_strs[0]})", dir_str,
				"(#{ls_strs[1]})", :center)
		elsif c_diff[2] > 0
			Print_Block.new("(#{ls.sformat})->")
		elsif c_diff[2] < 0
			Print_Block.new("<-(#{ls.sformat})")
		end
	end
	#--------------------------------------------------------------------------
	# > Block for a clear, bidirectional door
	#--------------------------------------------------------------------------
	def self.clear_biway_door_blk(c_diff)
		if    c_diff[0] < 0  then Print_Block.new("*", "v")
		elsif c_diff[0] > 0  then Print_Block.new("^", "*")
		elsif c_diff[1] != 0 then Print_Block.new(["   ", 3])
		elsif c_diff[2] != 0 then Print_Block.new("   ")
		end
	end
	#--------------------------------------------------------------------------
	# > Block for a clear, one-directional door
	#--------------------------------------------------------------------------
	def self.clear_oneway_door_blk(c_diff)
		if    c_diff[0] < 0 then Print_Block.new("*", "v")
		elsif c_diff[0] > 0 then Print_Block.new("^", "*")
		elsif c_diff[1] < 0 then Print_Block.new("   ", " ^ ", " | ")
		elsif c_diff[1] > 0 then Print_Block.new("   ", " | ", " v ")
		elsif c_diff[2] < 0 then Print_Block.new("<- ")
		elsif c_diff[2] > 0 then Print_Block.new(" ->")
		end
	end
	#--------------------------------------------------------------------------
	# > Coordinate within a room block for a door, returned as ratios that are
	#   multiplied by the width and length of the room block
	#   
	# > Calls on a specific sub-method according to the recipricosity of the
	#   door
	#--------------------------------------------------------------------------
	def self.door_block_coord(rcpr, c_diff)
		ratio_to_bip_coord(
			if rcpr
				biway_door_coord(c_diff)
			else oneway_door_coord(c_diff)
			end
		)
	end
	#--------------------------------------------------------------------------
	# > Coordinate for a bidirectional door
	#--------------------------------------------------------------------------
	def self.biway_door_coord(c_diff)
		if    c_diff[0] < 0 then [0.3, 0.5]
		elsif c_diff[0] > 0 then [0.7, 0.5]
		elsif c_diff[1] < 0 then [0, 0.5]
		elsif c_diff[1] > 0 then [1, 0.5]
		elsif c_diff[2] < 0 then [0.5, 0]
		elsif c_diff[2] > 0 then [0.5, 1]
		end
	end
	#--------------------------------------------------------------------------
	# > Coordinate for a one-directional door
	#--------------------------------------------------------------------------
	def self.oneway_door_coord(c_diff)
		if    c_diff[0] < 0 then [0.25, 0.5]
		elsif c_diff[0] > 0 then [0.75, 0.5]
		elsif c_diff[1] < 0 then [0, 0.25]
		elsif c_diff[1] > 0 then [1, 0.75]
		elsif c_diff[2] < 0 then [0.25, 0]
		elsif c_diff[2] > 0 then [0.75, 1]
		end
	end
	
	#--------------------------------------------------------------------------
	# BLOCKS FOR ASSEMBLY DOORS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Block for an assmebly door
	#   
	# > Supplied with the LS, sub-coordinate, and 'dir' parameter of the door,
	#   converts these into appropriate objects that are passed to the standard
	#   door block generator method
	#--------------------------------------------------------------------------
	def self.asm_door_block(ls, sub_coord, dir)
		door_block(ls, dir == 2, Assembly.convert_sub_coord(sub_coord))
	end
	#--------------------------------------------------------------------------
	# > Coordinate within a room block for an assembly door, identical to the
	#   coordinate positioning of a cursor
	#--------------------------------------------------------------------------
	def self.asm_door_block_coord(sub_coord)
		cursor_block_coord(sub_coord)
	end
	
	#--------------------------------------------------------------------------
	# BLOCKS FOR ASSEMBLY CURSORS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Block for an assemblage cursor
	#--------------------------------------------------------------------------
	def self.cursor_block
	end
	#--------------------------------------------------------------------------
	# > Coordinate for an assemblage cursor
	#--------------------------------------------------------------------------
	def self.cursor_block_coord(sub_cursor)
		ratio_to_bip_coord(
			case sub_cursor
			when -1 then [0.5, 0.5]
			when  0 then [0, 0.5]
			when  1 then [0.5, 1]
			when  2 then [0.5, 0]
			when  3 then [1, 0.5]
			end
		)
	end
	
	#--------------------------------------------------------------------------
	# BLOCKS FOR OTHER THINGS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns a block for a workspace slot containing the specified item
	#--------------------------------------------------------------------------
	def self.workspace_block(obj, index)
		wkspc_blk = Print_Block.new(" x----------------x ",
			[" |                | ", 5], " |              ##{index}| ",
			 " x================x ")
		
		# Print parameters of the object to a separate block that is then
		# printed onto the workspace block
		if obj
			params =
			if obj.is_a?(Dungeon)
				str_type = Dungeon::D_TYPE_MAP.invert[obj.class]
				["~Dungeon~", "NAME: #{obj.name}", "TYPE: #{str_type}",
					*obj.size_sformat]
			elsif obj.is_a?(Assembly)
				["~Assembly~", *obj.size_sformat]
			end
			
			wkspc_blk.print(Print_Block.new(*params), [1, 3])
		end
		
		wkspc_blk
	end
end

module Page_Templates
	
	#--------------------------------------------------------------------------
	# > Constants
	#--------------------------------------------------------------------------
	WKSPC_PG_WIDTH = 4
	
	#--------------------------------------------------------------------------
	# > Returns the page associated with a workspace of the specified capacity
	#--------------------------------------------------------------------------
	def self.workspace_page(capacity)
		blocks = []
		capacity.times { |index|
			blocks.push(Block_Templates.workspace_block(nil, index))
		}
		
		Page.new(blocks, WKSPC_PG_WIDTH, capacity / WKSPC_PG_WIDTH)
	end
end

#------------------------------------------------------------------------------
# PAGE
#==============================================================================
# A Page is a collection of Print Blocks all of the same size arranged in a 2-D
# array
# 
# When printing to a page, a block is sliced into sub-blocks which are printed
# to individual "blocks-in-page"
# 
# Pages can also be reverted to paragraphs of strings using 'to_s'
#------------------------------------------------------------------------------
class Page
	
	#--------------------------------------------------------------------------
	# > Accepts a 1-D array of print blocks and a length and width to group
	#   them by
	#--------------------------------------------------------------------------
	def initialize(blocks, width, length)
		@data = []
		
		# Converts the 1-D 'blocks' array into a 2-D array
		for row in (0...length)
			@data.push([])
			for col in (0...width)
				@data[row].push(blocks[row * width + col])
			end
		end
	end
	
	#--------------------------------------------------------------------------
	# DATA MANIPULATION & PAGE PROPERTIES
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns the block at the specified coordinates
	#--------------------------------------------------------------------------
	def block_at(row, col)
		@data[row][col]
	end
	#--------------------------------------------------------------------------
	# > Sets the specified block to the coordinates
	#--------------------------------------------------------------------------
	def assign_block(block, row, col)
		raise Printing_Error.new(4, "width", page_width, col) if col >= page_width
		raise Printing_Error.new(4, "length", page_length, row) if row >= page_length
		
		@data[row][col] = block.dup
	end
	#--------------------------------------------------------------------------
	# > Width of the page, in blocks
	#--------------------------------------------------------------------------
	def page_width
		@data[0].length
	end
	#--------------------------------------------------------------------------
	# > Length of the page, in blocks
	#--------------------------------------------------------------------------
	def page_length
		@data.length
	end
	#--------------------------------------------------------------------------
	# > Width of a block in this page
	#--------------------------------------------------------------------------
	def block_width
		@data[0][0].width
	end
	#--------------------------------------------------------------------------
	# > Length of a block in this page
	#--------------------------------------------------------------------------
	def block_length
		@data[0][0].length
	end
	#--------------------------------------------------------------------------
	# > Returns the dimension specified by 'i'
	#--------------------------------------------------------------------------
	def block_dim(i)
		(i == 0 ? block_length : block_width)
	end
	
	#--------------------------------------------------------------------------
	# BLOCK PRINTING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Overlays a single block onto this page, handling overlap between blocks
	#   by splitting the specified one into smaller blocks and printing these 
	#  
	# > The 'page_coord' specifies the block in this page to print on and the
	#   'blk_coord' specifies where on that block should printing begin
	#   
	# > Bounds must lie within those of the page
	#   
	# > May provide an alignment that specifies where the 'blk_coord' should be
	#   properly located
	#--------------------------------------------------------------------------
	def print(spec_blk, page_coord = [0, 0], blk_coord = [0, 0], align = :left)
		
		raise Printing_Error.new(3, "page coordinates", page_coord.length) if page_coord.length != 2
		raise Printing_Error.new(3, "block coordinates", blk_coord.length) if blk_coord.length != 2
		
		# Align 'blk_coord'
		alignment_adjust(spec_blk, blk_coord, page_coord, align)
		
		# Assign bounds
		w_blk_start = page_coord[1]
		w_blk_end   = w_blk_start +
			(blk_coord[1] + spec_blk.width - 1) / self.block_width
			
		l_blk_start = page_coord[0]
		l_blk_end   = l_blk_start +
			(blk_coord[0] + spec_blk.length - 1) / self.block_length
		
		# Raise error on out-of-bounds
		raise Printing_Error.new(2, "width", page_width, w_blk_start, w_blk_end, spec_blk) if w_blk_end > page_width
		raise Printing_Error.new(2, "length", page_length, l_blk_start, l_blk_end, spec_blk) if l_blk_end > page_length
		
		# Iterate over blocks within this page, creating necessary sub-blocks
		# and printing them onto those of this page
		for row in (l_blk_start..l_blk_end)
			for col in (w_blk_start..w_blk_end)
				
				# Determine the location in the spec_blk (i.e. left edge, right
				# edge, top, bottom, middle, etc.)
				w_res = range_compare(col, w_blk_start, w_blk_end)
				l_res = range_compare(row, l_blk_start, l_blk_end)
				
				# Get sub-block and coordinates to print it to in this block
				sub_blk, bip_coord = printing_sub_block(spec_blk, l_blk_start,
					w_blk_start, blk_coord, row, col, w_res, l_res)
				
				# Print the sub-block to this block
				block_at(row, col).print(sub_blk, bip_coord)
			end
		end
	end
	#--------------------------------------------------------------------------
	# > Adjusts the 'blk_coord' of a printing process according to the
	#   specified alignment
	#   
	# > Because aligning a block can sometimes push it out of its current
	#   block in the page, the page coordinate may be modified as well
	#--------------------------------------------------------------------------
	def alignment_adjust(spec_blk, blk_coord, pg_coord, align)
		case align
		when :center
			blk_coord[0] -= spec_blk.length / 2
			blk_coord[1] -= spec_blk.width / 2
		when :right
			blk_coord[1] -= spec_blk.width
		when :left  # Default
		end
		
		# Modifies the block and page coordinates for negative values
		for i in (0..1)
			next unless blk_coord[i] < 0
			
			blk_coord[i] = self.block_dim(i) + blk_coord[i] - 1
			pg_coord[i] -= 1
		end
	end
	#--------------------------------------------------------------------------
	# > Creates a sub-block from the specified block to be used for printing
	# 
	# > Determines the starting point for slicing the 'spec_blk' and for
	#   placing the sub-block into the "block-in-page", lastly calculating the
	#   dimensions of the sub-block
	# 
	# > Returns the newly created sub-block as well as the assigned "block-in-
	#   page" coordinates
	#--------------------------------------------------------------------------
	def printing_sub_block(spec_blk, l_blk_start, w_blk_start, blk_coord,
			row, col, w_res, l_res)
		
		# Row and column page coordinates relative to the starting block
		rel_col = col - w_blk_start
		rel_row = row - l_blk_start
		
		# Get starting point in the 'spec_block' to slice
		slc_coord = get_spec_block_slice_coordinates(rel_row, rel_col,
			blk_coord, w_res, l_res)
		
		# Get starting point in the "block-in-page" to assign the sub-block
		bip_coord = get_block_in_page_sub_coordinates(blk_coord, w_res, l_res)
		
		# Get width and length of the required sub-block
		sub_blk_dim = get_sub_block_dimensions(spec_blk, blk_coord, bip_coord,
			rel_row, rel_col, w_res, l_res)
		
		# Create and return the sub-block sliced from the 'spec_block' as well
		# as the "block-in-page" coordinates
		[spec_blk.sub_block(slc_coord, *sub_blk_dim), bip_coord]
	end
	#--------------------------------------------------------------------------
	# > Determines the coordinates within the 'spec_blk' to decide where to
	#   slice it to create the sub-block
	#--------------------------------------------------------------------------
	def get_spec_block_slice_coordinates(rel_row, rel_col, blk_coord,
			w_res, l_res)
		slc_coord = [0, 0]
		
		slc_coord[1] = self.block_width  * rel_col - blk_coord[1] if w_res > -1
		slc_coord[0] = self.block_length * rel_row - blk_coord[0] if l_res > -1
		
		slc_coord
	end
	#--------------------------------------------------------------------------
	# > Determinets sub-coordinates within the "current" block to decide where
	#   to place the sub-block
	#--------------------------------------------------------------------------
	def get_block_in_page_sub_coordinates(blk_coord, w_res, l_res)
		bip_coord = [0, 0]
		
		bip_coord[1] = blk_coord[1] if w_res < 0
		bip_coord[0] = blk_coord[0] if l_res < 0
		
		bip_coord
	end
	#--------------------------------------------------------------------------
	# >  Determines the width and length of the required sub-block
	#--------------------------------------------------------------------------
	def get_sub_block_dimensions(spec_blk, blk_coord, bip_coord, rel_row,
			rel_col, w_res, l_res)
		dim = []
		
		dim[1] =
		if    w_res == -3  then spec_blk.width
		elsif w_res < 1    then self.block_width - bip_coord[1]
		else spec_blk.width - rel_col * self.block_width + blk_coord[1]
		end
		
		dim[0] =
		if    l_res == -3  then spec_blk.length
		elsif l_res < 1    then self.block_length - bip_coord[0]
		else spec_blk.length - rel_row * self.block_length + blk_coord[0]
		end
		
		dim
	end
	#--------------------------------------------------------------------------
	# > Compares a point against a discrete range of integers by checking if it
	#   is below, inside, or above the range, and/or at one of its endpoints
	#   
	#   Can specify a range or start and end points
	#--------------------------------------------------------------------------
	def range_compare(point, *params)
		if params.length == 1
			first = params[0].begin
			last = params[0].end
		else first, last = params
		end
		
		# Degenerate case
		return -3 if first == last
		
		# Match point against the range's endpoints
		if    point <  first then -2
		elsif point == first then -1
		elsif point <  last  then  0
		elsif point == last  then  1
		else                       2
		end
	end
	
	#--------------------------------------------------------------------------
	# SPECIALIZED BLOCK PRINTING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Door Printing
	#--------------------------------------------------------------------------
	# > Prints a door to the specified page
	#   
	# > Uses the LS, coordinate difference, and reciprocality of the door to
	#   determine the exact block and its "block-in-page" coordinate
	#--------------------------------------------------------------------------
	def print_door(page_coord, ls, c_diff, rcpr)
		blk = Block_Templates.door_block(ls, rcpr, c_diff)
		
		# Obtain "block-in-page" coordinates from ratios
		bip_coord = Block_Templates.door_block_coord(rcpr, c_diff)
		
		print(blk, page_coord, bip_coord, :center)
	end
	#--------------------------------------------------------------------------
	# > Assembly Door Printing
	#--------------------------------------------------------------------------
	# > Prints an assembly door to the specified page
	#   
	# > The direction and bip coordinate are obtained by the directional sub-
	#   coordinate and the 'dir' parameter
	#--------------------------------------------------------------------------
	def print_asm_door(page_coord, ls, sub_coord, dir)
		blk = Block_Templates.asm_door_block(ls, sub_coord, dir)
		bip_coord = Block_Templates.asm_door_block_coord(sub_coord)
		
		print(blk, page_coord, bip_coord, :center)
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Converts the entire page of blocks into a string
	#   Reads across rows of blocks, connecting a single row of a row of blocks
	#   as a string on a line
	#--------------------------------------------------------------------------
	def to_s
		str = ""
		
		for row in (0...page_length)
			for sub_row in (0...block_length)
				for col in (0...page_width)
					str += @data[row][col][sub_row]
				end
				
				str += "\n"
			end
		end
		
		str
	end
	#--------------------------------------------------------------------------
	# > Creates a new page containing duplicate blocks to this one
	#--------------------------------------------------------------------------
	def dup
		page = blank_page
		
		for row in (0...page.page_length)
			for col in (0...page.page_width)
				page.assign_block(self.block_at(row, col), row, col)
			end
		end
		
		page
	end
	#--------------------------------------------------------------------------
	# > Resizes the page, adding rows or columns of blank blocks in the
	#   specified directions
	#--------------------------------------------------------------------------
	def resize(up, right, left, down)
		
		# Length-wise asjustment
		up.times   { @data[0, 0] = [blank_row] }
		down.times { @data.push(blank_row) }
		
		# Width-wise adjustment
		@data.each { |blk_row|
			left.times  { blk_row[0, 0] = [blank_block] }
			right.times { blk_row.push(blank_block) }
		}
	end
	
	#--------------------------------------------------------------------------
	# PAGE & BLOCK CONSTRUCTION
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns a blank block with dimensions from this page
	#--------------------------------------------------------------------------
	def blank_block
		Print_Block.blank_block(block_width, block_length)
	end
	#--------------------------------------------------------------------------
	# > Creates an array of blank blocks for a new row of an arbitrary page
	#--------------------------------------------------------------------------
	def Page.blank_row(length, b_width, b_length)
		blocks = []
		
		length.times {
			blocks.push(Print_Block.blank_block(b_width, b_length))
		}
		
		blocks
	end
	#--------------------------------------------------------------------------
	# > Creates an array of blank blocks for a new row in this page
	#--------------------------------------------------------------------------
	def blank_row
		Page.blank_row(page_width, block_width, block_length)
	end
	#--------------------------------------------------------------------------
	# > Creates a page of blank blocks from the specified dimensions
	#--------------------------------------------------------------------------
	def self.blank_page(p_width, p_length, b_width, b_length)
		blocks = Page.blank_row(p_width * p_length, b_width, b_length)
		
		Page.new(blocks, p_width, p_length)
	end
	#--------------------------------------------------------------------------
	# > Creates a page of blank blocks from this page's dimensions
	#--------------------------------------------------------------------------
	def blank_page
		Page.blank_page(page_width, page_length, block_width, block_length)
	end
end

#------------------------------------------------------------------------------
# DOCUMENT
#==============================================================================
# A Document is a collection of Pages
# 
# Used to order pages of dungeon rooms by floor nummber during printing
#------------------------------------------------------------------------------
class Document
	
	# Mixins
	include Enumerable
	
	#--------------------------------------------------------------------------
	# > Initialization with pages specified
	#--------------------------------------------------------------------------
	def initialize(pages = [])
		@pages = pages
	end
	#--------------------------------------------------------------------------
	# > References the page at the specified index
	#--------------------------------------------------------------------------
	def page(index)
		@pages[index]
	end
	#--------------------------------------------------------------------------
	# > Iteration through this document's pages
	#--------------------------------------------------------------------------
	def each
		@pages.each { |page| yield page }
	end
	#--------------------------------------------------------------------------
	# > Appends a page to this document
	#--------------------------------------------------------------------------
	def append(page)
		@pages.push(page)
	end
	
	#--------------------------------------------------------------------------
	# PRINTING
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Print by Block Replacement
	#--------------------------------------------------------------------------
	# > Prints the specified block to this document at the page and block
	#   specified by 'coord'
	#   
	# > Replaces the block within the page entirely, making it ideal for
	#   printing room outlines
	#--------------------------------------------------------------------------
	def print_block_replace(block, coord)
		page(coord[0]).assign_block(block, *coord[1..2])
	end
	#--------------------------------------------------------------------------
	# > Print by Block Editing
	#--------------------------------------------------------------------------
	# > Prints the specified Print Block to this document at the page and block
	#   specified by 'p_coord' and the internal block coordinates by 'coord'
	#   
	# > The Page handles the printing itself, overlaying the block across as
	#   many blocks as needed and editing its contents by printing sub-blocks
	#   to each affected block
	#--------------------------------------------------------------------------
	def print_block_edit(block, p_coord, coord)
		page(p_coord[0]).print(block, p_coord[1..2], coord)
	end
	
	#--------------------------------------------------------------------------
	# OTHER METHODS
	#--------------------------------------------------------------------------
	#--------------------------------------------------------------------------
	# > Returns a new document of the same pages duplicated
	#--------------------------------------------------------------------------
	def dup
		Document.new(@pages.collect { |page| page.dup})
	end
end
