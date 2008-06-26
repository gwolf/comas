class SysConf < ActiveRecord::Base
  validates_presence_of :key
  validates_uniqueness_of :key

  # Shorthand for find_by_key
  def self.value_for(key)
    self.find_by_key(key).value
  end
end
