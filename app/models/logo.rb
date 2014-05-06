class Logo < ActiveRecord::Base
  belongs_to :conference

  validates_presence_of :conference_id
  validates_associated :conference

  before_save {|logo| logo.create_conf_dir}
  before_destroy do |logo|
    # Do not destroy the images if more than one logo is found for
    # this conference
    if Logo.find_all_by_conference_id(logo.conference_id).size == 1
      # Attempt to remove the logos from the filesystem. Ignore errors
      # (as we would only be keeping data not linked anymore)
      #
      # We leave the empty directory (except for the last component), as
      # it might have other conferences' logos in it
      File.unlink logo.filename
      File.unlink logo.filename_med
      File.unlink logo.filename_thumb
      Dir.rmdir logo._conf_dir
    end
  end

  # Stores the actual logo with the data received as a raw image as
  # its only parameter. Creates the medium resolution and thumbnail
  # versions as well - RMagick calculations will only be done when
  # storing images, not when serving them.
  #
  # RMagick will throw out a Magick::ImageMagickError if an invalid
  # image is received
  def process_img(data)
    create_conf_dir

    # Generate the Magick::Image object
    img = Magick::Image.from_blob(data)[0]
    self.width = img.columns
    self.height = img.rows

    # Re-generate the original, ensuring we have it as a JPG
    img.format = 'jpg'
    File.open(filename, 'w') {|f| f.puts img.to_blob}

    # Generate medium-resolution and thumbnail
    med = img.thumbnail(medium_width, medium_height)
    File.open(filename_med, 'w') {|f| f.puts med.to_blob}

    thb = img.thumbnail(thumb_width, thumb_height)
    File.open(filename_thumb, 'w') {|f| f.puts thb.to_blob}

    save!
  end

  def has_data?
    File.exists?(filename) and File.readable?(filename)
  end

  def filename; File.join(_conf_dir, 'logo.jpg'); end
  def filename_med; File.join(_conf_dir, 'med.jpg'); end
  def filename_thumb; File.join(_conf_dir, 'thumb.jpg'); end

  def url; File.join(_conf_url, 'logo.jpg'); end
  def url_med; File.join(_conf_url, 'med.jpg'); end
  def url_thumb; File.join(_conf_url, 'thumb.jpg'); end

  # Thumbnail height: Stored in the 'logo_thumb_height' SysConf entry
  # (defaults to 65 if not set)
  def thumb_height
    ( SysConf.value_for('logo_thumb_height') || 65 ).to_i
  end

  def data_width; width; end
  def data_height; height; end

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

  def _conf_partial_path
    self.conference_id.to_s.split('')
  end

  def _conf_dir
    File.join(SysConf.value_for('logo_base_dir'), _conf_partial_path)
  end

  def _conf_url
    File.join(SysConf.value_for('logo_base_url'), _conf_partial_path)
  end

  def create_conf_dir
    base = SysConf.value_for('logo_base_dir')
    path = self._conf_partial_path

    (File.exists?(base) and File.directory?(base)) or 
      raise Errno::ENOENT, _('Logo base directory %s does not exist') % base
    File.writable?(base) or
      raise Errno::EACCES, _('Logo base directory %s is not writable') % base

    (0..path.size-1).each do |item|
      partial = File.join(base, path[0..item])
      File.exists?(partial) or Dir.mkdir(partial)
      File.directory?(partial) or
        raise(Errno::ENOTDIR, _('Partial path %s for conference ID %s ' +
                                'exists, but is not a directory') %
              [partial, conference_id])
      File.writable?(partial) or
        raise(Errno::EACCES, _('Partial path %s for conference ID %s ' +
                               'exists, but is not writable'),
              [partial, conference_id])
    end
  end
end
