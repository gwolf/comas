# -*- coding: utf-8 -*-
require 'tempfile'
class Logo < ActiveRecord::Base
  belongs_to :conference

  validates_presence_of :conference_id
  validates_associated :conference

  before_save {|logo| logo.create_conf_dir}
  before_destroy do |logo|
    # Attempt to remove the logos from the filesystem. Ignore errors
    # (as we would only be keeping data not linked anymore)
    #
    # We leave the empty directory (except for the last component), as
    # it might have other conferences' logos in it
    [logo.filename_thumb, logo.filename_med, logo.filename].each do |img|
      File.unlink(img) rescue nil
    end
    Dir.rmdir(logo._conf_dir) rescue nil
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
    if img.format == 'PDF'
      # Read the PDF and specify it to be of a resolution adequate for
      # printing in A4 / Letter, 300dpi
      #
      # To do this, instead of working with the data we received as a
      # blob, we have to use an external file :-/
      tf = Tempfile.new(['comas', '.pdf'])
      tf.print(data)
      tmpfilename = tf.path
      tf.flush

      tmpimg = Magick::ImageList.new(tf.path) {
        self.quality=80
        self.density=300
      }
      tmpimg[0].resize_to_fit(3300) # 11 inches, 300dpi
      tmpimg[0].format='jpg'

      # Seems a bit backwards to take an in-mem object, put it through
      # to_blob and from_blob in this same call... :-Þ
      img = Magick::Image.from_blob( tmpimg[0].to_blob )[0]
    end

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

  def data
    return nil unless has_data?
    return File.open(filename,'r') {|f| f.read}
  end

  def filename; File.join(_conf_dir, _my_name_for(:full)); end
  def filename_med; File.join(_conf_dir, _my_name_for(:med)); end
  def filename_thumb; File.join(_conf_dir, _my_name_for(:thumb)); end

  def url; File.join(_conf_url, _my_name_for(:full)); end
  def url_med; File.join(_conf_url, _my_name_for(:med)); end
  def url_thumb; File.join(_conf_url, _my_name_for(:thumb)); end

  def _my_name_for(size)
    return 'logo.jpg' if size == :full
    return 'med.jpg' if size == :med
    return 'thumb.jpg' if size == :thumb
  end

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
