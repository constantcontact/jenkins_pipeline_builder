jenkins-pipeline-builder
========================

[![Build Status](https://travis-ci.org/constantcontact/jenkins_pipeline_builder.svg)](https://travis-ci.org/constantcontact/jenkins_pipeline_builder)  [![Gem Version](https://badge.fury.io/rb/jenkins_pipeline_builder.svg)](http://badge.fury.io/rb/jenkins_pipeline_builder)

YAML/JSON driven jenkins job generator that lets you version your artifact pipelines alongside with the artifact source itself.

# Background

This project is inspired by the great work done by Arangamani with [jenkins_api_client](https://github.com/arangamani/jenkins_api_client) and amazing progress done by the Open Stack community with their [jenkins-job-builder](http://ci.openstack.org/jenkins-job-builder/)

The YAML structure began very closely resembling the OpenStack Job Builder, but, has evolved since then. Under the covers it uses the Jenkins API Client and is very extensible. Any plugin that is not currently supported can be added locally.

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
authentication. You can just use the plain password by using <tt>password</tt>
parameter. If you don't want to leave plain passwords in the credentials file,
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

Create all your Job description files in a folder (e.g.: ./pipeline). Follow the Job/View/Project DSL.
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

Please see the [DSL Wiki Page](https://github.com/constantcontact/jenkins_pipeline_builder/wiki/DSL)

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

