JenkinsPipelineBuilder.registry.entries.each do |type, path|
  singular_type = type.to_s.singularize
  define_method singular_type do |&block|
    set = JenkinsPipelineBuilder::ExtensionSet.new singular_type, path, &block
    return false unless set.valid?

    JenkinsPipelineBuilder.registry.register([:job, type], set)
    versions = set.extensions.map(&:min_version)
    JenkinsPipelineBuilder.logger.info "Successfully registered #{set.name} for versions #{versions}" if set.announced
    true
  end
end

def job_attribute(&block)
  set = JenkinsPipelineBuilder::ExtensionSet.new :job_attribute, &block
  return false unless set.valid?

  JenkinsPipelineBuilder.registry.register([:job], set)
  versions = set.extensions.map(&:min_version)
  JenkinsPipelineBuilder.logger.info "Successfully registered #{set.name} for versions #{versions}" if set.announced
  true
end
