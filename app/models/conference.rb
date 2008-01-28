class Conference < ActiveRecord::Base
  has_many :timeslots
  has_many :proposals
  has_many :conference_logos
  has_and_belongs_to_many :people

  validates_presence_of :name
  validates_uniqueness_of :name
  validate :dates_are_correct

  # Define a chronological default sorting
  def self.find(*args)
    order_arg = args.collect do |arg|
      if arg.kind_of? Hash 
        if arg.keys[0] == :order
          arg
        end
      end
    end

    if order_arg.compact.empty?
      args << {:order=> :begins}
    end
          
    super
  end

  protected
  def dates_are_correct
    errors.add(:begins, "can't be blank") if begins.nil? 
    errors.add(:finishes, "can't be blank") if finishes.nil? 

    if begins and finishes and begins > finishes
      errors.add( :finishes, 'Conference must end after its start date')
    end
  end
end
