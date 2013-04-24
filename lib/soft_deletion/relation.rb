# for ActiveRecord 3.2
module SoftDeletion
  module Relation
    def with_deleted
      new_scope = scoped.with_default_scope
      new_scope.where_values.delete_if {|where| where.left.name.to_s == 'deleted_at' && where.right.nil?}
      new_scope
    end

    def only_deleted
      new_scope = scoped.with_deleted
      new_scope.where('deleted_at IS NOT NULL')
    end

    ################
    # Copy-n-pasted from FriendlyId/friendly_id/lib/friendly_id/base.rb
    ################
    module Base
      def self.extended(base)
        class << base
          alias relation_without_soft_deletion relation
        end
        base.extend(SoftDeletion::Relation::Base::ClassMethods)
      end

      module ClassMethods
        private
        #
        # Gets an instance of an the relation class.
        #
        # With FriendlyId this will be a subclass of ActiveRecord::Relation, rather than
        # Relation itself, in order to avoid tainting all Active Record models with
        # FriendlyId.
        #
        # Note that this method is essentially copied and pasted from Rails 3.2.9.rc1,
        # with the exception of changing the relation class. Obviously this is less than
        # ideal, but I know of no better way to accomplish this.
        # @see #relation_class
        def relation #:nodoc:
          relation = relation_class.new(self, arel_table)

          if finder_needs_type_condition?
            relation.where(type_condition).create_with(inheritance_column.to_sym => sti_name)
          else
            relation
          end
        end

        # Gets (and if necessary, creates) a subclass of the model's relation class.
        #
        # Rather than including FriendlyId's overridden finder methods in
        # ActiveRecord::Relation directly, FriendlyId adds them to a subclass
        # specific to the AR model, and makes #relation return an instance of this
        # class. By doing this, we ensure that only models that specifically extend
        # FriendlyId have their finder methods overridden.
        #
        # Note that this method does not directly subclass ActiveRecord::Relation,
        # but rather whatever class the @relation class instance variable is an
        # instance of. In practice, this will almost always end up being
        # ActiveRecord::Relation, but in case another plugin is using this same
        # pattern to extend a model's finder functionality, FriendlyId will not
        # replace it, but rather override it.
        #
        # This pattern can be seen as a poor man's "refinement"
        # (http://timelessrepo.com/refinements-in-ruby), and while I **think** it
        # will work quite well, I realize that it could cause unexpected issues,
        # since the authors of Rails are probably not intending this kind of usage
        # against a private API. If this ends up being problematic I will probably
        # revert back to the old behavior of simply extending
        # ActiveRecord::Relation.
        def relation_class
          @relation_class or begin
            @relation_class = Class.new(relation_without_soft_deletion.class) do
              include SoftDeletion::Relation
            end
            # Set a name so that model instances can be marshalled. Use a
            # ridiculously long name that will not conflict with anything.
            # TODO: just use the constant, no need for the @relation_class variable.
            const_set('SoftDeletionActiveRecordRelation', @relation_class)
          end
        end
      end
    end
  end
end