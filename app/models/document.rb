class Document < ActiveRecord::Base
  belongs_to :proposal

  validates_presence_of :filename
  validates_presence_of :data
  validates_presence_of :descr
  validates_presence_of :proposal_id
  validates_uniqueness_of(:filename, :scope => :proposal_id,
                          :message => _('A file with this name has already ' +
                                        'been uploaded to this proposal'))
  validates_associated :proposal

  # We override find to exclude the whole file contents (the 'data' column)
  # from our result set. Operation should be _almost_ transparent (see note by
  # self#data=)
  def self.find (*args)
    select = self.columns.map(&:name).select{|c| c != 'data'}.join(', ')

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

  # We avoid needlessly bringing in the full data - so just ask the DB
  # to get its size.
  def size
    self.class.find(self.id, :select => 'length(data)').length.to_i
  end

  # How should a human get (and understand) the size? In familiar
  # bytes/KB/MB/GB representations
  def human_size
    s = self.size.to_f # So in the divisions we don't lose the decimals
    return _('%.2f GB') % (s/(1024*1024*1024)) if size > 1024*1024*1024
    return _('%.2f MB') % (s/(1024*1024)) if size > 1024*1024
    return _('%.2f KB') % (s/1024) if size > 1024
    return _('%d bytes') % s
  end

  def data
    return self[:data] if self.attributes.has_key? 'data'

    doc = self.class.find(self.id, :select => '*')
    doc[:data]
  end

  # IMPORTANT THING TO REMEMBER:
  #
  # Contrary to most Rails conventions, data is saved AS SOON AS IT IS RECEIVED
  # in order to free us a bit from the pain of getting the full file data at
  # every instantiation.
  def data=(value)
    return super(value) if self.attributes.has_key? 'data'

    doc = self.class.find(self.id, :select => '*')
    doc.data=value

    doc.save!
  end

  # Windows uploads are usually sent with their full path information
  # - Strip it, to be on the safe side, and to avoid confusing just
  # about everybody
  def filename= (name)
    self[:filename] = sanitize(name)
  end

  private
  def sanitize(name)
    # get only the filename, not the whole path and
    # replace all none alphanumeric, underscore or periods with underscore
    File.basename(name.gsub('\\', '/')).gsub(/[^\w\.\-]/,'_')
  end
end
