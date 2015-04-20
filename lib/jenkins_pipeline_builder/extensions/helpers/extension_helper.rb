class ExtensionHelper < SimpleDelegator
  attr_reader :params, :builder
  def initialize(params, builder)
    # TODO: We should allow for default values to be passed in here
    # That will allow for defaults to be pulled out of the extension and it
    # will also let better enable overriding of those values that do not have
    # an option to do so currently.
    @params = params
    @builder = builder
    super @params
  end

  # TODO: Method missing that pulls out of params?
  # That would allow everything to just call helper.foo
  # and then the helper can do any fiddling it needs to (or not)
end
