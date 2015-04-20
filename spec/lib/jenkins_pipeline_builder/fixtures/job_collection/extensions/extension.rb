publisher do
  name :my_test_thing
  plugin_id 'test-thing'
  description 'test plugin'
  jenkins_name 'test plugin'

  xml do |helper|
    stuff 'asdf'
    thing(helper.cool_method)
  end
end
