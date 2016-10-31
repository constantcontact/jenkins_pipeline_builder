class ExtensionHelper < SimpleDelegator
  attr_reader :params, :builder
  def initialize(extension, params, builder, defaults = {})
    # TODO: We should allow for default values to be passed in here
    # That will allow for defaults to be pulled out of the extension and it
    # will also let better enable overriding of those values that do not have
    # an option to do so currently.
    @params = if params.is_a? Hash
                defaults.merge params
              else
                params
              end
    @builder = builder
    @extension = extension

    @extension.parameters.try(:each) do |method_name|
      define_singleton_method(method_name) { self[method_name] }
    end

    super @params
  end

  # TODO: Method missing that pulls out of params?
  # That would allow everything to just call helper.foo
  # and then the helper can do any fiddling it needs to (or not)
end
