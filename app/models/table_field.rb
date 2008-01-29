# Dynamic table fields definition
#
# This model allows you to represent and validate your conference data 
# structure outside what the regular Comas models allow. For example, say
# that in your conference, besides the regular data required from people 
# (firstname, family name, login, password name and e-mail address), you want
# to get their postal address, and you want them to be separable by country. To
# do this, you create a <tt>countries</tt> catalog (i.e. a table with only a 
# <tt>name</tt> attribute). You then add the <tt>country_id</tt> and 
# <tt>postal_address</tt> fields to Person. Being this Rails and all, the 
# fields will be magically available already in the Person model.
#
# But of course, you want them to be validated! Ok, easy: (...)

#--
# Y también hay que crear las clases relacionadas... 
#++

class TableField < ActiveRecord::Base
  Valid_tables = ['person', 'proposal']

  validates_presence_of :model
  validates_inclusion_of :model, :in => Valid_tables
  validates_presence_of :field
  validates_uniqueness_of :field, :scope => :model
  
  Valid_tables.each do |tbl|
    eval "def self.for_#{tbl}; self.for_table('#{tbl}'); end"
  end

  def set_validations
    fldname = self.field
    regex = self.valid_regex
    model = self.model.classify.constantize

    logger.info("Field #{fldname} in #{self.model} not defined") unless 
      model.column_names.include? fldname

    model.class_eval {validates_presence_of fldname} unless self.allow_null

    model.class_eval {
      validates_each fldname do |rec, attr, val|
        rec.errors.add attr, "Is not valid (#{regex})" unless val =~ regex
      end
    } unless self.valid_regex.blank?
  end

  def declare_related_model
    fldname = self.field.gsub(/_id$/, '')
    tblname = fldname.tableize
    modelname = fldname.classify
    ref_model = self.model

    raise NameError, 'Not a relation field' unless defines_relation?

    # Ok, create the class, and define it in 
    eval %Q(
    class ::#{modelname} < ActiveRecord::Base
      include Catalog
      has_many :#{ref_model.pluralize}
    end

    class ::#{ref_model.classify}
      belongs_to :#{fldname}
    end
    )
  end

  # Right now, this only checks if the field ends with '_id'. We should add
  # further checks later on... (i.e. does the refered table exist?)
  def defines_relation?
    self.field =~ /_id$/
  end

  private
  def self.for_table(which) 
    list = self.find(:all, :conditions => ['model = ?', which.to_s])
    return list unless list.is_a? Array
    list.sort_by { |fld| [fld.order, fld.field] }
  end
end
