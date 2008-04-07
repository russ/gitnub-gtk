module GitNub
	class CommitView < Gtk::MozEmbed
		def initialize
			super
		end
		
		def update(controller)
			# controller.commit_id_label.text = controller.commits.active_commit.id
			title, message = controller.commits.active_commit.message.split("\n", 2)
	    open_stream('file://' + Pathname.new(File.dirname(__FILE__)).realpath + '/', 'text/html')
			append_data(
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
	    <p id="hash">#{controller.commits.active_commit.id}</p>
	    <div id="message">#{message.strip.gsub(/\n/, '<br />') if message}</div>
	    <h2 id="date">#{controller.commits.active_commit.authored_date.strftime('%A, %B %d %I:%M %p')} by #{controller.commits.active_commit.author.name}</h2>
	    </div>
	    
	    <div id="main">
	      <ul id="files">
					#{file_list(controller)}
	      </ul>
	      
	      <div id="diffs">
	        #{diff_list(controller)}
	      </div>
	    </div>
	  </div>
	 
	</body>
	</html>
	]
			)
	    close_stream
		end

		private

		def file_list(controller)
			out = []
			controller.commits.active_commit.diffs.each_with_index do |diff, i|
				out << %(<li id="item-#{i}")
				out << %(class="add") if diff.new_file
				out << %(class="delete") if diff.deleted_file
				out << %(><a href="#diff-#{i}" class="">#{diff.b_path}</a></li>)
			end
			out.join
		end
	
		def diff_list(controller)
			out = []
			controller.commits.active_commit.diffs.each_with_index do |diff, i|
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

	end
end
