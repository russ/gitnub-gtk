#!/usr/bin/env ruby

require 'pathname'
require 'md5'
require 'open-uri'
require 'cgi'
require 'libglade2'
require 'gtkmozembed'

require 'grit/lib/grit'

require 'branches'

module GitNub
	class ApplicationController
	
		include GetText
	
	  attr :glade
	  attr :offset
	  attr :branch
	  attr :active_commit
	
	  Gtk::MozEmbed.set_profile_path(ENV["HOME"] + ".mozilla", "RubyZilla")
	
	  def initialize(path_or_data, root = nil, domain = nil, localedir = nil, flag = GladeXML::FILE)
	    bindtextdomain(domain, localedir, nil, "UTF-8")
	    @glade = GladeXML.new(path_or_data, root, domain, localedir, flag) { |handler| method(handler) }
	
			@branches = @glade['branches']
	
			@offset = 50
			@current_commit_offset = 0
	
			@commit_tree = @glade['commit_tree']
			@commit_tree.set_rules_hint(true)
			@commit_tree.append_column(Gtk::TreeViewColumn.new('Author', Gtk::CellRendererPixbuf.new, { :pixbuf => 1 }))
			@commit_tree.append_column(Gtk::TreeViewColumn.new('Title', Gtk::CellRendererText.new, { :markup => 2 }))
	
			@store = Gtk::TreeStore.new(String, Gdk::Pixbuf, String)
			@commit_tree.model = @store
	
			@glade['latest_button'].clicked
	  end

		def update
			# Updating Everything...
		end









	
		def active_commit
			@commits[@commit_tree.selection.selected.to_s.to_i]
		end
	
		def on_commit_tree_row_activated
			refresh_commit_view
		end
	
		def page_commits(widget)
			case widget.name
				when 'previous_button' then @current_commit_offset -= @offset
				when 'latest_button' then @current_commit_offset = 0
				when 'next_button' then @current_commit_offset += @offset
			end
	
			@current_commit_offset = 0 if @current_commit_offset == -(@offset)
			@commits = fetch_commits_for(@branches.active_branch, @offset, @current_commit_offset)
	
			@glade['previous_button'].sensitive = false
			@glade['next_button'].sensitive = false
	
			if @commits.size == 0 || @current_commit_offset == 0
				@glade['previous_button'].sensitive = false
				@glade['next_button'].sensitive = true unless @commits.size == 0 || @commits.size % @offset != 0
	    elsif ((@current_commit_offset >= @offset) && (@commits.size % @offset == 0))
				@glade['previous_button'].sensitive = true
				@glade['next_button'].sensitive = true 
	    elsif @commits.size % @offset != 0
				@glade['previous_button'].sensitive = true
				@glade['next_button'].sensitive = false 
	    end
	
			refresh_commit_tree
			refresh_commit_view
	
			@commit_tree.set_cursor(Gtk::TreePath.new(0), nil, false)
		end
	
		def on_about_activate(widget)
			Gnome::About.new("GitNub-GTK", "0.01", "Copyright (C) 2008 Russ Smith", "A Port of GitNub for OS X", ["Russ Smith"], ["Russ Smith"], nil).show
		end
	
		def fetch_commits_for(branch, quantity, offset = 0)
			@commits = $repo.commits(branch, quantity, offset)
		end
	
		def refresh_commit_tree
			@store.clear
			avatars = {}
			@commits.each do |commit|
				unless avatars.include?(commit.author.email)
					loader = Gdk::PixbufLoader.new
					open(gravatar_url(commit.author.email)) { |f| loader.last_write(f.read) }
					avatars[commit.author.email] = loader.pixbuf
				end
				gravatar = avatars[commit.author.email]
	
				title, message = commit.message.split("\n", 2)
				summary = %Q[
	<b>#{title}</b>
	by #{commit.author.name} on #{commit.committed_date.strftime('%A, %b, %I:%M %p')}
				]
	
				itr = @store.append(nil)
				@store.set_value(itr, 1, gravatar)
				@store.set_value(itr, 2, summary)
			end
		end
	
		def refresh_commit_view
			@commit_id_label = @glade['commit_id_label']
			@commit_id_label.text = active_commit.id
	    @gecko = @glade["gecko"]
			title, message = active_commit.message.split("\n", 2)
	    @gecko.open_stream('file://' + Pathname.new(File.dirname(__FILE__)).realpath + '/', 'text/html')
			@gecko.append_data(
	%Q[	
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
	
	<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
	  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
	  <title>Commit</title>
	  <link rel="stylesheet" href="style.css" type="text/css" charset="utf-8" />
	</head>
	 
	<body>
	  <div id="content">
	  <div id="metadata">
	    <h1 id="title">#{title}</h1>
	    <p id="hash">#{active_commit.id}</p>
	    <div id="message">#{message.strip.gsub(/\n/, '<br />') if message}</div>
	    <h2 id="date">#{active_commit.authored_date.strftime('%A, %B %d %I:%M %p')} by #{active_commit.author.name}</h2>
	    </div>
	    
	    <div id="main">
	      <ul id="files">
					#{file_list}
	      </ul>
	      
	      <div id="diffs">
	        #{diff_list}
	      </div>
	    </div>
	  </div>
	 
	</body>
	</html>
	]
			)
	    @gecko.close_stream
		end
	
		def file_list
			out = []
			active_commit.diffs.each_with_index do |diff, i|
				out << %(<li id="item-#{i}")
				out << %(class="add") if diff.new_file
				out << %(class="delete") if diff.deleted_file
				out << %(><a href="#diff-#{i}" class="">#{diff.b_path}</a></li>)
			end
			out.join
		end
	
		def diff_list
			out = []
			active_commit.diffs.each_with_index do |diff, i|
				unless diff.deleted_file || diff.diff.nil?
					out << %(<div class="diff" id="diff-#{i}">)
					out << %(<h3>#{File.basename(diff.b_path)}</h3>)
					out << %(<pre><code class="diffcode">)
					html = CGI.escapeHTML(diff.diff)
					html.each_line do |line|
						if line =~ /^\+/
							out << %(<div class="addline">#{line}</div>)
						elsif line =~ /^\-/
							out << %(<div class="removeline">#{line}</div>)
						elsif line =~ /^@/
							out << %(<div class="meta">#{line}</div>)
						else
							out << line
						end
					end
					out << %(</code></pre></div>)
				end
			end
			out.join
		end
	
		def gravatar_url(email, size = 36)
			"http://www.gravatar.com/avatar.php?gravatar_id=#{MD5.hexdigest(email.downcase)}&size=#{size}"
		end
	
		def on_window_delete_event(widget, arg0 = nil)
			Gtk.main_quit
			exit!
		end
	end
end
	
# Load up the repository
pwd = Pathname.new(ENV['PWD'].nil? ? Dir.getwd : ENV['PWD'])
REPOSITORY_LOCATION = pwd + `cd #{pwd} && git rev-parse --git-dir 2>/dev/null`.chomp

begin
	$repo = Grit::Repo.new(REPOSITORY_LOCATION)
rescue Grit::InvalidGitRepositoryError
	puts "Not a vaid git repo."
	exit
end
	
# Main program
# if __FILE__ == $0
  PROG_PATH = File.join(Pathname.new(File.dirname(__FILE__)).realpath, "interface.glade")
  PROG_NAME = "GitNub"
	Gtk.init
  GitNub::ApplicationController.new(PROG_PATH, nil, PROG_NAME)
  Gtk.main
# end
