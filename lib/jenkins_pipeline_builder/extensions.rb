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
    ext = JenkinsPipelineBuilder::Extension.new
    ext.instance_eval(&block)
    ext.path path
    ext.type singular_type
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
  ext.type :job_attribute
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
      announced: true,
      type: false
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
