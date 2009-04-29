class SysConf < ActiveRecord::Base
  validates_presence_of :key
  validates_uniqueness_of :key

  # A lightweight caching system!  We set it to expire every 2 seconds
  # - It is basically made to avoid querying over and over for the
  # same entry in a single request. We could make it last longer, but
  # it can become a source for confusion.
  @@cache = {}

  def before_save
    @@cache.delete key.to_sym
  end

  # Shorthand for find_by_key
  def self.value_for(key)
    k = key.to_sym
    now = Time.now

    return @@cache[k][1] if @@cache[k] and @@cache[k].is_a?(Array) and
      @@cache[k][0] > now - 2.seconds

    item = self.find_by_key(key.to_s) or return nil
    @@cache[k] = [now, item.value]
    @@cache[k][1]
  end
end
