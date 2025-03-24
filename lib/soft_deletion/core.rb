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
      base.cattr_accessor :soft_deletion_update_timestamp
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

      def soft_deleted
        with_deleted { where.not(deleted_at: nil) }
      end

      def mark_as_soft_deleted_sql
        t = Time.now

        {deleted_at: t}.tap do |h|
          h[self.soft_deletion_update_timestamp] = t if self.soft_deletion_update_timestamp
        end
      end

      def soft_delete_all!(ids_or_models)
        ids_or_models = Array.wrap(ids_or_models)

        if ids_or_models.first.is_a?(ActiveRecord::Base)
          ids = ids_or_models.map(&:id)
          models = ids_or_models
        else
          ids = ids_or_models
          models = where(:id => ids)
        end

        transaction do
          where(:id => ids).update_all(mark_as_soft_deleted_sql)

          models.each do |model|
            model.soft_delete_dependencies.each { |dep| dep.execute_soft_delete(:soft_delete!) }
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
      if self.class.soft_deletion_update_timestamp
        new_timestamp = [self.deleted_at, send(self.class.soft_deletion_update_timestamp)].compact.max

        send("#{self.class.soft_deletion_update_timestamp}=", new_timestamp)
      end
    end

    def mark_as_undeleted
      self.deleted_at = nil
    end

    def soft_delete!(*args, **kwargs)
      _run_soft_delete(:soft_delete!, *args, **kwargs) { save!(*args, **kwargs) } || soft_delete_hook_failed(:before_soft_delete)
    end

    def soft_delete(*args, **kwargs)
      _run_soft_delete(:soft_delete, *args, **kwargs) { save(*args, **kwargs) }
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

    if ActiveRecord.version >= Gem::Version.new("7.2.0")
      def update_soft_delete_counter_caches(value) # uncovered NOTE: covered only at Rails >= 7.2.0 tests
        counter_cached_association_names.each do |association_name| # uncovered
          update_soft_delete_counter_cache(association(association_name), value) # uncovered
        end
      end
    else
      def update_soft_delete_counter_caches(value) # uncovered NOTE: covered only at Rails < 7.2.0 tests
        each_counter_cached_associations do |association| # uncovered
          update_soft_delete_counter_cache(association, value) # uncovered
        end
      end
    end

    def update_soft_delete_counter_cache(association, value)
      association.load_target unless association.loaded?
      if (target = association.target) # uncovered TODO: add test coverage for target not existing
        target.class.update_counters(target.id, association.reflection.counter_cache_column => value)
      end
    end

    def _run_soft_delete(method, *args, **kwargs, &block)
      result = false
      self.class.transaction do
        internal = lambda do
          mark_as_deleted
          raise ActiveRecord::Rollback unless soft_delete_dependencies.all? { |dep| dep.execute_soft_delete(method, *args, **kwargs) }
          result = block.call
          raise ActiveRecord::Rollback unless result
          update_soft_delete_counter_caches(-1)
        end

        run_callbacks :soft_delete, &internal

        result
      end
      result
    end

    def _run_soft_undelete(&block)
      raise "#{self.class} is not deleted" unless deleted_at # uncovered TODO: add test coverage

      result = false
      limit = deleted_at - 1.hour
      internal = lambda do
        mark_as_undeleted
        soft_delete_dependencies.each { |m| m.soft_undelete!(limit) }
        result = block.call
        update_soft_delete_counter_caches(1)
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
