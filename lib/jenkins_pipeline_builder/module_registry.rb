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
#

module JenkinsPipelineBuilder
  class ModuleRegistry
    attr_accessor :registry, :registered_modules
    ENTRIES = {
      builders: '//builders',
      publishers: '//publishers',
      wrappers: '//buildWrappers',
      triggers: '//triggers'
    }

    # creates register_triggers and so on
    # we declare job attribues below since it doesn't follow the pattern
    ENTRIES.keys.each do |key|
      # TODO: Too lazy to figure out a better way to do this
      singular_key = key.to_s.singularize.to_sym
      define_method "register_#{singular_key}" do |extension|
        @registered_modules[key][extension.name] = {
          jenkins_name: extension.jenkins_name,
          description: extension.description
        }
        @registry[:job][key][extension.name] = extension
      end
    end

    def initialize
      @registry = {
        job: {
        }
      }
      @registered_modules = { job_attributes: {} }

      entries.each do |key, _|
        @registered_modules[key] = {}
        @registry[:job][key] = {}
      end
    end

    def entries
      ENTRIES
    end

    def register_job_attribute(extension)
      @registered_modules[:job_attributes][extension.name] = {
        jenkins_name: extension.jenkins_name,
        description: extension.description
      }

      @registry[:job][extension.name] = extension
    end

    def get(path)
      parts = path.split('/')
      get_by_path_collection(parts, @registry)
    end

    def get_by_path_collection(path, registry)
      item = registry[path.shift.to_sym]
      return item if path.count == 0

      get_by_path_collection(path, item)
    end

    def traverse_registry_path(path, params, n_xml)
      registry = get(path)
      traverse_registry(registry, params, n_xml)
    end

    def traverse_registry(registry, params, n_xml)
      params.each do |key, value|
        if registry.is_a? Hash
          next unless registry.key? key
          if registry[key].is_a? Extension
            execute_extension(registry[key], value, n_xml)
          elsif value.is_a? Hash
            traverse_registry registry[key], value, n_xml
          elsif value.is_a? Array
            value.each do |v|
              traverse_registry registry[key], v, n_xml
            end
          end
        end
      end
    end

    def execute_extension(extension, value, n_xml)
      n_builders = n_xml.xpath(extension.path).first
      n_builders.instance_exec(value, &extension.before) if extension.before
      Nokogiri::XML::Builder.with(n_builders) do |xml|
        xml.instance_exec value, &extension.xml
      end
    end
  end
end
