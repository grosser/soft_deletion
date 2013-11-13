module SoftDeletion
  class Dependency
    attr_reader :record, :association_name

    def initialize(record, association_name)
      @record = record
      @association_name = association_name
    end

    def soft_delete!
      case association.options[:dependent]
      when :nullify
        nullify_dependencies
      when :delete_all
        dependency.update_all(record.class.mark_as_soft_deleted_sql)
      else
        dependencies.each(&:soft_delete!)
      end
    end

    def soft_undelete!(limit)
      klass.with_deleted do
        dependencies.reject { |m| m.deleted_at.to_i < limit.to_i }.each(&:soft_undelete!)
      end
    end

    protected

    def nullify_dependencies
      dependencies.each do |dependency|
        foreign_key = if association.respond_to?(:foreign_key) # rails 3.1+
          association.foreign_key
        else
          association.primary_key_name
        end
        method = (ActiveRecord::VERSION::STRING >= "3.1" ? :update_column : :update_attribute)
        dependency.send(method, foreign_key, nil)
      end
    end

    def klass
      association.klass
    end

    def association
      record.class.reflect_on_association(association_name.to_sym)
    end

    def dependency
      record.send(association_name)
    end

    def dependencies
      Array.wrap(dependency)
    end
  end
end
