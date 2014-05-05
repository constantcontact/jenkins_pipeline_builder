require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::View do
  context "With properly initialized client" do
    before(:all) do
      @creds_file = '~/.jenkins_api_client/login.yml'
      @valid_post_responses = [200, 201, 302]
      begin
        @client = JenkinsApi::Client.new(
            YAML.load_file(File.expand_path(@creds_file, __FILE__))
        )
        @client.logger.level = Logger::DEBUG
        @generator = JenkinsPipelineBuilder::Generator.new(nil, @client)
        @generator.no_files = true
      rescue Exception => e
        puts 'WARNING: Credentials are not set properly.'
        puts e.message
      end
    end

    describe 'InstanceMethods' do
      describe '#create' do
        def create_and_validate(params)
          name = params[:name]
          @valid_post_responses.should include(
            @generator.view.create(params).to_i
          )
          @generator.view.list_children(params[:parent_view], name).include?(name).should be_true
        end

        def destroy_and_validate(params)
          name = params[:name]
          @valid_post_responses.should include(
            @generator.view.delete(name, params[:parent_view]).to_i
          )
          @generator.view.list_children(params[:parent_view], name).include?(name).should be_false
        end

        def test_and_validate(params)
          create_and_validate(params)
          destroy_and_validate(params)
        end

        it 'accepts the name of the view and creates the view' do
          params = {
            :name => 'test_list_view'
          }

          test_and_validate(params)
        end

        it 'creates a Nested view with a child' do
          params_parent = {
            name: 'My Test Parent View',
            type: 'nestedView'
          }

          create_and_validate(params_parent)

          params_child = {
            name: 'Test List View',
            parent_view: params_parent[:name]
          }

          test_and_validate(params_child)

          destroy_and_validate(params_parent)
        end

        it 'creates a categorized view with columns' do
          params = {
            name: 'test_category_view',
            type: 'categorizedView',
            description: 'Blah blah',
            regex: 'Job-.*',
            groupingRules: [{
              groupRegex: 'Step-1.*',
              namingRule: '1. Commit'
            },{
              groupRegex: 'Step-2.*',
              namingRule: '2. Acceptance'
            },{
              groupRegex: 'Step-3.*',
              namingRule: '3. Release'
            }]
          }

          test_and_validate(params)
        end
      end
    end
  end
end
