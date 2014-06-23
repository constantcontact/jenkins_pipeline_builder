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
  class ::Hash
    def deep_merge(second)
      merger = proc { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      self.merge(second, &merger)
    end
  end

  class Utils
    # Code was duplicated from jeknins_api_client
    def self.symbolize_keys_deep!(h)
      return unless h.kind_of?(Hash)
      h.keys.each do |k|
        ks    = k.respond_to?(:to_sym) ? k.to_sym : k
        h[ks] = h.delete k # Preserve order even when k == ks
        symbolize_keys_deep! h[ks] if h[ks].kind_of? Hash
        if h[ks].kind_of? Array
          #puts "Array #{h[ks]}"
          h[ks].each { |item| symbolize_keys_deep!(item) }
        end
      end
    end
    def self.hash_merge!(old, new)
      old.merge!(new) do |_key, old, new|
        if old.is_a?(Hash) && new.is_a?(Hash)
          hash_merge!(old, new)
        else
          new
        end
      end
    end
  end
end
