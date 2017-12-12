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

require 'rspec/core/rake_task'
require 'yard'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

RSpec::Core::RakeTask.new

YARD::Config.load_plugin 'thor'
YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb', 'lib/**/**/*.rb']
end

namespace :doc do
  # This task requires that graphviz is installed locally. For more info:
  # http://www.graphviz.org/
  desc 'Generates the class diagram using the yard generated dot file'
  task :generate_class_diagram do
    puts 'Generating the dot file...'
    `yard graph --file jenkins_api_client.dot`
    puts 'Generating class diagram from the dot file...'
    `dot jenkins_api_client.dot -Tpng -o jenkins_api_client_class_diagram.png`
  end
end

task default: %i[spec rubocop]
