require File.dirname(__FILE__) + '/../test_helper'
require 'catalog_test_helper'

class PersonTypeTest < Test::Unit::TestCase
  include CatalogTestHelper
  def setup
    @model = PersonType
  end
end
