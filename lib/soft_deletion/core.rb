module SoftDeletion
  module Core
    def self.included(base)
      unless base.ancestors.include?(ActiveRecord::Base)
        raise "You can only include this if #{base} extends ActiveRecord::Base"
      end
      base.extend(ClassMethods)

      # backport after_soft_delete so we can safely upgrade to rails 3
      if ActiveRecord::VERSION::MAJOR > 2
        base.define_model_callbacks :soft_delete
        base.define_model_callbacks :soft_undelete
      else
        base.define_callbacks :before_soft_delete
        base.define_callbacks :after_soft_delete

        base.define_callbacks :before_soft_undelete
        base.define_callbacks :after_soft_undelete
      end
    end

    module ClassMethods
      def soft_delete_dependents
        self.reflect_on_all_associations.
          select { |a| [:destroy, :delete_all, :nullify].include?(a.options[:dependent]) }.
          map(&:name)
      end

      def with_deleted
        method = (ActiveRecord::VERSION::MAJOR >= 4 ? :unscoped : :with_exclusive_scope)
        send(method) do
          yield self
        end
      end

      def mark_as_soft_deleted_sql
        ["deleted_at = ?", Time.now]
      end

      def soft_delete_all!(ids_or_models)
        ids_or_models = Array.wrap(ids_or_models)

        if ids_or_models.first.is_a?(ActiveRecord::Base)
          ids = ids_or_models.map(&:id)
          models = ids_or_models
        else
          ids = ids_or_models
          models = if ActiveRecord::VERSION::MAJOR >= 4
            where(:id => ids)
          else
            all(:conditions => { :id => ids })
          end
        end

        transaction do
          if ActiveRecord::VERSION::MAJOR >= 4
            where(:id => ids).update_all(mark_as_soft_deleted_sql)
          else
            update_all(mark_as_soft_deleted_sql, :id => ids)
          end

          models.each do |model|
            model.soft_delete_dependencies.each(&:soft_delete!)
            model.run_callbacks ActiveRecord::VERSION::MAJOR > 2 ? :soft_delete : :after_soft_delete
          end
        end
      end
    end

    def deleted?
      deleted_at.present?
    end

    def mark_as_deleted
      self.deleted_at = Time.now
    end

    def mark_as_undeleted
      self.deleted_at = nil
    end

    def soft_delete!
      _run_soft_delete { save! }
    end

    def soft_delete(*args)
      _run_soft_delete{ save(*args) }
    end

    def soft_undelete!
      _run_soft_undelete{ save! }
    end

    def soft_delete_dependencies
      self.class.soft_delete_dependents.map { |dependent| SoftDeletion::Dependency.new(self, dependent) }
    end

    protected

    def _run_soft_delete(&block)
      self.class.transaction do
        result = false
        if ActiveRecord::VERSION::MAJOR > 2
          run_callbacks :soft_delete do
            mark_as_deleted
            soft_delete_dependencies.each(&:soft_delete!)
            result = block.call
          end
        else
          return false if !run_callbacks(:before_soft_delete) { |result, object| result == false }
          mark_as_deleted
          soft_delete_dependencies.each(&:soft_delete!)
          result = block.call
          run_callbacks :after_soft_delete
        end
        result
      end
    end

    def _run_soft_undelete(&block)
      self.class.transaction do
        result = false
        if ActiveRecord::VERSION::MAJOR > 2
          run_callbacks :soft_undelete do
            mark_as_undeleted
            soft_delete_dependencies.each(&:soft_undelete!)
            result = block.call
          end
        else
          return false if !run_callbacks(:before_soft_undelete) { |result, object| result == false }
          mark_as_undeleted
          soft_delete_dependencies.each(&:soft_undelete!)
          result = block.call
          run_callbacks :after_soft_undelete
        end
        result
      end
    end
  end
end
