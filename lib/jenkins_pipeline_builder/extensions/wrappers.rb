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

wrapper do
  name :ansicolor
  plugin_id 'ansicolor'
  announced false
  jenkins_name 'Color ANSI Console Output'
  description 'This plugin adds support for ANSI escape sequences, including color, to Console Output.'
  xml do |_|
    send('hudson.plugins.ansicolor.AnsiColorBuildWrapper') do
      colorMapName 'xterm'
    end
  end
end

wrapper do
  name :timestamp
  plugin_id 'timestamper'
  description 'Adds timestamps to the Console Output.'
  jenkins_name 'Add timestamps to the Console Output'
  announced false

  xml do |_|
    send('hudson.plugins.timestamper.TimestamperBuildWrapper', 'plugin' => 'timestamper')
  end
end

wrapper do
  name :rvm
  plugin_id 'rvm'
  description 'This plugin runs your jobs in the RVM managed ruby+gemset of your choice.'
  jenkins_name 'Run the build in a RVM-managed environment'
  announced false
  description 'rvm plugin'

  version '0.5' do
    xml do |wrapper|
      send('ruby-proxy-object') do
        send('ruby-object', 'ruby-class' => 'Jenkins::Tasks::BuildWrapperProxy', 'pluginid' => 'rvm') do
          object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') do
            impl('pluginid' => 'rvm', 'ruby-class' => 'String') { text wrapper }
          end
          pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { text 'rvm' }
        end
      end
    end
  end

  version '0' do
    xml do |wrapper|
      send('ruby-proxy-object') do
        send('ruby-object', 'ruby-class' => 'Jenkins::Plugin::Proxies::BuildWrapper', 'pluginid' => 'rvm') do
          object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') do
            impl('pluginid' => 'rvm', 'ruby-class' => 'String') do
              text wrapper
            end
          end
          pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { text 'rvm' }
        end
      end
    end
  end
end

wrapper do
  name :inject_passwords
  plugin_id 'envinject'
  description 'This plugin makes it possible to have an isolated environment for your jobs.'
  jenkins_name 'Inject passwords to the build as environment variables'
  announced false

  xml do |wrapper|
    EnvInjectPasswordWrapper do
      if wrapper.respond_to? :keys
        injectGlobalPasswords wrapper[:inject_global_passwords]
        passwords = wrapper[:passwords]
      else
        passwords = wrapper
      end
      break unless passwords

      passwordEntries do
        passwords.each do |password|
          EnvInjectPasswordEntry do
            name password[:name]
            value password[:value]
          end
        end
      end
    end
  end
end

wrapper do
  name :inject_env_var
  plugin_id 'envinject'
  description 'This plugin makes it possible to have an isolated environment for your jobs.'
  jenkins_name 'Inject environment variables to the build process'
  announced false

  xml do |params|
    EnvInjectBuildWrapper do
      info do
        propertiesFilePath params[:file] if params[:file]
        propertiesContent params[:content] if params[:content]
        loadFilesFromMaster false
      end
    end
  end
end

wrapper do
  name :artifactory
  plugin_id 'artifactory'
  description 'This plugin allows deploying Maven 2, Maven 3, Ivy and Gradle artifacts and build info to the Artifactory artifacts manager.'
  jenkins_name 'Generic-Artifactory Integration'
  announced false

  xml do |wrapper|
    send('org.jfrog.hudson.generic.ArtifactoryGenericConfigurator') do
      details do
        artifactoryUrl wrapper[:url]
        artifactoryName wrapper[:'artifactory-name']
        repositoryKey wrapper[:'release-repo']
        snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
      end
      deployPattern wrapper[:publish]
      resolvePattern
      matrixParams wrapper[:properties]
      deployBuildInfo wrapper[:'publish-build-info']
      useSpecs false
      includeEnvVars false
      envVarsPatterns do
        includePatterns
        excludePatterns '*password*,*secret*'
      end
      discardOldBuilds false
      discardBuildArtifacts true
    end
  end
end

wrapper do
  name :maven3artifactory
  plugin_id 'maven-plugin'
  description 'Jenkins plugin for building Maven 2/3 jobs via a special project type.'
  jenkins_name 'Maven3-Artifactory Integration'
  announced false

  xml do |wrapper|
    send('org.jfrog.hudson.maven3.ArtifactoryMaven3Configurator') do # plugin='artifactory@2.2.1'
      details do
        artifactoryUrl wrapper[:url]
        artifactoryName wrapper[:'artifactory-name']
        repositoryKey wrapper[:'release-repo']
        snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
      end
      deployArtifacts wrapper.fetch(:deploy, true)
      artifactDeploymentPatterns do
        includePatterns
        excludePatterns
      end
      includeEnvVars false
      deployBuildInfo wrapper.fetch(:'publish-build-info', true)
      envVarsPatterns do
        includePatterns
        excludePatterns '*password*,*secret*'
      end
      runChecks false
      violationRecipients
      includePublishArtifacts false
      scopes
      licenseAutoDiscovery true
      disableLicenseAutoDiscovery false
      discardOldBuilds false
      discardBuildArtifacts true
      matrixParams
      enableIssueTrackerIntegration false
      aggregateBuildIssues false
      blackDuckRunChecks false
      blackDuckAppName
      blackDuckAppVersion
      blackDuckReportRecipients
      blackDuckScopes
      blackDuckIncludePublishedArtifacts false
      autoCreateMissingComponentRequests true
      autoDiscardStaleComponentRequests true
      filterExcludedArtifactsFromBuild false
    end
  end
end

wrapper do
  name :nodejs
  plugin_id 'nodejs'
  description 'Provides Jenkins integration for NodeJS & npm packages.'
  jenkins_name 'Node Plugin'
  announced false

  xml do |wrapper|
    send('jenkins.plugins.nodejs.tools.NpmPackagesBuildWrapper') do
      nodeJSInstallationName wrapper[:node_installation_name]
    end
  end
end

wrapper do
  name :xvfb
  plugin_id 'xvfb'
  description 'Setup Xvfb display for Selenium with Firefox.'
  jenkins_name 'Xvfb'
  announced false

  xml do |params|
    send('org.jenkinsci.plugins.xvfb.XvfbBuildWrapper') do
      installationName 'Default'
      screen '1024x768x24'
      debug false
      self.timeout params[:timeout] || 10 # rubocop:disable Style/RedundantSelf
      displayNameOffset 1
      additionalOptions
      shutdownWithBuild false
      autoDisplayName false
    end
  end
end

wrapper do
  name :prebuild_cleanup
  plugin_id 'ws-cleanup'
  description 'Deletes workspace before build starts.'
  jenkins_name 'Delete workspace before build starts'
  announced false

  xml do |_|
    send('hudson.plugins.ws__cleanup.PreBuildCleanup', 'plugin' => 'ws-cleanup')
  end
end

wrapper do
  name :build_timeout
  plugin_id 'build-timeout'
  description 'Abort the build if it\'s stuck'
  jenkins_name 'Abort the build if it\'s stuck'
  announced false

  xml do |wrapper|
    send('hudson.plugins.build__timeout.BuildTimeoutWrapper', 'plugin' => 'build-timeout@1.18') do
      if wrapper[:timeout_strategy] == 'Absolute'
        strategy 'class' => 'hudson.plugins.build_timeout.impl.AbsoluteTimeOutStrategy' do
          timeoutMinutes wrapper[:timeout_minutes]
        end
      elsif wrapper[:timeout_strategy] == 'Deadline'
        strategy 'class' => 'hudson.plugins.build_timeout.impl.DeadlineTimeOutStrategy' do
          deadlineTime wrapper[:deadline_time]
          deadlineToleranceInMinutes wrapper[:deadline_tolerance]
        end
      elsif wrapper[:timeout_strategy] == 'Elastic'
        strategy 'class' => 'hudson.plugins.build_timeout.impl.ElasticTimeOutStrategy' do
          timeoutPercentage wrapper[:timeout_percentage]
          numberOfBuilds wrapper[:number_of_builds]
          failSafeTimeoutDuration wrapper[:fail_safe_timeout]
          timeoutMinutesElasticDefault wrapper[:timeout_minutes]
        end
      elsif wrapper[:timeout_strategy] == 'Likely stuck'
        strategy 'class' => 'hudson.plugins.build_timeout.impl.LikelyStuckTimeOutStrategy'
      elsif wrapper[:timeout_strategy] == 'No Activity'
        strategy 'class' => 'hudson.plugins.build_timeout.impl.NoActivityTimeOutStrategy' do
          timeoutSecondsString wrapper[:timeout_seconds]
        end
      end
      timeoutEnvVar wrapper[:timeout_env_var] unless wrapper[:timeout_env_var].nil?
      if wrapper[:operation] == 'Abort'
        operationList do
          send('hudson.plugins.build__timeout.operations.AbortOperation')
        end
      elsif wrapper[:operation] == 'Fail'
        operationList do
          send('hudson.plugins.build__timeout.operations.FailOperation')
        end
      elsif wrapper[:operation] == 'Writing'
        operationList do
          send('hudson.plugins.build__timeout.operations.WriteDescriptionOperation') do
            description wrapper[:description]
          end
        end
      else operationList
      end
    end
  end
end
