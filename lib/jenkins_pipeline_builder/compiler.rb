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
  class Compiler
    def self.resolve_value(value, settings)
      value_s = value.to_s.clone
      vars = value_s.scan(/{{([^}]+)}}/).flatten
      vars.select! do |var|
        var_val = settings[var.to_sym]
        value_s.gsub!("{{#{var.to_s}}}", var_val) unless var_val.nil?
        var_val.nil?
      end
      return nil if vars.count != 0
      return value_s
    end

    def self.get_settings_bag(item_bag, settings_bag = {})
      item = item_bag[:value]
      bag = {}
      return unless item.kind_of?(Hash)
      item.keys.each do |k|
        val = item[k]
        if val.kind_of? String
          new_value = resolve_value(val, settings_bag)
          return nil if new_value.nil?
          bag[k] = new_value
        end
      end
      my_settings_bag = settings_bag.clone
      return my_settings_bag.merge(bag)
    end

    def self.compile(item, settings = {})
      case item
        when String
          new_value = resolve_value(item, settings)
          puts "Failed to resolve #{item}" if new_value.nil?
          return new_value
        when Hash
          result = {}
          item.each do |key, value|
            new_value = compile(value, settings)
            puts "Failed to resolve #{value}" if new_value.nil?
            return nil if new_value.nil?
            result[key] = new_value
          end
          return result
        when Array
          result = []
          item.each do |value|
            new_value = compile(value, settings)
            puts "Failed to resolve #{value}" if new_value.nil?
            return nil if new_value.nil?
            result << new_value
          end
          return result
      end
      return item
    end
  end
end
