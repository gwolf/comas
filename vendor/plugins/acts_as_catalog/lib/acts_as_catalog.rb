module GWolf
  module UNAM #:nodoc:
    module ActsAsCatalog #:nodoc:
      def self.append_features(base)
        super
        base.extend(ClassMethods)
      end
      module ClassMethods
        def acts_as_catalog
          validates_presence_of :name
          validates_uniqueness_of :name
        end
      end
    end
  end
end
