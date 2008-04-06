module GitNub
	class Branches < Gtk::ComboBox
		def initialize
			super
			model = Gtk::ListStore.new(String)
			populate
			set_active(0)
		end
	
		def active_branch
			active_text
		end
	
		private
	
		def populate
			[ 'master' ].each do |branch|
				append_text(branch)
			end
		end
	end
end
