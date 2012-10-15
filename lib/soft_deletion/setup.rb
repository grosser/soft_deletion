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
        default_options = {:default_scope => false}

        include SoftDeletion::Core

        options = default_options.merge(options)

        if options[:default_scope] && table_exists? && column_names.include?("deleted_at")
          # Avoids a bad SQL request with versions of code without the column deleted_at (for example a migration prior to the migration
          # that adds deleted_at)
          default_scope :conditions => { :deleted_at => nil }
        end
      end
    end
  end
end
