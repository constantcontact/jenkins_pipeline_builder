require 'jenkins_pipeline_builder'
JenkinsPipelineBuilder.registry.entries.each do |type, path|
  singular_type = type.to_s.singularize
  define_method singular_type do |&block|
    ext = JenkinsPipelineBuilder::Extension.new
    ext.instance_eval(&block)
    ext.path path
    unless ext.valid?
      name = ext.name || 'A plugin with no name provided'
      puts "Encountered errors while registering #{name}"
      puts ext.errors.map { |k, v| "#{k}: #{v}" }.join(', ')
      return false
    end
    JenkinsPipelineBuilder.registry.register([:job, type], ext)
    puts "Successfully registered #{ext.name} for versions #{ext.min_version} and higher" if ext.announced
  end
end

def job_attribute(&block)
  ext = JenkinsPipelineBuilder::Extension.new
  ext.instance_eval(&block)
  unless ext.valid?
    name = ext.name || 'A plugin with no name provided'
    puts "Encountered errors while registering #{name}"
    puts ext.errors.map { |k, v| "#{k}: #{v}" }.join(', ')
    return false
  end
  JenkinsPipelineBuilder.registry.register([:job], ext)
  puts "Successfully registered #{ext.name} for versions #{ext.min_version} and higher" if ext.announced
end

module JenkinsPipelineBuilder
  class Extension
    DSL_METHODS = {
      name: false,
      plugin_id: false,
      min_version: false,
      jenkins_name: 'No jenkins display name set',
      description: 'No description set',
      path: false,
      announced: true
    }
    DSL_METHODS.keys.each do |method_name|
      define_method method_name do |value = nil|
        return instance_variable_get("@#{method_name}") if value.nil?
        instance_variable_set("@#{method_name}", value)
      end
    end

    def xml(path = false, &block)
      @path = path if path
      return @xml unless block
      @xml = block
    end

    def after(&block)
      return @after unless block
      @after = block
    end

    def before(&block)
      return @before unless block
      @before = block
    end

    def initialize
      DSL_METHODS.each do |key, value|
        instance_variable_set("@#{key}", value) if value
      end
    end

    def valid?
      errors.empty?
    end

    def errors
      errors = {}
      DSL_METHODS.keys.each do |name|
        errors[name] = 'Must be set' if send(name).nil?
      end
      errors
    end
  end
end
