class BlockingDownstreamHelper < ExtensionHelper
  attr_reader :colors
  def initialize(params)
    super params
    @colors = {
      'SUCCESS' => { ordinal:  0, color:  'BLUE' },
      'FAILURE' => { ordinal:  2, color:  'RED' },
      'UNSTABLE' => { ordinal:  1, color:  'YELLOW' }
    }
  end
end
