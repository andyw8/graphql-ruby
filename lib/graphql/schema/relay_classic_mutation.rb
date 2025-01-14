# frozen_string_literal: true

module GraphQL
  class Schema
    # Mutations that extend this base class get some conventions added for free:
    #
    # - An argument called `clientMutationId` is _always_ added, but it's not passed
    #   to the resolve method. The value is re-inserted to the response. (It's for
    #   client libraries to manage optimistic updates.)
    # - The returned object type always has a field called `clientMutationId` to support that.
    # - The mutation accepts one argument called `input`, `argument`s defined in the mutation
    #   class are added to that input object, which is generated by the mutation.
    #
    # These conventions were first specified by Relay Classic, but they come in handy:
    #
    # - `clientMutationId` supports optimistic updates and cache rollbacks on the client
    # - using a single `input:` argument makes it easy to post whole JSON objects to the mutation
    #   using one GraphQL variable (`$input`) instead of making a separate variable for each argument.
    #
    # @see {GraphQL::Schema::Mutation} for an example, it's basically the same.
    #
    class RelayClassicMutation < GraphQL::Schema::Mutation
      include GraphQL::Schema::HasSingleInputArgument

      argument :client_mutation_id, String, "A unique identifier for the client performing the mutation.", required: false

      # The payload should always include this field
      field(:client_mutation_id, String, "A unique identifier for the client performing the mutation.")
      # Relay classic default:
      null(true)

      # Override {GraphQL::Schema::Resolver#resolve_with_support} to
      # delete `client_mutation_id` from the kwargs.
      def resolve_with_support(**inputs)
        input = inputs[:input].to_kwargs

        if input
          # This is handled by Relay::Mutation::Resolve, a bit hacky, but here we are.
          input_kwargs = input.to_h
          client_mutation_id = input_kwargs.delete(:client_mutation_id)
          inputs[:input] = input_kwargs
        end

        return_value = super(**inputs)

        context.query.after_lazy(return_value) do |return_hash|
          # It might be an error
          if return_hash.is_a?(Hash)
            return_hash[:client_mutation_id] = client_mutation_id
          end
          return_hash
        end
      end
    end
  end
end
