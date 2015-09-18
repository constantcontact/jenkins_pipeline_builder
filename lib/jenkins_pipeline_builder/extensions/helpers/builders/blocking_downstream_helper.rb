class BlockingDownstreamHelper < ExtensionHelper
  attr_reader :colors
  def initialize(params, builder)
    super params, builder, defaults
    @colors = {
      'SUCCESS' => { ordinal:  0, color:  'BLUE' },
      'FAILURE' => { ordinal:  2, color:  'RED' },
      'UNSTABLE' => { ordinal: 1, color: 'YELLOW' }
    }
  end

  def defaults
    {
      data: [{ params: '' }],
      trigger_with_no_parameters: false
    }
  end
end
