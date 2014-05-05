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
  class Builders
    def self.build_multijob(params, xml)
      params[:phases].each do |name, content|
        xml.send('com.tikal.jenkins.plugins.multijob.MultiJobBuilder') {
          xml.phaseName name
          xml.phaseJobs {
            content[:jobs].each do |job|
              xml.send('com.tikal.jenkins.plugins.multijob.PhaseJobsConfig') {
                xml.jobName job[:name]
                xml.currParams job[:current_params] || false
                xml.exposedSCM job[:exposed_scm] || false
                if job[:config]
                  xml.configs {
                    if job[:config].has_key? :predefined_build_parameters
                      xml.send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') {
                        xml.properties job[:config][:predefined_build_parameters].join ' '
                      }
                    end
                  }
                end
              }
            end
          }
          xml.continuationCondition content[:continue_condition] || 'SUCCESSFUL'
        }
      end
    end

    def self.build_maven3(params, xml)
      xml.send('org.jfrog.hudson.maven3.Maven3Builder') {
        xml.mavenName params[:mavenName] || 'tools-maven-3.0.3'
        xml.rootPom params[:rootPom]
        xml.goals params[:goals]
        xml.mavenOpts params[:options]
      }
    end

    def self.build_shell_command(param, xml)
      xml.send('hudson.tasks.Shell') {
        xml.command param
      }
    end

    def self.build_environment_vars_injector(params, xml)
      xml.EnvInjectBuilder {
        xml.info {
          xml.propertiesFilePath params
        }
      }
    end
  end
end
