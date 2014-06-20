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
  class Publishers
    def self.description_setter(params, xml)
      xml.send('hudson.plugins.descriptionsetter.DescriptionSetterPublisher') {
        xml.regexp params[:regexp]
        xml.regexpForFailed params[:regexp]
        xml.description params[:description]
        xml.descriptionForFailed params[:description]
        xml.setForMatrix false
      }
    end

    def self.push_to_projects(params, xml)
      xml.send('hudson.plugins.parameterizedtrigger.BuildTrigger') {
        xml.configs {
          xml.send('hudson.plugins.parameterizedtrigger.BuildTriggerConfig') {
            xml.configs {
              params[:data] = [ { params: "" } ] unless params[:data]
              params[:data].each do |config|
                if config[:params]
                  xml.send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') {
                    xml.properties config[:params]
                  }
                end
                if config[:file]
                  xml.send('hudson.plugins.parameterizedtrigger.FileBuildParameters') {
                    xml.propertiesFile config[:file]
                    xml.failTriggerOnMissing false
                  }
                end
              end
            }
            xml.projects params[:project]
            xml.condition params[:condition] || 'SUCCESS'
            xml.triggerWithNoParameters params[:trigger_with_no_parameters] || false
          }
        }
      }
    end

    def self.push_to_hipchat(params, xml)
      params = {} if params == true
      xml.send('jenkins.plugins.hipchat.HipChatNotifier') {
        xml.jenkinsUrl params[:jenkinsUrl] || ''
        xml.authToken params[:authToken] || ''
        xml.room params[:room] || ''
      }
    end

    def self.push_to_git(params, xml)
      xml.send('hudson.plugins.git.GitPublisher') {
        xml.configVersion params[:configVersion] || 2
        xml.pushMerge params[:'push-merge'] || false
        xml.pushOnlyIfSuccess params[:'push-only-if-success'] || false
        xml.branchesToPush {
          xml.send('hudson.plugins.git.GitPublisher_-BranchToPush') {
            xml.targetRepoName params[:targetRepoName] || 'origin'
            xml.branchName params[:branchName] || 'master'
          }
        }
      }
    end

    def self.publish_junit(params, xml)
      xml.send('hudson.tasks.junit.JUnitResultArchiver') {
        xml.testResults params[:test_results] || ''
        xml.keepLongStdio false
        xml.testDataPublishers
      }
    end

    def self.coverage_metric(name, params, xml)
      xml.send('hudson.plugins.rubyMetrics.rcov.model.MetricTarget') {
        xml.metric name
        xml.healthy params[:healthy]
        xml.unhealthy params[:unhealthy]
        xml.unstable params[:unstable]
      }
    end

    def self.publish_rcov(params, xml)
      xml.send('hudson.plugins.rubyMetrics.rcov.RcovPublisher') {
        xml.reportDir params[:report_dir]
        xml.targets {
          coverage_metric('TOTAL_COVERAGE', params[:total], xml)
          coverage_metric('CODE_COVERAGE', params[:code], xml)
        }
      }
    end

    def self.post_build_script(params, xml)
      xml.send('org.jenkinsci.plugins.postbuildscript.PostBuildScript') {
        xml.buildSteps {
          if params[:shell_command]
            xml.send('hudson.tasks.Shell') {
              xml.command params[:shell_command]
            }
          end
        }
        xml.scriptOnlyIfSuccess params[:on_success]
        xml.scriptOnlyIfFailure params[:on_failure]
        xml.executeOn params[:execute_on] || 'BOTH'
      }
    end

    def self.groovy_postbuild(params, xml)
      xml.send('org.jvnet.hudson.plugins.groovypostbuild.GroovyPostbuildRecorder', 'plugin' => 'groovy-postbuild') {
        xml.groovyScript params[:groovy_script]
        xml.behavior params[:behavior] || '0'
        xml.runFormMatrixParent 'false'
        if params[:additional_classpaths]
          params[:additional_classpaths].each do |path|
            xml.send('org.jvnet.hudson.plugins.groovypostbuild.GroovyScriptPath') {
              xml.path path[:path] || '/'
            }
          end
        end
      }
    end

  end
end
