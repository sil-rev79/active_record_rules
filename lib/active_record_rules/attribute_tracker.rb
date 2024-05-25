# frozen_string_literal: true

module ActiveRecordRules
  class AttributeTracker
    def initialize
      @attributes_by_class = Hash.new { _1[_2] = Set.new }
    end

    def attributes_by_class
      # Copy into a new hash, without the defaulting behaviour
      { **@attributes_by_class }
    end

    def add_attribute(attribute, klass)
      @attributes_by_class[klass] << attribute
    end

    def for_class(klass)
      ClassTracker.new(self, klass)
    end

    class ClassTracker
      def initialize(parent, klass)
        @parent = parent
        @klass = klass
      end

      def add(attribute)
        @parent.add_attribute(attribute, @klass)
      end

      def for_class(klass)
        ClassTracker.new(@parent, klass)
      end
    end
  end
end
