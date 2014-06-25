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
  module CLI
    JenkinsPipelineBuilder.registry.entries.each do |entry, _path|
      klass_name = entry.to_s.classify
      klass = Class.new(Thor) do

        modules =  JenkinsPipelineBuilder.registry.registered_modules[entry]
        modules.each do |mod, values|
          desc mod, "Details for #{mod}"
          define_method(mod) do
            display_module(mod, values)
          end
        end

        private

        def display_module(mod, values)
          puts "#{mod}: #{values[:description]}"
        end
      end
      Module.const_set(klass_name, klass)
    end
    class Describe < Thor
      JenkinsPipelineBuilder.registry.entries.each do |entry, _path|
        klass_name = entry.to_s.classify
        singular_model = entry.to_s.singularize

        desc "#{singular_model} [module]", 'Shows details for the named module'
        subcommand singular_model, Module.const_get(klass_name)
      end
    end
  end
end
