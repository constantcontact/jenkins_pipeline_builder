#
# Copyright (c) 2014 Igor Moochnick
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
    attr_accessor :registry

    def initialize(registry)
      @registry = registry
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
        execute_registry_item(registry, key, value, n_xml)
      end
    end

    def traverse_registry_param_array(registry, params, n_xml)
      params.each do |item|
        key = item.keys.first
        next if key.nil?
        execute_registry_item(registry, key, item[key], n_xml)
      end
    end

    def execute_registry_item(registry, key, value, n_xml)
      registry_item = registry[key]
      if registry_item.kind_of?(Hash)
        sub_registry = registry_item[:registry]
        method = registry_item[:method]
        method.call(sub_registry, value, n_xml)
      elsif registry_item.kind_of?(Method) || registry_item.kind_of?(Proc)
        registry_item.call(value, n_xml) unless registry_item.nil?
      end
    end

    def run_registry_on_path(path, registry, params, n_xml)
      n_builders = n_xml.xpath(path).first
      Nokogiri::XML::Builder.with(n_builders) do |xml|
        traverse_registry_param_array(registry, params, xml)
      end
    end
  end
end
