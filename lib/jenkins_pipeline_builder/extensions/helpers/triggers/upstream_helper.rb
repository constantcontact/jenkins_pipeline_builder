class UpstreamHelper < ExtensionHelper
  attr_reader :color, :name, :ordinal
  def initialize(extension, params, builder)
    super extension, params, builder

    case params[:status]
    when 'unstable'
      @name = 'UNSTABLE'
      @ordinal = '1'
      @color = 'yellow'
    when 'failed'
      @name = 'FAILURE'
      @ordinal = '2'
      @color = 'RED'
    else
      @name = 'SUCCESS'
      @ordinal = '0'
      @color = 'BLUE'
    end
  end
end
