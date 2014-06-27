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
  class Extendable
    def self.register(name, jenkins_name: 'No jenkins display name provided', description: 'No description provided', &block)
      registry = JenkinsPipelineBuilder.registry
      registry.send(class_to_registry_method(to_s), name, jenkins_name, description, 'ansicolor', 1, &block)
    end

    def self.class_to_registry_method(name)
      h = {
        'JenkinsPipelineBuilder::JobBuilder' => :register_job_attribute,
        'JenkinsPipelineBuilder::Builders' => :register_builder,
        'JenkinsPipelineBuilder::Publishers' => :register_publisher,
        'JenkinsPipelineBuilder::Wrappers' => :register_wrapper,
        'JenkinsPipelineBuilder::Triggers' => :register_trigger
      }
      fail "Unknown class #{name} when adding an extension. Known classes are #{h.keys.join ', '}" unless h.key?(name)
      h[name]
    end
  end
end
