class ShortConferenceName < ActiveRecord::Migration
  class Conference < ActiveRecord::Base
    # ensure_short_name validation copied from the "real" Conference
    # class' #ensure_short_name - This will keep the RDBMS happy and
    # ticking, even with an unique index being created.
    def validate 
      prepared = name.gsub(/\s/, '_').gsub(/[^\w]/,'').downcase
      cutoff = 10
      short = prepared[0..cutoff]
      while self.class.find_by_short_name(short)
        cutoff += 1
        short << (prepared[cutoff] || '+')
      end
      self.short_name = short
    end
  end

  def self.up
    add_column(:conferences, :short_name, :string, 
               :default => '', :null => false)
    Conference.find(:all).each {|c| c.save} #Enough to trigger the validation
    add_index :conferences, :short_name, :unique => true
  end

  def self.down
    remove_column :conferences, :short_name
  end
end
