module Pakyow
  module Presenter
    class ViewComposer
      class << self
        def from_path(store, path, opts = {}, &block)
          ViewComposer.new(store, path, opts, &block)
        end
      end

      attr_accessor :context
      attr_reader :store, :path, :page, :partials

      def initialize(store, path = nil, opts = {}, &block)
        @store = store
        @path = path

        self.page = opts.fetch(:page) {
          path
        }

        self.template = opts.fetch(:template) {
          (@page.is_a?(Page) && @page.info(:template)) || path
        }

        @partials = {}

        begin
          @partials = includes(opts.fetch(:includes))
        rescue
          @partials = store.partials(path) unless path.nil?
        end

        @partials.each do |name, partial|
          partial.composer = self
        end

        instance_exec(&block) if block_given?
      end

      def initialize_copy(original)
        super

        %w[store path page template partials view].each do |ivar|
          value = original.instance_variable_get("@#{ivar}").dup
          self.instance_variable_set("@#{ivar}", value)
        end

        # update composer reference for partials
        @partials.each do |name, partial|
          partial.composer = self
        end

        # update composer reference for page
        @page.composer = self
      end

      def precompose!
        @view = build_view
        clean!
      end

      def view
        if dirty?
          @view = build_view
          clean!
        end

        return @view
      end

      def template(template = nil)
        return @template if template.nil?

        self.template = template
        return self
      end

      def template=(template)
        unless template.is_a?(Template)
          # get template by name
          template = @store.template(template)
        end

        @template = template
        dirty!

        return self
      end

      def page=(page)
        unless page.is_a?(Page)
          # get page by name
          page = @store.page(page)
        end

        page.composer = self
        @page = page
        dirty!

        return self
      end

      def includes(partial_map)
        dirty!

        @partials.merge!(remap_partials(partial_map))
      end

      def partials=(partial_map)
        dirty!
        @partials.merge!(remap_partials(partial_map))
      end

      def partial(name)
        @partials[name]
      end

      def container(name)
        @page.container(name)
      end

      def dirty?
        @dirty
      end

      def dirty!
        @dirty = true
      end

      private

      def clean!
        @dirty = false
      end

      def build_view
        raise MissingTemplate, "No template provided to view composer" if @template.nil?
        raise MissingPage, "No page provided to view composer" if @page.nil?

        view = @template.dup.build(@page).includes(@partials)

        # set title
        title = @page.info(:title)
        view.title = title unless title.nil?

        return view
      end

      def remap_partials(partials)
        Hash[partials.map { |name, partial_or_path|
          if partial_or_path.is_a?(Partial)
            partial = partial_or_path
          else
            partial = Partial.load(@store.expand_partial_path(path))
          end

          [name, partial]
        }]
      end

    end
  end
end
