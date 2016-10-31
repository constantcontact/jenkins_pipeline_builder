module CustomErrors
  class ParseError < StandardError
    def initialize(msg, path = nil)
      super(format_msg(msg, path).squeeze(' '))
    end

    private

    def format_msg(msg, path)
      if path.nil?
        %(There was an error while parsing a file:
        #{msg})
      else
        %(There was an error while parsing a file:
        #{path}
        #{msg})
      end
    end
  end
end
