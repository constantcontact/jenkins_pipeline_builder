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
  class Compiler
    attr_reader :generator, :job_collection

    def initialize(generator)
      @generator = generator
      @job_collection = generator.job_collection.collection
    end

    def get_settings_bag(item_bag, settings_bag = {})
      item = item_bag[:value]
      bag = {}
      return unless item.is_a?(Hash)
      item.keys.each do |k|
        val = item[k]
        next unless val.is_a? String
        new_value = resolve_value(val, settings_bag)
        return nil if new_value.nil?
        bag[k] = new_value
      end
      my_settings_bag = settings_bag.clone
      my_settings_bag.merge(bag)
    end

    def compile(item, settings = {})
      success, item = handle_enable(item, settings)
      return false, item unless success

      case item
      when String
        return compile_string item, settings
      when Hash
        return compile_hash item, settings
      when Array
        return compile_array item, settings
      end
      [true, item]
    end

    def handle_enable(item, settings)
      return true, item unless item.is_a? Hash
      if item.key?(:enabled) && item.key?(:parameters) && item.length == 2
        enabled_switch = resolve_value(item[:enabled], settings)
        return [true, {}] if enabled_switch == 'false'
        if enabled_switch != 'true'
          return [false, { 'value error' => "Invalid value for #{item[:enabled]}: #{enabled_switch}" }]
        end
        if item[:parameters].is_a? Hash
          item = item.merge item[:parameters]
          item.delete :parameters
          item.delete :enabled
        else
          item = item[:parameters]
        end
      end
      [true, item]
    end

    private

    def compile_string(item, settings)
      errors = {}
      new_value = resolve_value(item, settings)
      errors[item] =  "Failed to resolve #{item}" if new_value.nil?
      return false, errors unless errors.empty?
      [true, new_value]
    end

    def compile_array(item, settings)
      errors = {}
      result = []
      item.each do |value|
        if value.nil?
          errors[item] = "found a nil value when processing following array:\n #{item.inspect}"
          break
        end
        success, payload = compile(value, settings)
        unless success
          errors.merge!(payload)
          next
        end
        if payload.nil?
          errors[value] = "Failed to resolve:\n===>item #{value}\n\n===>of list: #{item}"
          next
        end
        result << payload
      end
      return false, errors unless errors.empty?
      [true, result]
    end

    def compile_item(key, value, errors, settings)
      if value.nil?
        errors[key] = "key: #{key} has a nil value, this is often a yaml syntax error. Skipping children and siblings"
        return false, errors[key]
      end
      success, payload = compile(value, settings)
      unless success
        errors.merge!(payload)
        return false, payload
      end
      if payload.nil?
        errors[key] = "Failed to resolve:\n===>key: #{key}\n\n===>value: #{value}\n\n===>of: #{item}"
        return false, errors[key]
      end
      [true, payload]
    end

    def compile_hash(item, settings)
      success, item = handle_enable(item, settings)
      return false, item unless success

      errors = {}
      result = {}

      item.each do |key, value|
        success, payload = compile_item(key, value, errors, settings)
        next unless success
        result[key] = payload unless payload == {}
      end
      return false, errors unless errors.empty?
      [true, result]
    end

    def resolve_value(value, settings)
      # pull@ designates that this is a reference to a job that will be generated
      # for a pull request, so we want to save the resolution for the second pass
      pull_job = value.to_s.match(/{{pull@(.*)}}/)
      if pull_job
        return pull_job[1] unless settings[:pull_request_number]
        value = pull_job[1]
      end

      settings = settings.with_indifferent_access
      value_s = value.to_s.clone
      # First we try to do job name correction
      vars = value_s.scan(/{{job@(.*)}}/).flatten
      if vars.count > 0
        vars.select! do |var|
          var_val = job_collection[var.to_s]
          value_s.gsub!("{{job@#{var}}}", var_val[:value][:name]) unless var_val.nil?
          var_val.nil?
        end
      end
      # Then we look for normal values to replace
      vars = value_s.scan(/{{([^{}@]+)}}/).flatten
      vars.select! do |var|
        var_val = settings[var]
        value_s.gsub!("{{#{var}}}", var_val.to_s) unless var_val.nil?
        var_val.nil?
      end
      return nil if vars.count != 0
      value_s
    end
  end
end
