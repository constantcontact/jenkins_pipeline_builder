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

class Hash
  def deep_merge(second)
    merger = proc { |_key, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge(v2, &merger) : v2 }
    merge(second, &merger)
  end
end

module JenkinsPipelineBuilder
  class Utils
    # Code was duplicated from jeknins_api_client
    def self.symbolize_keys_deep!(to_symbolize)
      return unless to_symbolize.is_a?(Hash)

      # This lint is disabled here because each_key requires that you not add or remove keys
      # during iteration, which apparently this block does...
      # rubocop:disable Style/HashEachMethods
      to_symbolize.keys.each do |k|
        ks = k.respond_to?(:to_sym) ? k.to_sym : k
        to_symbolize[ks] = to_symbolize.delete k # Preserve order even when k == ks
        symbolize_keys_deep! to_symbolize[ks] if to_symbolize[ks].is_a? Hash
        to_symbolize[ks].each { |item| symbolize_keys_deep!(item) } if to_symbolize[ks].is_a?(Array)
      end
      # rubocop:enable Style/HashEachMethods
    end

    def self.symbolize_with_empty_hash!(array_of_maybe_str)
      array_of_maybe_str.map! do |maybe_str|
        maybe_str.is_a?(String) ? { maybe_str.to_sym => {} } : maybe_str
      end
    end

    def self.hash_merge!(old_hash, new_hash)
      old_hash.merge!(new_hash) do |_key, old, new|
        if old.is_a?(Hash) && new.is_a?(Hash)
          hash_merge!(old, new)
        else
          new
        end
      end
    end
  end
end
