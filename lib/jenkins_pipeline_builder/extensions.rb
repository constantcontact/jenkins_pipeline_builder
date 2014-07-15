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
    set = JenkinsPipelineBuilder::ExtensionSet.new
    set.instance_eval(&block)
    set.blocks.each do |version, settings|
      ext = JenkinsPipelineBuilder::Extension.new
      ext.min_version version
      ext.type singular_type
      set.settings.merge(settings).each do |key, value|
        ext.send key, value
      end
      ext.path path unless ext.path
      set.extensions << ext
    end
    unless set.valid?
      name = set.name || 'A plugin with no name provided'
      puts "Encountered errors while registering #{name}"
      puts set.errors.map { |k, v| "#{k}: #{v}" }.join(', ')
      return false
    end
    JenkinsPipelineBuilder.registry.register([:job, type], set)
    versions = set.extensions.map { |ext| ext.min_version }
    puts "Successfully registered #{set.name} for versions #{versions}" if set.announced
  end
end

def job_attribute(&block)
  set = JenkinsPipelineBuilder::ExtensionSet.new
  set.instance_eval(&block)
  set.blocks.each do |version, settings|
    ext = JenkinsPipelineBuilder::Extension.new
    ext.min_version version
    ext.type :job_attribute
    set.settings.merge(settings).each do |key, value|
      ext.send key, value
    end
    set.extensions << ext
  end
  unless set.valid?
    name = set.name || 'A plugin with no name provided'
    puts "Encountered errors while registering #{name}"
    puts set.errors.map { |k, v| "#{k}: #{v}" }.join(', ')
    return false
  end
  JenkinsPipelineBuilder.registry.register([:job], set)
  puts "Successfully registered #{set.name} for versions #{set.min_version} and higher" if set.announced
end

module JenkinsPipelineBuilder
  class ExtensionSet
    SET_METHODS = [
      :name,
      :plugin_id,
      :jenkins_name,
      :description,
      :announced,
      :type
    ]
    SET_METHODS.each do |method_name|
      define_method method_name do |value = nil|
        return settings[method_name] if value.nil?
        settings[method_name] = value
      end
    end

    attr_accessor :blocks, :extensions, :settings

    def initialize
      @blocks = {}
      @settings = {}
      @extensions = []
    end

    def get_extension(version = '0')
      extensions.first
    end

    def merge(other_set)
      mismatch = []
      SET_METHODS.each do |method_name|
        val1 = settings[method_name]
        val2 = other_set.settings[method_name]
        mismatch << "The values for #{method_name} do not match #{val1} : #{val2}" unless val1 == val2
      end
      mismatch.each do |error|
        puts error
      end
      fail 'Values did not match, cannot merge exception sets' if mismatch.any?

      blocks.merge other_set.blocks
    end

    def xml(path: false, version: '0', &block)
      unless block
        fail "no block found for version #{version}" unless blocks.key version
        return blocks[version][:block]
      end
      blocks[version] = { xml: block, path: path }
    end

    def after(version: '0', &block)
      return @after unless block
      blocks[version] = {} unless blocks[version]
      blocks[version][:after] = block
    end

    def before(version: '0', &block)
      return @before unless block
      blocks[version] = {} unless blocks[version]
      blocks[version][:before] = block
    end

    def valid?
      errors.empty?
    end

    def errors
      errors = {}
      extensions.each do |ext|
        ver = ext.min_version || 'unknown'
        errors["#{ext.name} version #{ver}"] = ext.errors unless ext.valid?
      end
      errors
    end
  end
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
      xml: false
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

    def errors
      errors = {}
      EXT_METHODS.keys.each do |name|
        errors[name] = 'Must be set' if send(name).nil?
      end
      errors
    end
  end
end
