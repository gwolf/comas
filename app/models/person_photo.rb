class PersonPhoto < ActiveRecord::Base
  belongs_to :person
  validates_presence_of :person_id
  validates_uniqueness_of :person_id
  validates_associated :person

  # Maximum size to which to resize a newly uploaded photo
  MAX_DIMENSIONS=400

  # Resizes the image specified (as a blob) as the only parameter to
  # whatever MAX_DIMENSIONS specifies; sets the related information
  # and saves the object
  def save_data(value)
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
end
