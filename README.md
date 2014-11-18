jenkins-pipeline-builder
========================

[![Build Status](https://travis-ci.org/constantcontact/jenkins_pipeline_builder.svg)](https://travis-ci.org/constantcontact/jenkins_pipeline_builder)  [![Gem Version](https://badge.fury.io/rb/jenkins_pipeline_builder.svg)](http://badge.fury.io/rb/jenkins_pipeline_builder)

YAML driven CI Jenkins Pipeline Builder enabling to version your artifact pipelines alongside with the artifact source
itself.

This Gem uses this methodolody by itself. Notice the 'pipeline' folder where we have a declaration of the Gem's build
pipeline.

# Background

This project is inspired by a great work done by Arangamani with [jenkins_api_client](https://github.com/arangamani/jenkins_api_client) and
amazing progress done by the Open Stack community with their [jenkins-job-builder](http://ci.openstack.org/jenkins-job-builder/)

The YAML structure very closely resembles the OpenStack Job Builder, but, in comparison to Python version, is 100%
pure Ruby and uses Jenkins API Client and has additional functionlity of building different types of Jenkins views.

# JenkinsPipelineBuilder

USAGE:
------

### Installation

Ruby 2.0 or higher is required.

Add this line to your application's Gemfile:

    gem 'jenkins_pipeline_builder'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jenkins_pipeline_builder

    brew install libxml2 libxslt
    [optional] brew link libxml2 libxslt
    gem install nokogiri

### Authentication

For more info see [jenkins_api_client](https://github.com/arangamani/jenkins_api_client).
Supplying credentials to the client is optional, as not all Jenkins instances
require authentication. This project supports two types of password-based
authentication. You can just you the plain password by using <tt>password</tt>
parameter. If you don't prefer leaving plain passwords in the credentials file,
you can encode your password in base64 format and use <tt>password_base64</tt>
parameter to specify the password either in the arguments or in the credentials
file. To use the client without credentials, just leave out the
<tt>username</tt> and <tt>password</tt> parameters. The <tt>password</tt>
parameter is only required if <tt>username</tt> is specified.

#### Using with Open ID

For more info see [jenkins_api_client](https://github.com/arangamani/jenkins_api_client).
It is very simple to authenticate with your Jenkins server that has Open ID
authentication enabled. You will have to obtain your API token and use the API
token as the password. For obtaining the API token, go to your user configuration
page and click 'Show API Token'. Use this token for the `password` parameter when
initializing the client.

### Basic usage

Create all your Job description files in a folder (Ex.: ./pipeline). Follow the Job/View/Project DSL.
Try to extract the reusable values out of jobs into the project.

Put the right information about the location of your Jenkins server and the appropriate credentials
in a config file (ex: config.login.yml)

Now you ready to bootstrap a pipeline:

    generate pipeline -c config/login.yml bootstrap ./pipeline

NOTE: you can run the pipeline in NOOP (debug-only) mode by addind -d parameter, like:
    generate pipeline -d -c config/login.yml bootstrap ./pipeline

The command comes with fairly extensive help. For example you can list all of the registered extension types with `generate list` and a list of all extensions of a type with `generate list type`

#### JSON now supported
The pipeline builder now suppots json for config and pipeline files instead of or in addition to yaml files

DSL:
----

## Job DSL
Here's a high level overview of what's available:

```yaml
- job:
    name: nameStr # Name of your Job
    job_type: free_style # Optional  [free_style|multi_project|job_dsl|build_flow|pull_request_generator]
    concurrent_build: true or false
    discard_old: # Discard old builds after:
      days: 1 # Optional, number of days after which the build is deleted
      number: 2 # Optional, number of builds after which the build is deleted
      artifact_days: 3 # Optional, number of days after which the artifact is deleted
      artifact_number: 4 # Optional, number of builds after which the artifact is deleted
    throttle: # Optional, throttles concurrent jobs
      max_per_node: int
      max_total: int
      option: category or alone
      category: string # Only used if option == category
    prepare_environment:
        properties_content: string
        keep_environment: true
        keep_build: true
    parameters:
      - name: param_name
        type: string
        default: default value
        description: text
    scm_provider: git # See more info on Jenkins Api Client
    scm_url: git@github.com:your_url_here
    scm_branch: master
    scm_params:
      excluded_users: user
      local_branch: branch_name
      recursive_update: true
      wipe_workspace: true
      skip_tag: true # Optional, defaults to false
      excluded_regions: region
      included_regions: region
    shell_command: '. commit_build.sh'
    inject_env_vars_pre_scm:
      file: '${PARENT_WORKSPACE}/{{shared_job_settings_file}}'
    promoted_builds:
      - 'Stage Promotion'
      - 'Prod Promotion'
    hipchat:
      room: room name here
      start-notify: true
    priority: # Optional
        use_priority: true # true OR false
        job_priority: 1 # Default value is -1
    builders:
      - multi_job:
          phases:
            "Phase One":
              jobs:
                - name: first
                  exposed_scm: true
                  current_params: true
                  config:
                    predefined_build_parameters: |
                      PARAM_NAME_1: PARAM_VALUE_1
                      PARAM_NAME_2: PARAM_VALUE_2
                - name: second
              continue_condition: COMPLETED
            "Phase Two":
              jobs:
                - name: third
      - inject_vars_file: build_job_info
      - shell_command: |
          echo 'Doing some work'
          run command1
      - maven3:
          goals: -B clean
          rootPom: path_to_pom
          mavenName: maven-name # Optional
      - remote_job:
          server: 'Name of Server' # Name of the Remote Jenkins Server
          job_name: name_of_remote_build
          blocking: true # Block current job until remote job finishes
          polling_interval: 10 # Optional, number of seconds between polls, defaults to 10
          continue_on_remote_failure: false
          parameters: # Optional, if both are specified only the file is used
            file: 'foo.prop'
            content: |
              VAR1 = value_1
              VAR2 = value_2
          credentials: # Optional, if you want to override the server credentials
            type: api_token or none
            username: name_of_user
            api_token: APITOKEN
      - blocking_downstream:
          project: nameStr
          data:
            - params: |
                param1
                param2
          trigger_with_no_parameters: false
          # Below is Optional, values can be SUCCESS, FAILURE, UNSTABLE, never
          fail: FAILURE # Fail this build step if the triggered build is worse or equal to
          mark_fail: SUCCESS # Mark this build as failure if the triggered build is worse or equal to
          mark_unstable: UNSTABLE # Mark this build as unstable if the triggered build is worse or equal to
      - copy_artifact:
          project: nameStr # Name of the project
          artifacts: 'artifact.txt' # Selector for artifacts
          target_directory: 'artifacts' # Where the artifacts should go, blank for Workspace root
          filter: 'test=true' # String of filters, PARAM1=VALUE1,PARAM2=VALUE2, Optional
          fingerprint: true # Optional, true or false, defaults to true
          flatten: false # Optional, true or false, defaults to false
          optional: false # Optional, true or false, defaults to false
          selector: # Optional
            type: status # Defaults to status, options: status, saved, triggered, permalink, specific, workspace, parameter
            stable: true # Use if type = 'status', true or false
            fallback: true # Use if type = 'triggered', true or false
            id: lastBuild # Use if type = 'permalink', options: lastBuild, lastStableBuild, lastSuccessfulBuild, lastFailedBuild, lastUnstableBuild, lastUnsucceessfulBuild
            number: '123' # Use if type = 'specific', the number of the build to use
            param: 'BUILD_SELECTOR' # Use if type = 'parameter', the build parameter name
    wrappers:
      - timestamp: true
      - ansicolor: true
      - artifactory:
          url: 'https://url.com/path'
          artifactory-name: 'key'
          release-repo: release
          snapshot-repo: snapshot
          publish: 'pkg/*.gem'
          publish-build-info: true # Optional
          properties: key=value;key2=value2,value2.1
      - maven3artifactory:
          url: https://artifactory.com/artifactory
          artifactory-name: name
          release-repo: release
          snapshot-repo: snapshot
          publish-build-info: true # Optional
      - inject_env_var:
          file: 'foo.prop'
          content: |
            VAR1 = value_1
            VAR2 = value_2
      - inject_passwords:
        - name: pwd_name
          value: some_encrypted_password
      - rvm: "ruby-version@ruby-gemset"
    publishers:
      - junit_result:
          test_results: 'out/**/*.xml'
      - git:
          push-merge: true
          push-only-if-success: false
      - hipchat:
          jenkinsUrl: 'https://jenkins_url/'
          authToken: 'auth_token'
          room: 'room name'
      - coverage_result:
          report_dir: out/coverage/rcov
          total:
            healthy: 80
            unhealthy: 0
            unstable: 0
          code:
            healthy: 80
            unhealthy: 0
            unstable: 0
      - description_setter:
          regexp: See the build details at (.*)
          description: 'Build Details: <a href="\1">\1</a>'
      - downstream:
          project: project_name
          data:
            - params: |
                PARAM1=value1
                PARAM2=value2
            - file: promote-job-params
      - archive_artifact:
          artifacts: 'artifact.txt' #Artifact include string/pattern
          exclude: '' # Optional, exclude string/pattern
          latest_only: false # Optional, true or false, defaults to false
          allow_empty: false # Optional, true or false, defaults to false
      - email_notifications:
          recipients: 'test@example.com' # Whitepace-delimited list of recipients
          send_if_unstable: false # Optional, default to true
          send_to_individuals: true # Optional, default to false
      - sonar_result:
          branch: 'sonar-results-branch-name'
          maven_installation_name: 'name'
    triggers:
      - git_push: true
      - scm_polling: 'H/5 * * * *'
      - periodic_build: 'H/15 * * * *'
      - upstream: # Trigger this build after another build has completed
          projects: project-name-here
          status: failed, unstable, stable # Optional, stable by default
    build_flow: |
      guard {
        build("job_name1", param1: params["param1"]);
      } rescue {
        build("job_name2", param1: build21.environment.get("some_var"))
      }
```

NOTE: The *promoted_builds* plugin is not fully implemented. This plugin just helps you point to the jobs that you have in order to promote your build.
You need to manually create your promotion rules. Using this plugin will help you regenerate your jobs without breaking your manual promotion jobs.

### Pull Request Generator

The pull request generator will generate pipelines for pull requests that are noticed on your repo. It will also remove old pipelines from Jenkins if the pull_request is closed.
If you need to modify job parameters please just specify that in the jobs section like the example below.

When running a project through this module, the project {{name}} is appended with "-PR##" where ## is the number of the pull request.  You can also use {{pull_request_number}} to get just the number of the PR.

```yaml
- job:
    name: '{{name}}-ReqGen'
    job_type: pull_request_generator
    git_url: 'https://www.github.com/'
    git_repo: 'jenkins_pipeline_builder'
    git_org: 'constantcontact'
    jobs:
      - '{{name}}-Job1':
          publishers:
            - downstream:
                project: '{{name}}-Job2'
      - '{{name}}-Job2':
          discard_old:
            number: '100'
      - '{{name}}-Job3'
    builders:
        - shell_command: |
            generate -v || gem install jenkins_pipeline_builder
            generate pipeline pull_request pipeline/ {{name}}
```

### View DSL
```yaml
- view:
    name: 'view name'
    type: 'listview' # Optional: listview [default], myview, nestedView, categorizedView, dashboardView, multijobView
    description: 'description'
    parent_view: 'Parent View Name' # Optional, when you're using tested views
    regex: '.*'
    groupingRules: # Optional, when you are using Categorized view
      - groupRegex: "1.*"
        namingRule: "sub view"
```

### Project DSL
```yaml
- project:
    name: Your project name
    jobs:
      - Job1
      - Job2
          param1: value1
      - JobTemplate1
```

### Default Settings Section

The defaults section mimics behavior of [jenkins-job-builder Defaults](http://ci.openstack.org/jenkins-job-builder/configuration.html#defaults)
If a set of Defaults is specified with the name global, that will be used by all Job (and Job Template) definitions.

```yaml
- defaults:
    name: global
    param1: 'value 1'
```

Extending the Pipeline Builder
------------------------------

Have a feature you want to test out before adding it to the source? Now you can create a quick "extension" to the pipeline builder to add new or overwrite existing functionality.

To add an extension, create an "extensions" directiroy inside of "pipeline" and create a file named "my_extension.rb" (or any name). Then just `require 'jenkins_pipeline_builder/extensions'` and you can begin using the extension DSL. All of the plugins use this DSL and provide an excellent source of examples. You can find them in lib/jenkins_pipeline_builder/extensions.

For help figuring out what category your change is, examine the config.xml for a job that uses your feature. If it is a first child of the root "project" node, your change is a job_attribute. Otherwise it should be either a builder, publisher, wrapper, or trigger, depending what child node it is found in the XML tree.

Here is an example of extending the pipeline builder with a new publisher:

```ruby
publisher do
  name :yaml_name
  plugin_id 123
  min_version '0.4'
  jenkins_name "Jenkins UI Name"
  description "Description of this feature"
  params[:thing, :value]

  xml do |params, xml|
   send("new_element") do
      property params[:value]
      if params[:thing]
        thing 'true'
      end
    end
  end
end
```

You can also declare multiple versions of an extension. Some plugins have breaking xml changes between versions. Simply declare a version block with the minimum required version and then declare your xml, before and after blocks inside that version.

```ruby
publisher do
  name :yaml_name
  plugin_id 123
  min_version '0.4'
  jenkins_name "Jenkins UI Name"
  description "Description of this feature"

  version '0' do
    before do
      # preprocessing here
    end

    after do
      # post processing here
    end

    xml do |params, xml|
     send("new.element") do
        property params[:value]
        if params[:thing]
          thing 'true'
        end
      end
    end
  end

  version '1.0' do
    before do
      # preprocessing here
    end

    after do
      # post processing here
    end

    xml do |params, xml|
     send("different.element") do
        property params[:value]
        if params[:thing]
          thing 'true'
        end
      end
    end
  end
end
```


Finally, you can add the new DSL in your YAML:

```yaml
- job:
    name: 'Example-Job'
    publishers:
      - yaml_name:
          value: 'example'
```

PLUGINS:
--------

A number of the DSL options rely on Jenkins plugins, including:

* ansicolor - "AnsiColor"
* (view) type: 'categorizedView' - "categorized-view"
* hipchat - "HipChat Plugin"
* inject_env_vars - "Environment Injector Plugin"
* priority - "Priority Sorter plugin"
* downstream - "Parameterized Trigger plugin"
* rvm - "Rvm"
* throttle - "Throttle Concurrent Builds Plug-in"
* timestamp - "Timestamper"
* groovy_postbuild - "Groovy Postbuild"

Just about every plugin above can be installed through Jenkins (Manage Jenkins > Manage Plugins > Available)

For a list of all currently supported plugins run `generate list` or `generate list type` to see all of a specific type

CONTRIBUTING:
----------------

If you would like to contribute to this project, just do the following:

1. Fork the repo on Github.
2. Add your features and make commits to your forked repo.
3. Make a pull request to this repo.
4. Review will be done and changes will be requested.
5. Once changes are done or no changes are required, pull request will be merged.
6. The next release will have your changes in it.

Please take a look at the issues page if you want to get started.

FEATURE REQUEST:
----------------

If you use this gem for your project and you think it would be nice to have a
particular feature that is presently not implemented, I would love to hear that
and consider working on it. Just open an issue in Github as a feature request.

