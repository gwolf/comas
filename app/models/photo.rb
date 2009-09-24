class Photo < ActiveRecord::Base
  belongs_to :person
  validates_presence_of :person_id
  validates_uniqueness_of :person_id
  validates_associated :person

  HideColumns = %w(data thumb)

  # We override find to exclude the whole file contents from our
  # result set.
  # 
  # The binary values should not be directly modified - Use
  # self#from_blob instead.
  def self.find (*args)
    select = (self.columns.map(&:name) - HideColumns).join(', ')

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

  # Maximum  dimensions  to  store  a  photo with  —  Taken  from  the
  # «logo_thumb_height» SysConf key, defaulting to 500.
  def self.max_size
    SysConf.value_for('logo_medium_height').to_i || 500
  end

  # The size ratio between the thumb and the regular photo dimensions
  # — Taken from max_size and the «logo_thumb_height» SysConf
  # key, defaulting to 65.
  def self.thumb_ratio
    (SysConf.value_for('logo_thumb_height') || 65).to_f / self.max_size
  end

  # Resizes the image specified (as a blob) as the only parameter to
  # whatever MAX_DIMENSIONS specifies; sets the related information
  # and saves the object
  def from_blob(value)
    img = Magick::Image.from_blob(value)[0]
    x = img.columns
    y = img.rows

    max = self.class.max_size
    ratio = self.class.thumb_ratio

    if x > y
      self.width, self.height = max, (max.to_f * y / x).to_i
    else
      self.width, self.height = (max.to_f * x / y).to_i, max
    end
    img.format = 'jpg'

    self.data = img.resize(width, height).to_blob 
    self.thumb = img.resize(width * ratio,
                            height * ratio).to_blob 
    save!
  end

  HideColumns.each do |col|
    eval "def #{col}
            return self[:#{col}] if self.attributes.has_key?('#{col}')
            self.class.find(self.id, :select => 'id, #{col}')[:#{col}]
          end"
  end
end
