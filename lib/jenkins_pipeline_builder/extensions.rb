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

module JenkinsPipelineBuilder
  class Extension
    attr_accessor :helper
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
    }.freeze

    EXT_METHODS.each_key do |method_name|
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
      errors = check_parameters value
      raise ArgumentError, errors.join("\n") if errors.any?

      unless path
        raise ArgumentError, %(Extension #{name} has no valid path
        Check ModuleRegistry#entries and the definition of the extension
        Note: job_attributes have no implicit path and must be set in the builder
        ).squeeze(' ')
      end

      n_builders = n_xml.xpath(path).first
      n_builders.instance_exec(value, &before) if before
      build_extension_xml n_builders, value
      n_builders.instance_exec(value, &after) if after
      true
    end

    def check_parameters(value)
      return [] if parameters && parameters.empty?
      return [] unless value.is_a? Hash

      errors = []
      value.each_key do |key|
        next if parameters && parameters.include?(key)

        errors << "Extension #{name} does not support parameter #{key}"
      end
      errors
    end

    def errors
      errors = {}
      EXT_METHODS.each_key do |name|
        errors[name] = 'Must be set' if send(name).nil?
      end
      errors
    end

    private

    def build_extension_xml(n_builders, value)
      Nokogiri::XML::Builder.with(n_builders) do |builder|
        include_helper value, builder
        builder.instance_exec helper, &xml
      end
    end

    def include_helper(params, builder)
      klass = "#{name.to_s.camelize}Helper".safe_constantize
      klass ||= ExtensionHelper
      self.helper = klass.new self, params, builder
    end
  end
end
