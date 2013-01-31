module Pakyow
  # A singleton that manages route sets.
  #
  class Router
    def initialize
      self.reset
    end

    def reset
      @sets = {}
      self
    end

    @@instance = self.new
    def self.instance
      @@instance
    end

    # Creates a new set (or appends to a set if it exists).
    #
    def set(name, &block)
      @sets[name] ||= RouteSet.new
      @sets[name].instance_exec(&block)
    end

    # Iterates through route sets and returns the first matching route.
    #
    def route(name, group = nil)
      @sets.each { |set|
        if r = set[1].route(name, group)
          return r
        end
      }

      nil
    end

    # Performs the initial routing for a request.
    #
    def route!(request)
      self.trampoline(self.match(request))
    end

    # Reroutes a request.
    #
    def reroute!(request)
      throw :fns, self.match(request)
    end

    # Finds and invokes a handler by name or by status code.
    #
    def handle!(name_or_code, from_logic = false)
      @sets.each { |set|
        if h = set[1].handle(name_or_code)
          Pakyow.app.response.status = h[0]
          from_logic ? throw(:fns, h[2]) : self.trampoline(h[2])
          break
        end
      }
    end

    def routed?
      @routed
    end

    protected

    # Calls a list of route functions in order (each in a separate context).
    #
    def call_fns(fns)
      fns.each {|fn| self.context.instance_exec(&fn)}
    end

    # Creates a context in which to evaluate a route function.
    #
    def context
      FnContext.new
    end

    # Finds the first matching route for the request path/method and
    # returns the list of route functions for that route.
    #
    def match(request)
      path   = StringUtils.normalize_path(request.working_path)
      method = request.working_method

      @routed = false

      match, data = nil
      @sets.each { |set|
        match, data = set[1].match(path, method)
        break if match
      }

      fns = []
      if match
        fns = match[3]

        # handle route params
        #TODO where to do this?
        request.params.merge!(HashUtils.strhash(self.data_from_path(path, data, match[1])))

        #TODO where to do this?
        request.route_path = match[4]
      end

      fns
    end

    # Calls route functions and catches new functions as
    # they're thrown (e.g. by reroute).
    #
    def trampoline(fns)
      until fns.empty?
        fns = catch(:fns) {
          self.call_fns(fns)

          # Getting here means that call() returned normally (not via a throw)
          :fall_through
        } # end :fns catch block

        # If reroute! or invoke_handler! was called in the block, block will have a new value (nil or block).
        # If neither was called, block will be :fall_through

        @routed = case fns
          when []             then false
          when :fall_through  then fns = [] and true
        end
      end
    end

    # Extracts the data from a path.
    #
    def data_from_path(path, matches, vars)
      data = {}
      return data unless matches

      vars.each {|v|
        data[v[:var]] = matches[v[:position]]
      }

      data
    end
  end
end
