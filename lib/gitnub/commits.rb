module GitNub
  class Commits < Gtk::ScrolledWindow
    attr_accessor :commits
    attr_accessor :offset
    attr_accessor :current_commit_offset
    attr_accessor :tree_view

    def initialize
      super

      @offset, @current_commit_offset = 50, 0

      self.width_request = 300
      self.hscrollbar_policy = Gtk::POLICY_NEVER

      # Set up the treeview
      @model = Gtk::TreeStore.new(String, Gdk::Pixbuf, String)
      @tree_view = Gtk::TreeView.new(@model)

      # Settings
      @tree_view.set_rules_hint(true)
      @tree_view.show_expanders = false
      @tree_view.headers_visible = false

      # Columns
      @tree_view.append_column(Gtk::TreeViewColumn.new('Author', Gtk::CellRendererPixbuf.new, { :pixbuf => 1 }))
      @tree_view.append_column(Gtk::TreeViewColumn.new('Title', Gtk::CellRendererText.new, { :markup => 2 }))

      self.add(@tree_view)
    end

    def active_commit
      @commits[@tree_view.selection.selected.to_s.to_i]
    end

    def update(controller)
      @commits = fetch_commits_for(controller, controller.branches.active_branch, @offset, @current_commit_offset)

      @model.clear
      avatars = {}
      @commits.each do |commit|
        unless avatars.include?(commit.author.email)
          loader = Gdk::PixbufLoader.new
          open(gravatar_url(commit.author.email)) { |f| loader.last_write(f.read) }
          avatars[commit.author.email] = loader.pixbuf
        end
        gravatar = avatars[commit.author.email]

        title, message = commit.message.split("\n", 2)
        summary = %(<b>#{title}</b>\nby #{commit.author.name} on #{commit.committed_date.strftime('%A, %b %d, %I:%M %p')})

        itr = @model.append(nil)
        @model.set_value(itr, 1, gravatar)
        @model.set_value(itr, 2, summary)
      end

      controller.commit_view.update(controller)
    end

    def page_commits(action, controller)
      case action
        when 'previous' then @current_commit_offset -= @offset
        when 'latest' then @current_commit_offset = 0
        when 'next' then @current_commit_offset += @offset
      end

      @current_commit_offset = 0 if @current_commit_offset == -(@offset)
      @commits = fetch_commits_for(controller, controller.branches.active_branch, @offset, @current_commit_offset)

      controller.previous_button.sensitive = false
      controller.next_button.sensitive = false

      if @commits.size == 0 || @current_commit_offset == 0
        controller.previous_button.sensitive = false
        controller.next_button.sensitive = true unless @commits.size == 0 || @commits.size % @offset != 0
      elsif ((@current_commit_offset >= @offset) && (@commits.size % @offset == 0))
        controller.previous_button.sensitive = true
        controller.next_button.sensitive = true 
      elsif @commits.size % @offset != 0
        controller.previous_button.sensitive = true
        controller.next_button.sensitive = false 
      end

      self.update(controller)
      @tree_view.set_cursor(Gtk::TreePath.new(0), nil, false)
    end

    private

    def fetch_commits_for(controller, branch, quantity, offset = 0)
      @commits = controller.repository.commits(branch, quantity, offset)
    end

    def gravatar_url(email, size = 36)
      "http://www.gravatar.com/avatar.php?gravatar_id=#{MD5.hexdigest(email.downcase)}&size=#{size}"
    end
  end
end
