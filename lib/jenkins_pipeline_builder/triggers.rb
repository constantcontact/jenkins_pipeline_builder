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
  class Triggers
    def self.enable_git_push(_, xml)
      xml.send('com.cloudbees.jenkins.GitHubPushTrigger') do
        xml.spec
      end
    end

    def self.enable_scm_polling(scm_polling, xml)
      xml.send('hudson.triggers.SCMTrigger') do
        xml.spec scm_polling
        xml.ignorePostCommitHooks false
      end
    end

    def self.enable_periodic_build(periodic_build, xml)
      xml.send('hudson.triggers.TimerTrigger') do
        xml.spec periodic_build
      end
    end

    def self.enable_upstream_check(params, xml)
      case params[:status]
      when 'unstable'
        name = 'UNSTABLE'
        ordinal = '1'
        color = 'yellow'
      when 'failed'
        name = 'FAILURE'
        ordinal = '2'
        color = 'RED'
      else
        name = 'SUCCESS'
        ordinal = '0'
        color = 'BLUE'
      end
      xml.send('jenkins.triggers.ReverseBuildTrigger') do
        xml.spec
        xml.upstreamProjects params[:projects]
        xml.send('threshold') do
          xml.name name
          xml.ordinal ordinal
          xml.color color
          xml.completeBuild true
        end
      end
    end
  end
end
