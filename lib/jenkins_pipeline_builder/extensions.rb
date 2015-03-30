#
# Copyright (c) 2014 Constant Contact
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'jenkins_pipeline_builder'
JenkinsPipelineBuilder.registry.entries.each do |type, path|
  singular_type = type.to_s.singularize
  define_method singular_type do |&block|
    set = JenkinsPipelineBuilder::ExtensionSet.new singular_type, path, &block
    return false unless set.valid?

    JenkinsPipelineBuilder.registry.register([:job, type], set)
    versions = set.extensions.map(&:min_version)
    puts "Successfully registered #{set.name} for versions #{versions}" if set.announced
    true
  end
end

def job_attribute(&block)
  set = JenkinsPipelineBuilder::ExtensionSet.new :job_attribute, &block
  return false unless set.valid?

  JenkinsPipelineBuilder.registry.register([:job], set)
  versions = set.extensions.map(&:min_version)
  puts "Successfully registered #{set.name} for versions #{versions}" if set.announced
end

module JenkinsPipelineBuilder
  class Extension
    EXT_METHODS = {
      name: false,
      plugin_id: false,
      jenkins_name: 'No jenkins display name set',
      description: 'No description set',
      announced: true,
      min_version: false,
      path: false,
      type: false,
      before: false,
      after: false,
      xml: false,
      parameters: []
    }
    EXT_METHODS.keys.each do |method_name|
      define_method method_name do |value = nil|
        return instance_variable_get("@#{method_name}") if value.nil?
        instance_variable_set("@#{method_name}", value)
      end
    end

    def initialize
      EXT_METHODS.each do |key, value|
        instance_variable_set("@#{key}", value) if value
      end
      before false
      after false
    end

    def valid?
      errors.empty?
    end

    def execute(value, n_xml)
      errors = []
      check_parameters value
      errors.each do |error|
        logger.error error
      end
      return false if errors.any?

      n_builders = n_xml.xpath(path).first
      n_builders.instance_exec(value, &before) if before
      Nokogiri::XML::Builder.with(n_builders) do |builder|
        builder.instance_exec value, &xml
      end
      n_builders.instance_exec(value, &after) if after
      true
    end

    def check_parameters(value)
      return if parameters && parameters.empty?
      return unless value.is_a? Hash
      value.each_key do |key|
        next if parameters && parameters.include?(key)
        errors << "Extension #{extension.name} does not support parameter #{key}"
      end
    end

    def errors
      errors = {}
      EXT_METHODS.keys.each do |name|
        errors[name] = 'Must be set' if send(name).nil?
      end
      errors
    end
  end
end
