module SoftDeletion
  module Core
    def self.included(base)
      unless base.ancestors.include?(ActiveRecord::Base)
        raise "You can only include this if #{base} extends ActiveRecord::Base"
      end
      base.extend(ClassMethods)

      base.define_model_callbacks :soft_delete
      base.define_model_callbacks :soft_undelete
      base.cattr_accessor :soft_delete_default_scope
    end

    module ClassMethods
      def soft_delete_dependents
        reflect_on_all_associations.
          select { |a| [:destroy, :delete_all, :nullify].include?(a.options[:dependent]) }.
          select { |a| a.klass.method_defined?(:soft_delete!) }.map(&:name)
      end

      def with_deleted
        key = :"soft_deletion_with_deleted_#{soft_delete_default_scope}"
        Thread.current[key] = true
        yield
      ensure
        Thread.current[key] = nil
      end

      def mark_as_soft_deleted_sql
        { deleted_at: Time.now }
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
            model.run_callbacks :soft_delete
          end
        end
      end
    end

    def deleted?
      deleted_at.present?
    end

    def mark_as_deleted
      self.deleted_at ||= Time.now
    end

    def mark_as_undeleted
      self.deleted_at = nil
    end

    def soft_delete!(*args)
      _run_soft_delete { save!(*args) } || soft_delete_hook_failed(:before_soft_delete)
    end

    def soft_delete(*args)
      _run_soft_delete{ save(*args) }
    end

    def soft_undelete
      _run_soft_undelete{ save }
    end

    def soft_undelete!
      _run_soft_undelete{ save! } || soft_delete_hook_failed(:before_soft_undelete)
    end

    def soft_delete_dependencies
      self.class.soft_delete_dependents.map { |dependent| SoftDeletion::Dependency.new(self, dependent) }
    end

    protected

    def soft_delete_counter_cache_associations
      each_counter_cached_associations do |association|
        foreign_key = association.reflection.foreign_key.to_sym
        unless destroyed_by_association && destroyed_by_association.foreign_key.to_sym == foreign_key
          if send(association.reflection.name)
            yield association
          end
        end
      end
    end

    def _run_soft_delete(&block)
      result = false
      internal = lambda do
        mark_as_deleted
        soft_delete_dependencies.each(&:soft_delete!)
        result = block.call
        soft_delete_counter_cache_associations(&:decrement_counters)
      end

      self.class.transaction do
        run_callbacks :soft_delete, &internal
      end

      result
    end

    def _run_soft_undelete(&block)
      raise "#{self.class} is not deleted" unless deleted_at

      result = false
      limit = deleted_at - 1.hour
      internal = lambda do
        mark_as_undeleted
        soft_delete_dependencies.each { |m| m.soft_undelete!(limit)}
        result = block.call
        soft_delete_counter_cache_associations(&:increment_counters)
      end

      self.class.transaction do
        run_callbacks :soft_undelete, &internal
      end

      result
    end

    def soft_delete_hook_failed(hook)
      error = (errors.full_messages.presence || ["None"]).join(", ")
      message = "#{hook} hook failed, errors: #{error}"
      # not passing record (self) as 2nd argument to be rails 3/4.1 compatible
      raise ActiveRecord::RecordNotSaved.new(message)
    end
  end
end
