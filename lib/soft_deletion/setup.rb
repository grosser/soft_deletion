module SoftDeletion
  module Setup

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # When you call this, it will include the core module and its methods
      #
      # Options:
      #
      # *default_scope*, value: true/false
      # If true, it will also define a default scope
      #
      # It will check if the column "deleted_at" exist before applying default scope
      def has_soft_deletion(options={})
        include SoftDeletion::Core

        if options[:default_scope]
          self.soft_delete_default_scope = name
          default_scope do
            if Thread.current[:"soft_deletion_with_deleted_#{soft_delete_default_scope}"]
              where(nil)
            else
              where(deleted_at: nil)
            end
          end
        end
      end
    end
  end
end
