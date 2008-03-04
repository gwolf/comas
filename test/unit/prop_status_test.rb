require File.dirname(__FILE__) + '/../test_helper'
require 'catalog_test_helper'

class PropStatusTest < Test::Unit::TestCase
  include CatalogTestHelper
  def setup
    @model = PropStatus
  end
end
