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

        if options[:default_scope]
          conditions = {:deleted_at => nil}
          if ActiveRecord::VERSION::STRING < "3.1"
            # Avoids a bad SQL request with versions of code without the column deleted_at
            # (for example a migration prior to the migration that adds deleted_at)
            if !table_exists?
              warn "#{table_name} table missing, disabling soft_deletion default scope"
            elsif !column_names.include?("deleted_at")
              warn "#{table_name} does not have deleted_at column, disabling soft_deletion default scope"
            else
              default_scope :conditions => conditions
            end
          else
            default_scope { where(conditions) }
          end
        end
      end
    end
  end
end
