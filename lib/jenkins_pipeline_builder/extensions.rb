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

    def initialize(type, path = nil, &block)
      @blocks = {}
      @settings = {}
      @extensions = []

      instance_eval(&block)

      blocks.each do |version, settings|
        add_extension type, version, settings, path
      end
    end

    def installed_version=(version)
      version = version.match(/\d+\.\d+/)
      @version = Gem::Version.new version
    end

    def add_extension(type, version, settings, path = nil)
      ext = JenkinsPipelineBuilder::Extension.new
      ext.min_version version
      ext.type type
      self.settings.merge(settings).each do |key, value|
        ext.send key, value
      end

      ext.path path unless ext.path
      extensions << ext
    end

    def installed_version
      return @version if @version
      reg = JenkinsPipelineBuilder.registry
      version = reg.versions[settings[:plugin_id]]
      fail "Plugin #{settings[:name]} is not installed (plugin_id: #{settings[:plugin_id]})" if version.nil?
      self.installed_version = version
      @version
    end

    def extension
      # TODO: Support multiple xml sections for the native to jenkins plugins
      return extensions.first if settings[:plugin_id] == 'builtin'

      extension = versions[highest_allowed_version]

      unless extension
        fail "Can't find version of #{name} lte #{installed_version}, available versions: #{versions.keys.map(&:to_s)}"
      end
      extension
    end

    def merge(other_set)
      mismatch = []
      SET_METHODS.each do |method_name|
        val1 = settings[method_name]
        val2 = other_set.settings[method_name]
        mismatch << "The values for #{method_name} do not match '#{val1}' : '#{val2}'" unless val1 == val2
      end
      mismatch.each do |error|
        puts error
      end
      fail 'Values did not match, cannot merge exception sets' if mismatch.any?

      blocks.merge other_set.blocks
    end

    def parameters(params)
      version = @min_version || '0'

      blocks[version] = {} unless blocks[version]
      blocks[version][:parameters] = params
    end

    def xml(path: false, version: '0', &block)
      if @min_version
        version = @min_version
      elsif version != '0'
        deprecation_warning(settings[:name], 'xml')
      end
      unless block
        fail "no block found for version #{version}" unless blocks.key version
        return blocks[version][:block]
      end
      store_xml version, block, path
    end

    def version(ver, &block)
      @min_version = ver
      yield block
    end

    [:after, :before].each do |method_name|
      define_method method_name do |version: '0', &block|
        if @min_version
          version = @min_version
        elsif version != '0'
          deprecation_warning(settings[:name], method_name)
        end

        return instance_variable_get(method_name) unless block
        blocks[version] = {} unless blocks[version]
        blocks[version][method_name] = block
      end
    end

    def valid?
      valid = errors.empty?
      unless valid
        name ||= 'A plugin with no name provided'
        puts "Encountered errors while registering #{name}"
        puts errors.map { |k, v| "#{k}: #{v}" }.join(', ')
      end
      valid
    end

    def errors
      errors = {}
      errors['ExtensionSet'] = 'no extensions successfully registered' if extensions.empty?
      extensions.each do |ext|
        ver = ext.min_version || 'unknown'
        errors["#{ext.name} version #{ver}"] = ext.errors unless ext.valid?
      end
      errors
    end

    private

    def highest_allowed_version
      ordered_version_list.each do |version|
        return version if version <= installed_version
      end
    end

    def store_xml(version, block, path)
      if blocks[version]
        blocks[version].merge!(xml: block, path: path)
      else
        blocks[version] = { xml: block, path: path }
      end
    end

    def versions
      @versions ||= extensions.each_with_object({}) do |ext, hash|
        hash[Gem::Version.new(ext.min_version)] = ext
      end
    end

    def ordered_version_list
      versions.keys.sort.reverse
    end

    def deprecation_warning(name, block)
      puts "WARNING: #{name} set the version in the #{block} block, this is deprecated. Please use a version block."
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

    def errors
      errors = {}
      EXT_METHODS.keys.each do |name|
        errors[name] = 'Must be set' if send(name).nil?
      end
      errors
    end
  end
end
