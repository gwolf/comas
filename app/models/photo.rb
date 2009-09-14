class Photo < ActiveRecord::Base
  belongs_to :person
  validates_presence_of :person_id
  validates_uniqueness_of :person_id
  validates_associated :person

  # Maximum size to which to resize a newly uploaded photo
  MAX_DIMENSIONS=400

  # We override find to exclude the whole file contents from our
  # result set.
  # 
  # The binary values should not be directly modified - Use
  # self#from_blob instead.
  def self.find (*args)
    select = (self.columns.map(&:name) - ['data']).join(', ')

    if args[-1].is_a?(Hash)
      if args[1].has_key? :select
        select = args[-1][:select]
      else
        args[-1][:select] = select
      end
    else
      args << {:select => select}
    end

    super(*args)
  end

  # Resizes the image specified (as a blob) as the only parameter to
  # whatever MAX_DIMENSIONS specifies; sets the related information
  # and saves the object
  def from_blob(value)
    img = Magick::Image.from_blob(value)[0]
    x = img.columns
    y = img.rows
    if x > y
      self.width, self.height = MAX_DIMENSIONS, (MAX_DIMENSIONS.to_f * y / x).to_i
    else
      self.width, self.height = (MAX_DIMENSIONS.to_f * x / y).to_i, MAX_DIMENSIONS
    end
    img.resize!(width, height)

    img.format = 'jpg'

    self.data = img.to_blob 
    save!
  end

  def data
    return self[:data] if self.attributes.has_key?('data')
    self.class.find(self.id, :select => 'id, data')[:data]
  end
end
