module Cinch
  module Plugin
    include Helpers

    # @note All writeonly attributes can actually be read, but those
    #   methods are provided by {ClassMethods}
    # @since 1.2.0
    module ClassAttributes
      # Note: The reason we are using a ClassAttributes module,
      # instead of simply defining the attributs in ClassMethods, is
      # that it improves the documentation generated by YARD. As soon
      # as we remove the deprecated parts of methods like help,
      # react_on etc, we will move the attributes to ClassMethods.

      # @return [Hash<Symbol<:pre, :post> => Array<Hook>>] All hooks
      attr_accessor :hooks

      # @return [Array<Symbol<:message, :channel, :private>>] The list of events to react on
      attr_writer   :react_on

      # @return [String, nil] The name of the plugin
      attr_writer   :plugin_name

      # @return [Array<Match>] All matchers
      attr_reader   :matchers

      # @return [Array<Listener>] All listeners
      attr_reader   :listeners

      # @return [Array<Timer>] All timers
      attr_reader   :timers

      # @return [Array<String>] All CTCPs
      attr_reader   :ctcps

      # @return [String, nil] The help message
      attr_writer   :help

      # @return [String, Regexp, Proc] The prefix
      attr_writer   :prefix

      # @return [String, Regexp, Proc] The suffix
      attr_writer   :suffix

      # @return [Array<Symbol>] Required plugin options
      attr_writer :required_options
    end

    # @see ClassAttributes ClassAttributes for information on available attributes
    module ClassMethods
      include ClassAttributes

      # @attr [String, Regexp, Proc] pattern
      # @attr [Boolean] use_prefix
      # @attr [Boolean] use_suffix
      # @attr [Symbol] method
      Match = Struct.new(:pattern, :use_prefix, :use_suffix, :method)

      # @attr [Symbol] event
      # @attr [Symbol] method
      Listener = Struct.new(:event, :method)

      # @attr [Number] interval
      # @attr [Symbol] method
      # @attr [Boolean] threaded
      # @attr [Boolean] registered
      Timer = Struct.new(:interval, :method, :threaded, :registered)

      # @attr [Symbol] type
      # @attr [Array<Symbol>] for
      # @attr [Symbol] method
      Hook = Struct.new(:type, :for, :method)

      # @api private
      def self.extended(by)
        by.instance_exec do
          @matchers  = []
          @ctcps     = []
          @listeners = []
          @timers    = []
          @help      = nil
          @hooks     = Hash.new{|h, k| h[k] = []}
          @prefix    = nil
          @suffix    = nil
          @react_on  = :message
          @required_options = []
        end
      end

      # Set options.
      #
      # Available options:
      #
      #   - {ClassAttributes#help= help}
      #   - {ClassAttributes#plugin_name= plugin_name}
      #   - {ClassAttributes#prefix= prefix}
      #   - {ClassAttributes#react_on= react_on}
      #   - {ClassAttributes#suffix= suffx}
      #
      # @overload set(key, value)
      #   @param [Symbol] key The option's name
      #   @param [Object] value
      #   @return [void]
      # @overload set(options)
      #   @param [Hash<Symbol => Object>] options The options, as key => value associations
      #   @return [void]
      #   @example
      #     set(:help   => "the help message",
      #         :prefix => "^")
      # @return [void]
      # @since 1.2.0
      def set(*args)
        case args.size
        when 1
          # {:key => value, ...}
          args.first.each do |key, value|
            self.send("#{key}=", value)
          end
        when 2
          # key, value
          self.send("#{args.first}=", args.last)
        else
          raise ArgumentError # TODO proper error message
        end
      end

      # Set a match pattern.
      #
      # @param [Regexp, String] pattern A pattern
      # @option options [Symbol] :method (:execute) The method to execute
      # @option options [Boolean] :use_prefix (true) If true, the
      #   plugin prefix will automatically be prepended to the
      #   pattern.
      # @option options [Boolean] :use_suffix (true) If true, the
      #   plugin suffix will automatically be appended to the
      #   pattern.
      # @return [void]
      def match(pattern, options = {})
        options = {:use_prefix => true, :use_suffix => true, :method => :execute}.merge(options)
        @matchers << Match.new(pattern, options[:use_prefix], options[:use_suffix], options[:method])
      end

      # Events to listen to.
      # @overload listen_to(*types, options = {})
      #   @param [String, Symbol, Integer] *types Events to listen to. Available
      #     events are all IRC commands in lowercase as symbols, all numeric
      #     replies, and the following:
      #
      #       - :channel (a channel message)
      #       - :private (a private message)
      #       - :message (both channel and private messages)
      #       - :error   (IRC errors)
      #       - :ctcp    (ctcp requests)
      #       - :action  (actions, aka /me)
      #
      #   @param [Hash] options
      #   @option options [Symbol] :method (:listen) The method to
      #     execute
      #   @return [void]
      def listen_to(*types)
        options = {:method => :listen}
        if types.last.is_a?(Hash)
          options.merge!(types.pop)
        end

        types.each do |type|
          @listeners << Listener.new(type, options[:method])
        end
      end

      def ctcp(command)
        @ctcps << command.to_s.upcase
      end

      # Set or query the help message.
      # @overload help()
      #   @return [String, nil] The help message
      #   @since 1.2.0
      #
      # @overload help(message)
      #   Sets the help message
      #
      #   @param [String] message
      #   @return [void]
      #   @deprecated See {#set} or {ClassAttributes#help=} instead
      # @return [String, nil, void]
      def help(*args)
        case args.size
        when 0
          return @help
        when 1
          $stderr.puts "Deprecation warning: Beginning with version 1.2.0, help should not be used to set options anymore."
          self.help = args.first
        else
          raise ArgumentError # TODO proper error message
        end
      end

      # Set or query the plugin prefix.
      # @overload prefix()
      #   @return [String, Regexp, Proc] The plugin prefix
      #   @since 1.2.0
      #
      # @overload prefix(prefix = nil, &block)
      #   Sets the plugin prefix
      #
      #   @param [String, Regexp, Proc] prefix
      #   @return [void]
      #   @deprecated See {#set} or {ClassAttributes#prefix=} instead
      # @return [String, Regexp, Proc, void]
      def prefix(prefix = nil, &block)
        return @prefix if prefix.nil? && block.nil?
        $stderr.puts "Deprecation warning: Beginning with version 1.2.0, prefix should not be used to set options anymore."
        self.prefix = prefix || block
      end

      # Set or query the plugin suffix.
      # @overload suffix()
      #   @return [String, Regexp, Proc] The plugin suffix
      #   @since 1.2.0
      #
      # @overload suffix(suffix = nil, &block)
      #   Sets the plugin suffix
      #
      #   @param [String, Regexp, Proc] suffix
      #   @return [void]
      #   @deprecated See {#set} or {ClassAttributes#suffix=} instead
      # @return [String, Regexp, Proc, void]
      def suffix(suffix = nil, &block)
        return @suffix if suffix.nil? && block.nil?
        $stderr.puts "Deprecation warning: Beginning with version 1.2.0, suffix should not be used to set options anymore."
        self.suffix = suffix || block
      end

      # Set or query which kind of messages to react on (i.e. call {#execute})
      # @overload react_on()
      #   @return [Array<Symbol<:message, :channel, :private>>] What kind of messages to react on
      #   @since 1.2.0
      # @overload react_on(events)
      #   Set which kind of messages to react on
      #   @param [Array<Symbol<:message, :channel, :private>>] events Which events to react on
      #   @return [void]
      #   @deprecated See {#set} or {ClassAttributes#react_on=} instead
      # @return [Array<Symbol>, void]
      def react_on(*args)
        case args.size
        when 0
          return @react_on
        when 1
          $stderr.puts "Deprecation warning: Beginning with version 1.2.0, react_on should not be used to set options anymore."
          self.react_on = args.first
        else
          raise ArgumentError # TODO proper error message
        end
      end

      # Set or query the plugin name.
      # @overload plugin_name()
      #   @return [String] The plugin name
      #   @since 1.2.0
      #
      # @overload plugin_name(name)
      #   Sets the plugin name
      #
      #   @param [String] name
      #   @return [void]
      #   @deprecated See {#set} or {ClassAttributes#plugin_name=} instead
      # @return [String, void]
      def plugin_name(*args)
        case args.size
        when 0
          return @plugin_name || self.name.split("::").last.downcase
        when 1
          $stderr.puts "Deprecation warning: Beginning with version 1.2.0, plugin_name should not be used to set options anymore."
          self.plugin_name = args.first
        else
          raise ArgumentError # TODO proper error message
        end
      end
      alias_method :plugin, :plugin_name

      # Set or query the required plugin options.
      # @overload required_options()
      #   @return [Array<Symbol>] The required plugin options
      #   @since 1.2.0
      #
      # @overload required_options(options)
      #   @param [Array<Symbol>] options The required options
      #   @return [void]
      #   @deprecated See {#set} or {ClassAttributes#required_options=} instead
      def required_options(*args)
        case args.size
        when 0
          return @required_options
        when 1
          $stderr.puts "Deprecation warning: Beginning with version 1.2.0, required_options should not be used to set options anymore."
          self.required_options = args.first
        else
          raise ArgumentError # TODO proper error message
        end
      end

      # @example
      #   timer 5, method: :some_method
      #   def some_method
      #     Channel("#cinch-bots").send(Time.now.to_s)
      #   end
      #
      # @param [Number] interval Interval in seconds
      # @param [Proc] block A proc to execute
      # @option options [Symbol] :method (:timer) Method to call (only if no proc is provided)
      # @option options [Boolean] :threaded (true) Call method in a thread?
      # @return [void]
      def timer(interval, options = {}, &block)
        options = {:method => :timer, :threaded => true}.merge(options)
        @timers << Timer.new(interval, block || options[:method], options[:threaded], false)
      end

      # Defines a hook which will be run before or after a handler is
      # executed, depending on the value of `type`.
      #
      # @param [Symbol<:pre, :post>] type Run the hook before or after
      #   a handler?
      # @option options [Array<:match, :listen_to, :ctcp>] :for ([:match, :listen_to, :ctcp])
      #   Which kinds of events to run the hook for.
      # @option options [Symbol] :method (true) The method to execute.
      # @return [void]
      def hook(type, options = {})
        options = {:for => [:match, :listen_to, :ctcp], :method => :hook}.merge(options)
        __hooks(type) << Hook.new(type, options[:for], options[:method])
      end

      # @return [Hash]
      # @api private
      def __hooks(type = nil, events = nil)
        if type.nil?
          hooks = @hooks
        else
          hooks = @hooks[type]
        end

        if events.nil?
          return hooks
        else
          events = [*events]
          if hooks.is_a?(Hash)
            hooks = hooks.map { |k, v| v }
          end
          return hooks.select { |hook| (events & hook.for).size > 0 }
        end
      end

      # @return [void]
      # @api private
      def call_hooks(type, event, instance, args)
        __hooks(type, event).each do |hook|
          instance.__send__(hook.method, *args)
        end
      end

      # @param [Bot] bot
      # @return [Array<Symbol>, nil]
      # @since 1.2.0
      def check_for_missing_options(bot)
        @required_options.select { |option|
          !bot.config.plugins.options[self].has_key?(option)
        }
      end
      private :check_for_missing_options

      # @return [void]
      # @api private
      def __register_with_bot(bot, instance)
        missing = check_for_missing_options(bot)
        unless missing.empty?
          bot.debug "[plugin] #{plugin_name}: Could not register plugin because the following options are not set: #{missing.join(", ")}"
          return
        end

        @listeners.each do |listener|
          bot.debug "[plugin] #{plugin_name}: Registering listener for type `#{listener.event}`"
          bot.on(listener.event, [], instance) do |message, plugin, *args|
            if plugin.respond_to?(listener.method)
              plugin.class.call_hooks(:pre, :listen_to, plugin, [message])
              plugin.__send__(listener.method, message, *args)
              plugin.class.call_hooks(:post, :listen_to, plugin, [message])
            else
              $stderr.puts "Warning: The plugin '#{plugin.class.plugin_name}' is missing the method '#{listener.method}'. Beginning with version 2.0.0, this will cause an exception."
            end
          end
        end

        if @matchers.empty?
          @matchers << Match.new(plugin_name, true, true, :execute)
        end

        prefix = @prefix || bot.config.plugins.prefix
        suffix = @suffix || bot.config.plugins.suffix

        @matchers.each do |pattern|
          _prefix = pattern.use_prefix ? prefix : nil
          _suffix = pattern.use_suffix ? suffix : nil

          pattern_to_register = Pattern.new(_prefix, pattern.pattern, _suffix)
          react_on = @react_on || :message

          bot.debug "[plugin] #{plugin_name}: Registering executor with pattern `#{pattern_to_register.inspect}`, reacting on `#{react_on}`"

          bot.on(react_on, pattern_to_register, instance, pattern) do |message, plugin, pattern, *args|
            if plugin.respond_to?(pattern.method)
              method = plugin.method(pattern.method)
              arity = method.arity - 1
              if arity > 0
                args = args[0..arity - 1]
              elsif arity == 0
                args = []
              end
              plugin.class.__hooks(:pre, :match).each {|hook| plugin.__send__(hook.method, message)}
              method.call(message, *args)
              plugin.class.__hooks(:post, :match).each {|hook| plugin.__send__(hook.method, message)}
            else
              $stderr.puts "Warning: The plugin '#{plugin.class.plugin_name}' is missing the method '#{pattern.method}'. Beginning with version 2.0.0, this will cause an exception."
            end
          end
        end

        @ctcps.each do |ctcp|
          bot.debug "[plugin] #{plugin_name}: Registering CTCP `#{ctcp}`"
          bot.on(:ctcp, ctcp, instance, ctcp) do |message, plugin, ctcp, *args|
            plugin.class.__hooks(:pre, :ctcp).each {|hook| plugin.__send__(hook.method, message)}
            plugin.__send__("ctcp_#{ctcp.downcase}", message, *args)
            plugin.class.__hooks(:post, :ctcp).each {|hook| plugin.__send__(hook.method, message)}
          end
        end

        @timers.each do |timer|
          # TODO move debug message to instance method
          bot.debug "[plugin] #{plugin_name}: Registering timer with interval `#{timer.interval}` for method `#{timer.method}`"
          bot.on :connect do
            next if timer.registered
            instance.timer(timer.interval,
                           {:method => timer.method, :threaded => timer.threaded})
            timer.registered = true
          end
        end

        if @help
          bot.debug "[plugin] #{plugin_name}: Registering help message"
          help_pattern = Pattern.new(prefix, "help #{plugin_name}", suffix)
          bot.on(:message, help_pattern, @help) do |message, help_message|
            message.reply(help_message)
          end
        end
      end
    end

    # @return [Bot]
    attr_reader :bot
    # @api private
    def initialize(bot)
      @bot = bot
      self.class.__register_with_bot(bot, self)
    end

    # (see Bot#synchronize)
    def synchronize(*args, &block)
      @bot.synchronize(*args, &block)
    end

    # This method will be executed whenever an event the plugin
    # {Plugin::ClassMethods#listen_to listens to} occurs.
    #
    # @abstract
    # @return [void]
    # @see Plugin::ClassMethods#listen_to
    def listen(*args)
      $stderr.puts "Warning: The plugin '#{self.class.plugin_name}' is missing the method 'listen'. Beginning with version 2.0.0, this will cause an exception."
    end

    # This method will be executed whenever a message matches the
    # {Plugin::ClassMethods#match match pattern} of the plugin.
    #
    # @abstract
    # @return [void]
    # @see Plugin::ClassMethods#match
    def execute(*args)
      $stderr.puts "Warning: The plugin '#{self.class.plugin_name}' is missing the method 'execute'. Beginning with version 2.0.0, this will cause an exception."
    end

    # Provides access to plugin-specific options.
    #
    # @return [Hash] A hash of options
    def config
      @bot.config.plugins.options[self.class] || {}
    end

    # @api private
    def self.included(by)
      by.extend ClassMethods
    end
  end
end
