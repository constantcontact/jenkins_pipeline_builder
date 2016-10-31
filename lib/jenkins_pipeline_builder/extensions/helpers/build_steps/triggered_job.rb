class TriggeredJobHelper < ExtensionHelper
  # @param xml_builder [Nokogiri::Builder] this will be self inside an extension
  # @param threshold_type [String, Symbol] case-insensitive string or symbol
  #  from the %(failure unstable success)
  # @returns [Nokogiri::Builder] continues the mutation of the passed in builder
  def generate_for_threshold(xml_builder, threshold_type)
    case threshold_type
    when /failure/i, :failure
      generate_threshold_xml({ name: 'FAILURE', ordinal: 2, color: 'RED' }, xml_builder)
    when /unstable/i, :unstable
      generate_threshold_xml({ name: 'UNSTABLE', ordinal: 1, color: 'YELLOW' }, xml_builder)
    when /success/i, :success
      generate_threshold_xml({ name: 'SUCCESS', ordinal: 0, color: 'BLUE' }, xml_builder)
    else
      raise ArgumentError("Input should be one of the following either as a case insensitive string or symbol: \n
                          'failure', 'unstable', 'success'")
    end
  end

  def resolve_block_condition(key)
    try(:block_condition).try([], key)
  end

  def block_condition?
    respond_to?(:block_condition) && block_condition != false
  end

  private

  def generate_threshold_xml(data, xml)
    xml.send(:name, data[:name])
    xml.send(:ordinal, data[:ordinal])
    xml.send(:color, data[:color])
    xml.send(:completeBuild, 'true')
  end
end
