module DEBUGGER__
  class BacktraceFormatter
    attr_reader :frames

    COLOR_CODES = {
      green: 10,
      yellow: 11,
      blue: 12,
      megenta: 13,
      cyan: 14,
      orange: 214
    }

    COLOR_RESET_POSTFIX = "\u001b[0m"

    def initialize(frames)
      @frames = frames
    end

    def formatted_traces(max)
      traces = []
      max += 1 if @frames.size == max + 1
      max.times do |i|
        break if i >= @frames.size
        traces << formatted_trace(i)
      end

      traces
    end

    def formatted_trace(i)
      frame = @frames[i]
      location_str = colorize(frame.location_str, :green)
      call_identifier_str = colorize(frame.call_identifier_str, :yellow)

      result = "#{call_identifier_str} at #{location_str}"

      if frame.return_value_str
        return_value_str = colorize(frame.return_value_str, :megenta)
        result += " #=> #{return_value_str}"
      end

      result
    end

    private

    def colorize(content, color)
      color_code = COLOR_CODES[color]
      color_prefix = "\u001b[38;5;#{color_code}m"
      "#{color_prefix}#{content}#{COLOR_RESET_POSTFIX}"
    end
  end
end
