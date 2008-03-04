require File.dirname(__FILE__) + '/../test_helper'
require 'catalog_test_helper'

class RoomTest < Test::Unit::TestCase
  include CatalogTestHelper
  def setup
    @model = Room
  end
end
