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
    # This class provides various command line operations related to jobs.
    class Pipeline < Thor
      include Thor::Actions

      desc 'dump', 'Dump job'
      def dump(job_name)
        Helper.setup(parent_options).dump(job_name)
      end

      desc 'bootstrap Path', 'Generates pipeline from folder or a file'
      def bootstrap(path, project_name = nil)
        failed = Helper.setup(parent_options).bootstrap(path, project_name)
        fail 'Encountered error during run' unless failed.empty?
      end

      desc 'pull_request Path', 'Generates jenkins jobs based on a git pull request.'
      def pull_request(path, project_name = nil)
        Helper.setup(parent_options).pull_request(path, project_name)
      end

      desc 'file Path', 'Does the same thing as bootstrap but doesn\'t actually create jobs on the server'
      def file(path, project_name = nil)
        Helper.setup(parent_options).file(path, project_name)
      end
    end
  end
end
