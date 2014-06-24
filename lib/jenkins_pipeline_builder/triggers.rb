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
  class Triggers < Extendable
    register :git_push do |_, xml|
      xml.send('com.cloudbees.jenkins.GitHubPushTrigger') do
        xml.spec
      end
    end

    register :scm_polling do |scm_polling, xml|
      xml.send('hudson.triggers.SCMTrigger') do
        xml.spec scm_polling
        xml.ignorePostCommitHooks false
      end
    end

    register :periodic_build do |periodic_build, xml|
      xml.send('hudson.triggers.TimerTrigger') do
        xml.spec periodic_build
      end
    end

    register :upstream do |params, xml|
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
