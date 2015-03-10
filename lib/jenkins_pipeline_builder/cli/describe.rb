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
    entries = JenkinsPipelineBuilder.registry.entries.keys
    entries << :job_attributes
    entries.each do |entry|
      klass_name = entry.to_s.classify
      # rubocop:disable Style/AccessModifierIndentation
      klass = Class.new(Thor) do
        if entry == :job_attributes
          extensions = JenkinsPipelineBuilder.registry.registry[:job].select { |_, x| x.is_a? ExtensionSet }
        else
          extensions = JenkinsPipelineBuilder.registry.registry[:job][entry]
        end

        extensions.each do |key, extset|
          # TODO: don't just take the first
          ext = extset.extensions.first
          desc key, "Details for #{ext.name}"
          define_method(ext.name) do
            display_module(ext)
          end
        end

        private

        def display_module(ext)
          puts "#{ext.name}: #{ext.description}"
        end
      end
      # rubocop:enable Style/AccessModifierIndentation
      Module.const_set(klass_name, klass)
    end
    class Describe < Thor
      entries = JenkinsPipelineBuilder.registry.entries.keys
      entries << :job_attributes
      entries.each do |entry, _path|
        klass_name = entry.to_s.classify
        singular_model = entry.to_s.singularize

        desc "#{singular_model} [module]", 'Shows details for the named module'
        subcommand singular_model, Module.const_get(klass_name)
      end
    end
  end
end
