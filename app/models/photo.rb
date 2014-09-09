# -*- coding: utf-8 -*-
class Photo < ActiveRecord::Base
  belongs_to :person
  validates_presence_of :person_id
  validates_uniqueness_of :person_id
  validates_associated :person

  before_save {|photo| photo.create_photo_dir}
  before_destroy do |photo|
    # Do not destroy the images if more than one photo is found for
    # this person
    if Photo.find_all_by_person_id(photo.person_id).size == 1
      # Attempt to remove the photos from the filesystem. Ignore errors
      # (as we would only be keeping data not linked anymore)
      #
      # We leave the empty directory (except for the last component), as
      # it might have other photos in it
      File.unlink photo.filename
      File.unlink photo.filename_thumb
      Dir.rmdir photo._photo_dir
    end
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
    create_photo_dir

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

    File.open(filename, 'w') {|f| f.puts img.resize(width, height).to_blob }
    File.open(filename_thumb, 'w') {|f| f.puts img.resize(width * ratio,
                                                          height * ratio).to_blob }
    save!
  end

  # Keep old interface (mainly as it is used by the nametags)
  def data
    File.open(self.filename).read
  end

  def filename; File.join(_photo_dir, 'photo.jpg'); end
  def filename_thumb; File.join(_photo_dir, 'thumb.jpg'); end

  def url; File.join(_photo_url, 'photo.jpg'); end
  def url_thumb; File.join(_photo_url, 'thumb.jpg'); end

  def _photo_dir
    File.join(SysConf.value_for('photo_base_dir'), _photo_partial_path)
  end

  def _photo_url
    File.join(SysConf.value_for('photo_base_url'), _photo_partial_path)
  end

  def _photo_partial_path
    self.person_id.to_s.split('')
  end

  def create_photo_dir
    base = SysConf.value_for('photo_base_dir')
    path = self._photo_partial_path

    (File.exists?(base) and File.directory?(base)) or 
      raise Errno::ENOENT, _('Photo base directory %s does not exist') % base
    File.writable?(base) or
      raise Errno::EACCES, _('Photo base directory %s is not writable') % base

    (0..path.size-1).each do |item|
      partial = File.join(base, path[0..item])
      File.exists?(partial) or Dir.mkdir(partial)
      File.directory?(partial) or
        raise(Errno::ENOTDIR, _('Partial path %s for person ID %s ' +
                                'exists, but is not a directory') %
              [partial, conference_id])
      File.writable?(partial) or
        raise(Errno::EACCES, _('Partial path %s for person ID %s ' +
                               'exists, but is not writable'),
              [partial, conference_id])
    end
  end
end
