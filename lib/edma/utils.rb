module Edma
	class Utils
		attr_accessor :email_clients, :compiled_markup

		def initialize
			@email_clients = [ "hotmail", 
				"gmail", 
				"notes8", 
				"ol2010", 
				"ol2007", 
				"gmailnew", 
				"ffhotmail", 
				"ipad3", 
				"iphone3", 
				"ol2003", 
				"ol2000", 
				"ol2002", 
				"yahooo" ]
		end

		def id
			File.basename(Dir.getwd)
		end
		
	end
end