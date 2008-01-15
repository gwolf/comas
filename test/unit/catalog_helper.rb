# Generic tests for catalogs
#
# A catalog is defined as a simple model, whose table has only two attributes:
# ID and name. Names are required and unique. 
#
# This helper should be required in your catalog unit tests. Then, just declare
# the right model in your <tt>setup</tt> method, i.e. to test the SomeModel 
# model, your test could be:
#
#   require File.dirname(__FILE__) + '/../test_helper'
#   require File.dirname(__FILE__) + '/catalog_helper'
#
#   class PropTypeTest < CatalogTest
#     def setup
#       @model = PropType
#     end
#   end

class CatalogTest < ActiveSupport::TestCase
  def test_catalog_table_is_well_defined
    return if @model.nil?

    # Make sure the table has the right structure: Two fields, named
    # 'name' and 'id'. Else, it is not a ComasCatalog.
    columns = @model.column_names.map {|fld| fld.to_sym}
    assert columns.size == 2
    assert columns.include?(:id)
    assert columns.include?(:name)
  end

  def test_catalog_requires_valid_name
    return if @model.nil?

    # No catalog item should be allowed without a name
    item = @model.new
    assert !item.valid?
    assert item.errors.on(:name)

    # ...But with a name, it should work
    item.name = 'The Name'
    assert item.valid?
    assert item.save
  end

  def test_catalog_requires_unique_names
    return if @model.nil?

    # Get a first item as a reference...
    item = @model.find(:first)
    if item.nil?
      item = @model.new(:name => 'The Name')
      item.save
    end

    # Another item with the same name should be rejected
    item2 = @model.new
    item2.name = item.name
    assert !item2.valid?
    assert item2.errors.on(:name)

    # But if the name is changed, it should work correctly
    item2.name += '... But changed'
    assert item2.valid?
    assert item2.save
  end
end
