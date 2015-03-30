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
  class View
    # Initializes a new View object.
    #
    # @param generator [Generator] the client object
    #
    # @return [View] the view object
    #
    def initialize(generator)
      @generator = generator
      @client = generator.client
      @logger = @client.logger
    end

    def generate(path)
      if path.end_with? 'json'
        hash = JSON.parse(IO.read(path))
      else
        hash = YAML.load_file(path)
      end

      hash.each do |item|
        Utils.symbolize_keys_deep!(item)
        create(item[:view]) if item[:view]
      end
    end

    # Creates a listview by accepting the given parameters hash
    #
    # @param [Hash] params options to create the new view
    # @option params [String] :name Name of the view
    # @option params [String] :type Description of the view
    # @option params [String] :description Description of the view
    # @option params [String] :status_filter Filter jobs based on the status.
    #         Valid options: all_selected_jobs, enabled_jobs_only,
    #         disabled_jobs_only. Default: all_selected_jobs
    # @option params [Boolean] :filter_queue true or false
    # @option params [Boolean] :filter_executors true or false
    # @option params [String] :regex Regular expression to filter jobs that
    #         are to be added to the view
    #
    # @raise [ArgumentError] if the required parameter +:name+ is not
    #   specified
    #
    def create(params)
      # Name is a required parameter. Raise an error if not specified
      fail ArgumentError, 'Name is required for creating view' unless params.is_a?(Hash) && params[:name]
      clean_up_views(params) unless JenkinsPipelineBuilder.debug
      params[:type] ||= 'listview'
      create_base_view(params[:name], params[:type], params[:parent_view])
      @logger.debug "Creating a #{params[:type]} view with params: #{params.inspect}"

      if JenkinsPipelineBuilder.debug
        # pp post_params(params)
        return
      end

      view_path = params[:parent_view].nil? ? '' : "/view/#{params[:parent_view]}"
      view_path += "/view/#{params[:name]}/configSubmit"

      @client.api_post_request(view_path, post_params(params))
    end

    private

    def clean_up_views(params)
      # If we have a parent view, we need to do some additional checks
      if params[:parent_view]
        create_base_view(params[:parent_view], 'nestedView') unless exists?(params[:parent_view])
        delete(params[:name], params[:parent_view]) if exists?(params[:name], params[:parent_view])
      else
        delete(params[:name]) if exists?(params[:name])
      end
    end

    def post_params(params)
      statuses = { 'enabled_jobs_only' => '1', 'disabled_jobs_only' => '2' }

      json = {
        'name' => params[:name],
        'description' => params[:description],
        'mode' => get_mode(params[:type]),
        'statusFilter' => '',
        'columns' => get_columns(params[:type])
      }
      json.merge!('groupingRules' => params[:groupingRules]) if params[:groupingRules]
      payload = {
        'name' => params[:name],
        'mode' => get_mode(params[:type]),
        'description' => params[:description],
        'statusFilter' => statuses.fetch(params[:status_filter], ''),
        'json' => json.to_json
      }
      payload.merge!('filterQueue' => 'on') if params[:filter_queue]
      payload.merge!('filterExecutors' => 'on') if params[:filter_executors]
      payload.merge!('useincluderegex' => 'on', 'includeRegex' => params[:regex]) if params[:regex]
      payload
    end

    def get_mode(type)
      case type
      when 'listview'
        'hudson.model.ListView'
      when 'myview'
        'hudson.model.MyView'
      when 'nestedView'
        'hudson.plugins.nested_view.NestedView'
      when 'categorizedView'
        'org.jenkinsci.plugins.categorizedview.CategorizedJobsView'
      when 'dashboardView'
        'hudson.plugins.view.dashboard.Dashboard'
      when 'multijobView'
        'com.tikal.jenkins.plugins.multijob.views.MultiJobView'
      else
        fail "Type #{type} is not supported by Jenkins."
      end
    end

    # Creates a new empty view of the given type
    #
    # @param [String] view_name Name of the view to be created
    # @param [String] type Type of view to be created. Valid options:
    # listview, myview. Default: listview
    #
    def create_base_view(view_name, type = 'listview', parent_view_name = nil)
      @logger.info "Creating a view '#{view_name}' of type '#{type}'"
      mode = get_mode(type)
      initial_post_params = {
        'name' => view_name,
        'mode' => mode,
        'json' => {
          'name' => view_name,
          'mode' => mode
        }.to_json
      }

      if JenkinsPipelineBuilder.debug
        # pp initial_post_params
        return
      end

      view_path = parent_view_name.nil? ? '' : "/view/#{parent_view_name}"
      view_path += '/createView'

      @client.api_post_request(view_path, initial_post_params)
    end

    def get_columns(type)
      column_names = ['Status', 'Weather', 'Last Success', 'Last Failure', 'Last Duration', 'Build Button']
      if type == 'categorizedView'
        column_names.insert(2, 'Categorized - Job')
      else
        column_names.insert(2, 'Name')
      end

      result = []
      column_names.each do |name|
        result << columns_repository[name]
      end
      result
    end

    def columns_repository
      {
        'Status' => { 'stapler-class' => 'hudson.views.StatusColumn', 'kind' => 'hudson.views.StatusColumn' },
        'Weather' => { 'stapler-class' => 'hudson.views.WeatherColumn', 'kind' => 'hudson.views.WeatherColumn' },
        'Name' => { 'stapler-class' => 'hudson.views.JobColumn', 'kind' => 'hudson.views.JobColumn' },
        'Last Success' => { 'stapler-class' => 'hudson.views.LastSuccessColumn',
                            'kind' => 'hudson.views.LastSuccessColumn' },
        'Last Failure' => { 'stapler-class' => 'hudson.views.LastFailureColumn',
                            'kind' => 'hudson.views.LastFailureColumn' },
        'Last Duration' => { 'stapler-class' => 'hudson.views.LastDurationColumn',
                             'kind' => 'hudson.views.LastDurationColumn' },
        'Build Button' => { 'stapler-class' => 'hudson.views.BuildButtonColumn',
                            'kind' => 'hudson.views.BuildButtonColumn' },
        'Categorized - Job' => { 'stapler-class' => 'org.jenkinsci.plugins.categorizedview.IndentedJobColumn',
                                 'kind' => 'org.jenkinsci.plugins.categorizedview.IndentedJobColumn' }
      }
    end

    # This method lists all views
    #
    # @param [String] parent_view a name of the parent view
    # @param [String] filter a regex to filter view names
    # @param [Bool] ignorecase whether to be case sensitive or not
    #
    def list_children(parent_view = nil, filter = '', ignorecase = true)
      @logger.info "Obtaining children views of parent #{parent_view} based on filter '#{filter}'"
      view_names = []
      path = parent_view.nil? ? '' : "/view/#{parent_view}"
      response_json = @client.api_get_request(path)
      response_json['views'].each do |view|
        if ignorecase
          view_names << view['name'] if view['name'] =~ /#{filter}/i
        else
          view_names << view['name'] if view['name'] =~ /#{filter}/
        end
      end
      view_names
    end

    # Delete a view
    #
    # @param [String] view_name
    #
    def delete(view_name, parent_view = nil)
      @logger.info "Deleting view '#{view_name}'"
      path = parent_view.nil? ? '' : "/view/#{parent_view}"
      path += "/view/#{view_name}/doDelete"
      @client.api_post_request(path)
    end
    # Checks if the given view exists in Jenkins
    #
    # @param [String] view_name
    #
    def exists?(view_name, parent_view = nil)
      if parent_view
        list_children(parent_view, view_name).include?(view_name)
      else
        @client.view.list(view_name).include?(view_name)
      end
    end
  end
end
