module SoftDeletion
  class CounterCache
    attr_reader :record, :association

    def initialize(record, association)
      @record = record
      @association = association
    end

    def increment!
      update(true)
    end

    def decrement!
      update(false)
    end

    protected

    def update(up=false)
      unless destroyed_by_association
        if record.send(association.reflection.name)
          up ? association.increment_counters : association.decrement_counters
        end
      end
    end

    def foreign_key
      @foreign_key ||= association.reflection.foreign_key.to_sym
    end

    def destroyed_by_association
      record.destroyed_by_association && record.destroyed_by_association.foreign_key.to_sym == foreign_key
    end
  end
end
