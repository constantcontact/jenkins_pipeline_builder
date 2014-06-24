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
  class Builders
    def self.build_multijob(params, xml)
      params[:phases].each do |name, content|
        xml.send('com.tikal.jenkins.plugins.multijob.MultiJobBuilder') do
          xml.phaseName name
          xml.phaseJobs do
            content[:jobs].each do |job|
              xml.send('com.tikal.jenkins.plugins.multijob.PhaseJobsConfig') do
                xml.jobName job[:name]
                xml.currParams job[:current_params] || false
                xml.exposedSCM job[:exposed_scm] || false
                if job[:config]
                  xml.configs do
                    if job[:config].key? :predefined_build_parameters
                      xml.send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') do
                        xml.properties job[:config][:predefined_build_parameters].join "\n"
                      end
                    end
                  end
                end
              end
            end
          end
          xml.continuationCondition content[:continue_condition] || 'SUCCESSFUL'
        end
      end
    end

    def self.build_maven3(params, xml)
      xml.send('org.jfrog.hudson.maven3.Maven3Builder') do
        xml.mavenName params[:mavenName] || 'tools-maven-3.0.3'
        xml.rootPom params[:rootPom]
        xml.goals params[:goals]
        xml.mavenOpts params[:options]
      end
    end

    def self.build_shell_command(param, xml)
      xml.send('hudson.tasks.Shell') do
        xml.command param
      end
    end

    def self.build_environment_vars_injector(params, xml)
      xml.EnvInjectBuilder do
        xml.info do
          xml.propertiesFilePath params
        end
      end
    end

    def self.blocking_downstream(params, xml)
      colors = { 'SUCCESS' => { ordinal:  0, color:  'BLUE' }, 'FAILURE' => { ordinal:  2, color:  'RED' }, 'UNSTABLE' => { ordinal:  1, color:  'YELLOW' } }
      xml.send('hudson.plugins.parameterizedtrigger.TriggerBuilder', 'plugin' => 'parameterized-trigger') do
        xml.configs do
          xml.send('hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig') do

            xml.configs do
              params[:data] = [{ params: '' }] unless params[:data]
              params[:data].each do |config|
                if config[:params]
                  xml.send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') do
                    xml.properties config[:params]
                  end
                end
                if config[:file]
                  xml.send('hudson.plugins.parameterizedtrigger.FileBuildParameters') do
                    xml.propertiesFile config[:file]
                    xml.failTriggerOnMissing false
                  end
                end
              end
            end
            xml.projects params[:project]
            xml.condition params[:condition] || 'SUCCESS'
            xml.triggerWithNoParameters params[:trigger_with_no_parameters] || false
            xml.block do
              if params[:fail] && colors.include?(params[:fail])
                xml.buildStepFailureThreshold do
                  xml.name params[:fail]
                  xml.ordinal colors[params[:fail]][:ordinal]
                  xml.color colors[params[:fail]][:color]
                  xml.completeBuild 'true'
                end
              end
              if params[:mark_fail] && colors.include?(params[:mark_fail])
                xml.failureThreshold do
                  xml.name params[:mark_fail]
                  xml.ordinal colors[params[:mark_fail]][:ordinal]
                  xml.color colors[params[:mark_fail]][:color]
                  xml.completeBuild 'true'
                end
              end
              if params[:mark_unstable] && colors.include?(params[:mark_unstable])
                xml.unstableThreshold do
                  xml.name params[:mark_unstable]
                  xml.ordinal colors[params[:mark_unstable]][:ordinal]
                  xml.color colors[params[:mark_unstable]][:color]
                  xml.completeBuild 'true'
                end
              end
            end
            xml.buildAllNodesWithLabel false
          end
        end
      end
    end

    def self.start_remote_job(params, xml)
      parameters = params[:parameters][:content].split("\n") if params[:parameters] && params[:parameters][:content]
      xml.send('org.jenkinsci.plugins.ParameterizedRemoteTrigger.RemoteBuildConfiguration', 'plugin' => 'Parameterized-Remote-Trigger') do
        xml.remoteJenkinsName params[:server]
        xml.job params[:job_name]
        xml.shouldNotFailBuild params[:continue_on_remote_failure] if params[:continue_on_remote_failure]
        xml.pollInterval params[:polling_interval] if params[:polling_interval]
        xml.blockBuildUntilComplete params[:blocking] if params[:blocking]
        xml.token
        if params[:parameters] && params[:parameters][:content]
          xml.parameters parameters.join("\n")
          xml.parameterList do
            parameters.each do |p|
              xml.string p
            end
          end
        elsif params[:parameters] && params[:parameters][:file]
          xml.loadParamsFromFile 'true'
          xml.parameterFile params[:parameters][:file]
        else
          xml.parameters
          xml.parameterList do
            xml.string
          end
        end
        if params[:credentials] && params[:credentials][:type]
          xml.overrideAuth 'true'
          xml.auth do
            xml.send('org.jenkinsci.plugins.ParameterizedRemoteTrigger.Auth') do
              if params[:credentials][:type] == 'api_token'
                xml.authType 'apiToken'
                xml.username params[:credentials][:username]
                xml.API__TOKEN params[:credentials][:api_token]
              else
                xml.authType 'none'
              end
            end
          end
        end
      end
    end

    def self.build_copy_artifact(params, xml)
      xml.send('hudson.plugins.copyartifact.CopyArtifact', 'plugin' => 'copyartifact') do
        xml.project params[:project]
        xml.filter params[:artifacts]
        xml.target params[:target_directory]
        xml.parameters params[:filter] if params[:filter]
        if params[:selector] && params[:selector][:type]
          case params[:selector][:type]
          when 'saved'
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.SavedBuildSelector')
          when 'triggered'
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.TriggeredBuildSelector') do
              xml.fallbackToLastSuccessful params[:selector][:fallback] if params[:selector][:fallback]
            end
          when 'permalink'
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.PermalinkBuildSelector') do
              xml.id params[:selector][:id] if params[:selector][:id]
            end
          when 'specific'
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.SpecificBuildSelector') do
              xml.buildNumber params[:selector][:number] if params[:selector][:number]
            end
          when 'workspace'
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.WorkspaceSelector')
          when 'parameter'
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.ParameterizedBuildSelector') do
              xml.parameterName params[:selector][:param] if params[:selector][:param]
            end
          else
            xml.send('selector', 'class' => 'hudson.plugins.copyartifact.StatusBuildSelector') do
              xml.stable params[:selector][:stable] if params[:selector][:stable]
            end
          end
        else
          xml.send('selector', 'class' => 'hudson.plugins.copyartifact.StatusBuildSelector')
        end
        if params[:fingerprint].nil?
          xml.doNotFingerprintArtifacts false
        else
          if params[:fingerprint].to_s == 'true'
            xml.doNotFingerprintArtifacts false
          else
            xml.doNotFingerprintArtifacts true
          end
        end
        xml.flatten true if params[:flatten]
        xml.optional true if params[:optional]
      end
    end
  end
end
