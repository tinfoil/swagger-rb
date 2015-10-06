module Swagger
  # Represents a Swagger Schema Object, a more deterministic subset of JSON Schema.
  # @see https://github.com/wordnik/swagger-spec/blob/master/versions/2.0.md#schema-object- Schema Object
  # @see http://json-schema.org/ JSON Schema
  class Schema < Hashie::Mash
    include Attachable
    include Hashie::Extensions::MergeInitializer
    include Hashie::Extensions::DeepFind
    attr_accessor :parent

    def initialize(hash, default = nil)
      super
      attach_to_children
    end

    def parse
      schema = clone
      if schema.key?('$ref')
        model = model_from_reference(schema.delete('$ref'))
        schema.merge!(model)
      end

      schema.resolve_all_refs(schema)

      schema
    end

    protected

    def refs
      deep_find_all('$ref')
    end

    def resolve_all_refs(schema)
      count = 0
      until schema.refs_resolved?
        fail 'Could not resolve non-remote $refs 5 cycles - circular references?' if count >= 5
        schema.resolve_refs
        count += 1
      end
    end

    def resolve_refs
      items_and_props = [deep_select('items'), deep_select('properties').map(&:values)].flatten.compact
      items_and_props.each do |schema|
        next unless schema.key?('$ref')

        model = model_from_reference(schema.delete('$ref'))
        schema.merge!(model)
      end
    end

    def refs_resolved?
      return true if refs.nil?
      refs.all? do |ref|
        remote_ref?(ref)
      end
    end

    def model_from_reference(ref)
      fail "Remote references are not yet supported: #{ref}" if remote_ref?(ref)

      key = ref.split('/').last
      root.definitions[key]
    end

    def remote_ref?(ref)
      ref.match(%r{\A\w+\://})
    end
  end
end
