module GitNub
	# Subclass of the ComboBox model
	# Keeps things nice and clean
	class Branches < Gtk::ComboBox

		alias :active_branch :active_text

		def initialize
			super
			model = Gtk::ListStore.new(String)
			populate
			set_active(0)

			# Connect the change signal to update 
			# the application view
			signal_connect("changed") { p "update..." }
		end

		private

		# Populates the Combobox with the 
		# repos branches	
		def populate
			$repo.branches.each do |branch|
				append_text(branch.name)
			end
		end
	end
end
