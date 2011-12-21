class Logo < ActiveRecord::Base
  belongs_to :conference

  validates_presence_of :conference_id
  validates_associated :conference

  # Fields holding binary content that are specially managed
  BinFields = ['data', 'medium', 'thumb']

  # We override find to exclude the whole file contents (data, medium
  # and thumb columns) from our result set.
  #
  # The binary values should not be directly modified - Use
  # self#from_blob instead.
  def self.find (*args)
    select = (self.columns.map(&:name) - BinFields).join(', ')

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

  BinFields.each do |col|
    eval "def #{col}
            return self[:#{col}] if self.attributes.has_key?('#{col}')
            logo = self.class.find(self.id, :select => 'id, conference_id, #{col}')
            logo[:#{col}]
          end"
  end

  # Creates or updates the logo for the conference (specified as the
  # second parameter) with the data received as a raw image as the
  # first parameter. Creates the medium resolution and thumbnail
  # versions as well - RMagick calculations will only be done when
  # storing images, not when serving them.
  #
  # RMagick will throw out a Magick::ImageMagickError if an invalid
  # image is received
  def self.from_blob(data, conf)
    conf = Conference.find_by_id(conf) if conf.is_a?(Fixnum)
    logo = self.find(:first, :conditions => ['conference_id = ?', conf.id]) ||
      self.new
    logo.conference_id = conf.id

    # Generate the Magick::Image object
    img = Magick::Image.from_blob(data)[0]
    logo.width = img.columns
    logo.height = img.rows

    # Re-generate the original, ensuring we have it as a JPG
    img.format = 'jpg'
    logo[:data] = img.to_blob

    # Generate medium-resolution and thumbnail
    med = img.thumbnail(logo.medium_width, logo.medium_height)
    logo[:medium] = med.to_blob

    thb = img.thumbnail(logo.thumb_width, logo.thumb_height)
    logo[:thumb] = thb.to_blob

    logo.save!

    logo
  end

  # Thumbnail height: Stored in the 'logo_thumb_height' SysConf entry
  # (defaults to 65 if not set)
  def thumb_height
    ( SysConf.value_for('logo_thumb_height') || 65 ).to_i
  end

  # Thumbnail width (proportional to #thumb_height, preserving the
  # original image's aspect ratio)
  def thumb_width
    width * thumb_height / height
  end

  # Medium resolution height: Stored in the 'logo_medium_height'
  # SysConf entry (defaults to 500 if not set)
  #
  # If the full image is smaller than the medium image, there is no
  # point in having an amplified (and blurry) medium image - So give
  # back the original size.
  def medium_height
    ht = ( SysConf.value_for('logo_medium_height') || 500 ).to_i
    height < ht ? height : ht
  end

  # Medium resolution width (proportional to #medium_height, preserving the
  # original image's aspect ratio)
  def medium_width
    width * medium_height / height
  end

  def bigger_than_medium?
    height > medium_height
  end

  private
  BinFields.each { |col| eval "def #{col}=(what); end"}
end
