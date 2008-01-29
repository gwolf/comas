module Catalog
  ActiveRecord::Base::validates_presence_of :name
  ActiveRecord::Base::validates_uniqueness_of :name
end
