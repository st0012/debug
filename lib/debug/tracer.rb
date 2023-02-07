# frozen_string_literal: true

class BaseTracer
  M_OBJECT_ID = method(:object_id).unbind
  HOME = ENV['HOME'] ? (ENV['HOME'] + '/') : nil

  class LimitedPP
    def self.pp(obj, max)
      out = self.new(max)
      catch out do
        PP.singleline_pp(obj, out)
      end
      out.buf
    end

    attr_reader :buf

    def initialize max
      @max = max
      @cnt = 0
      @buf = String.new
    end

    def <<(other)
      @buf << other

      if @buf.size >= @max
        @buf = @buf[0..@max] + '...'
        throw self
      end
    end
  end

  def safe_inspect obj, max_length: 40
    LimitedPP.pp(obj, max_length)
  rescue NoMethodError => e
    klass, oid = M_CLASS.bind_call(obj), M_OBJECT_ID.bind_call(obj)
    if obj == (r = e.receiver)
      "<\##{klass.name}#{oid} does not have \#inspect>"
    else
      rklass, roid = M_CLASS.bind_call(r), M_OBJECT_ID.bind_call(r)
      "<\##{klass.name}:#{roid} contains <\##{rklass}:#{roid} and it does not have #inspect>"
    end
  rescue Exception => e
    "<#inspect raises #{e.inspect}>"
  end

  def colorize(str, color)
    # don't colorize trace sent into a file
    if @output.is_a?(File)
      str
    else
      IRB::Color.colorize str, color
    end
  end

  def colorize_cyan(str)
    colorize(str, [:CYAN, :BOLD])
  end

  def colorize_blue(str)
    colorize(str, [:BLUE, :BOLD])
  end

  def colorize_magenta(str)
    colorize(str, [:MAGENTA, :BOLD])
  end

  def pretty_path path
    return '#<none>' unless path

    case
    when path.start_with?(dir = RbConfig::CONFIG["rubylibdir"] + '/')
      path.sub(dir, '$(rubylibdir)/')
    when Gem.path.any? do |gp|
        path.start_with?(dir = gp + '/gems/')
      end
      path.sub(dir, '$(Gem)/')
    when HOME && path.start_with?(HOME)
      path.sub(HOME, '~/')
    else
      path
    end
  end

  def initialize(output: STDOUT, pattern: nil)
    @name = self.class.name
    @type = @name.sub(/Tracer\z/, '')
    @output = output

    if pattern
      @pattern = Regexp.compile(pattern)
    else
      @pattern = nil
    end

    @tp = setup

    puts "PID:#{Process.pid} #{self}" if @output.is_a?(File)
  end

  def key
    [@type, @pattern, @into].freeze
  end

  def header
    ""
  end

  def to_s
    s = "#{@name}#{description} (#{@tp.enabled? ? 'enabled' : 'disabled'})"
    s += " with pattern #{@pattern.inspect}" if @pattern
    s
  end

  def description
    nil
  end

  def enable
    @tp.enable
    self
  end

  def disable
    @tp.disable
  end

  def skip?(tp)
    skip_with_pattern?(tp)
  end

  def skip_with_pattern?(tp)
    @pattern && !tp.path.match?(@pattern)
  end

  def out tp, msg = nil, depth = caller.size - 1
    location_str = colorize("#{pretty_path(tp.path)}:#{tp.lineno}", [:GREEN])
    buff = "#{header} \#depth:#{'%-2d'%depth}#{msg} at #{location_str}"

    puts buff
  end

  def puts msg
    @output.puts msg
    @output.flush
  end

  def minfo tp
    return "block{}" if tp.event == :b_call

    klass = tp.defined_class

    if klass.singleton_class?
      "#{tp.self}.#{tp.method_id}"
    else
      "#{klass}\##{tp.method_id}"
    end
  end
end

class LineTracer < BaseTracer
  def setup
    TracePoint.new(:line){|tp|
      next if skip?(tp)
      # pp tp.object_id, caller(0)
      out tp
    }
  end
end

class CallTracer < BaseTracer
  def setup
    TracePoint.new(:a_call, :a_return){|tp|
      next if skip?(tp)

      depth = caller.size

      call_identifier_str =
        if tp.defined_class
          minfo(tp)
        else
          "block"
        end

      call_identifier_str = colorize_blue(call_identifier_str)

      case tp.event
      when :call, :c_call, :b_call
        depth += 1 if tp.event == :c_call
        sp = ' ' * depth
        out tp, ">#{sp}#{call_identifier_str}", depth
      when :return, :c_return, :b_return
        depth += 1 if tp.event == :c_return
        sp = ' ' * depth
        return_str = colorize_magenta(safe_inspect(tp.return_value))
        out tp, "<#{sp}#{call_identifier_str} #=> #{return_str}", depth
      end
    }
  end

  def skip_with_pattern?(tp)
    super && !tp.method_id&.match?(@pattern)
  end
end

class ExceptionTracer < BaseTracer
  def setup
    TracePoint.new(:raise) do |tp|
      next if skip?(tp)

      exc = tp.raised_exception

      out tp, " #{colorize_magenta(exc.inspect)}"
    rescue Exception => e
      p e
    end
  end

  def skip_with_pattern?(tp)
    super && !tp.raised_exception.inspect.match?(@pattern)
  end
end

class ObjectTracer < BaseTracer
  def initialize obj_id, obj_inspect, **kw
    @obj_id = obj_id
    @obj_inspect = obj_inspect
    super(**kw)
  end

  def key
    [@type, @obj_id, @pattern, @into].freeze
  end

  def description
    " for #{@obj_inspect}"
  end

  def colorized_obj_inspect
    colorize_magenta(@obj_inspect)
  end

  def setup
    TracePoint.new(:a_call){|tp|
      next if skip?(tp)

      if M_OBJECT_ID.bind_call(tp.self) == @obj_id
        klass = tp.defined_class
        method = tp.method_id
        method_info =
          if klass.singleton_class?
            if tp.self.is_a?(Class)
              ".#{method} (#{klass}.#{method})"
            else
              ".#{method}"
            end
          else
            "##{method} (#{klass}##{method})"
          end

        out tp, " #{colorized_obj_inspect} receives #{colorize_blue(method_info)}"
      elsif !tp.parameters.empty?
        b = tp.binding
        method_info = colorize_blue(minfo(tp))

        tp.parameters.each{|type, name|
          next unless name

          colorized_name = colorize_cyan(name)

          case type
          when :req, :opt, :key, :keyreq
            if b.local_variable_get(name).object_id == @obj_id
              out tp, " #{colorized_obj_inspect} is used as a parameter #{colorized_name} of #{method_info}"
            end
          when :rest
            next if name == :"*"

            ary = b.local_variable_get(name)
            ary.each{|e|
              if e.object_id == @obj_id
                out tp, " #{colorized_obj_inspect} is used as a parameter in #{colorized_name} of #{method_info}"
              end
            }
          when :keyrest
            next if name == :'**'
            h = b.local_variable_get(name)
            h.each{|k, e|
              if e.object_id == @obj_id
                out tp, " #{colorized_obj_inspect} is used as a parameter in #{colorized_name} of #{method_info}"
              end
            }
          end
        }
      end
    }
  end
end

module DEBUGGER__
  module TracerExtension
    include SkipPathHelper

    def header
      "DEBUGGER (trace/#{@type}) \#th:#{Thread.current.instance_variable_get(:@__thread_client_id)}"
    end

    def skip? tp
      ThreadClient.current.management? || skip_path?(tp.path) || super
    end

    def setup
      @name = @name.sub(/DEBUGGER__::/, "")
      @type = @type.sub(/DEBUGGER__::/, "").downcase
      super
    end

    def to_s
      s = super
      s += " into: #{File.basename(@output)}" if @output.is_a?(File)
      s
    end

    def colorize str, color
      if !CONFIG[:no_color]
        super str, color
      else
        str
      end
    end
  end

  class LineTracer < ::LineTracer
    include TracerExtension
  end

  class CallTracer < ::CallTracer
    include TracerExtension
  end

  class ExceptionTracer < ::ExceptionTracer
    include TracerExtension
  end

  class ObjectTracer < ::ObjectTracer
    include TracerExtension
  end
end

