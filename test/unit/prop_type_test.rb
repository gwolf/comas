require File.dirname(__FILE__) + '/../test_helper'
require 'catalog_test_helper'

class PropTypeTest < Test::Unit::TestCase
  include CatalogTestHelper
  def setup
    @model = PropType
  end
end
