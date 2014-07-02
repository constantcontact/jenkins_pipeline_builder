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

publisher do
  name :description_setter
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('hudson.plugins.descriptionsetter.DescriptionSetterPublisher') do
      regexp params[:regexp]
      regexpForFailed params[:regexp]
      description params[:description]
      descriptionForFailed params[:description]
      setForMatrix false
    end
  end
end

publisher do
  name :downstream
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('hudson.plugins.parameterizedtrigger.BuildTrigger') do
      configs do
        send('hudson.plugins.parameterizedtrigger.BuildTriggerConfig') do
          configs do
            params[:data] = [{ params: '' }] unless params[:data]
            params[:data].each do |config|
              if config[:params]
                send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') do
                  properties config[:params]
                end
              end
              if config[:file]
                send('hudson.plugins.parameterizedtrigger.FileBuildParameters') do
                  propertiesFile config[:file]
                  failTriggerOnMissing false
                end
              end
            end
          end
          projects params[:project]
          condition params[:condition] || 'SUCCESS'
          triggerWithNoParameters params[:trigger_with_no_parameters] || false
        end
      end
    end
  end
end

publisher do
  name :hipchat
  plugin_id 101
  min_version 0
  announced false

  xml do |params|
    params = {} if params == true
    send('jenkins.plugins.hipchat.HipChatNotifier') do
      jenkinsUrl params[:jenkinsUrl] || ''
      authToken params[:authToken] || ''
      room params[:room] || ''
    end
  end
end

publisher do
  name :git
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('hudson.plugins.git.GitPublisher') do
      configVersion params[:configVersion] || 2
      pushMerge params[:'push-merge'] || false
      pushOnlyIfSuccess params[:'push-only-if-success'] || false
      branchesToPush do
        send('hudson.plugins.git.GitPublisher_-BranchToPush') do
          targetRepoName params[:targetRepoName] || 'origin'
          branchName params[:branchName] || 'master'
        end
      end
    end
  end
end

publisher do
  name :junit_result
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('hudson.tasks.junit.JUnitResultArchiver') do
      testResults params[:test_results] || ''
      keepLongStdio false
      testDataPublishers
    end
  end
end

publisher do
  name :coverage_result
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('hudson.plugins.rubyMetrics.rcov.RcovPublisher') do
      reportDir params[:report_dir]
      targets do
        { 'TOTAL_COVERAGE' => params[:total], 'CODE_COVERAGE' => params[:code] }.each do |key, params|
          send('hudson.plugins.rubyMetrics.rcov.model.MetricTarget') do
            metric key
            healthy params[:healthy]
            unhealthy params[:unhealthy]
            unstable params[:unstable]
          end
        end
      end
    end
  end
end

publisher do
  name :post_build_script
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('org.jenkinsci.plugins.postbuildscript.PostBuildScript') do
      buildSteps do
        if params[:shell_command]
          send('hudson.tasks.Shell') do
            command params[:shell_command]
          end
        end
      end
      scriptOnlyIfSuccess params[:on_success]
      scriptOnlyIfFailure params[:on_failure]
      executeOn params[:execute_on] || 'BOTH'
    end
  end
end

publisher do
  name :groovy_postbuild
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('org.jvnet.hudson.plugins.groovypostbuild.GroovyPostbuildRecorder', 'plugin' => 'groovy-postbuild') do
      groovyScript params[:groovy_script]
      behavior params[:behavior] || '0'
      runFormMatrixParent 'false'
      if params[:additional_classpaths]
        params[:additional_classpaths].each do |path|
          send('org.jvnet.hudson.plugins.groovypostbuild.GroovyScriptPath') do
            path path[:path] || '/'
          end
        end
      end
    end
  end
end

publisher do
  name :archive_artifact
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send('hudson.tasks.ArtifactArchiver') do
      artifacts params[:artifacts]
      excludes params[:excludes] if params[:excludes]
      latestOnly params[:latest_only] || false
      allowEmptyArchive params[:allow_empty] || false

    end
  end
end

publisher do
  name :email_notifications
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    send 'hudson.tasks.Mailer', 'plugin' => 'mailer' do
      recipients params[:recipients] || ''
      send_unstable = false
      send_unstable = true if params[:send_if_unstable] == false
      dontNotifyEveryUnstableBuild send_unstable
      sendToIndividuals params[:send_to_individuals] if params[:send_to_individuals]
    end
  end
end
