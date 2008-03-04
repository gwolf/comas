require File.dirname(__FILE__) + '/../test_helper'
require 'catalog_test_helper'

class RoleTest < Test::Unit::TestCase
  include CatalogTestHelper
  def setup
    @model = Role
  end
end
