# -*- coding: utf-8 -*-
class SysConf < ActiveRecord::Base
  validates_presence_of :key
  validates_uniqueness_of :key

  # Default entries are _not_ handled through gettext - This will fill
  # up the DB at first system usage, before even determining the
  # desired system languages
  DefaultEntries = {
    'accepted_prop_status_id' => {
      :descr => ('The proposal status ID that means a proposal has been ' +
                 'accepted. Leaving it empty means the status with highest ' +
                 'available ID should be taken.'),
      :value => ''},
    'footer_text' => {
      :descr => 'Text to display as your page footer',
      :value => 'Powered by <a href="http://www.comas-code.org/">Comas</a>'},
    'logo_base_dir' => {
      :descr => 'Server directory in which conference logos are to be stored',
      :value => File.join(RAILS_ROOT, 'public/logos') },
    'logo_base_url' => {
      :descr => 'URL in which conference logos are to be found (following logo_base_dir)',
      :value => '/logos' },
    'mail_from' => {
      :descr => ('E-mail address that should be used for system-generated ' +
                 'mails'),
      :value => 'invalid_mail_address@lazy-comas-admin.org'},
    'new_prop_status_id' => {
      :descr => ('The proposal status ID a new proposal should be assigned. ' +
                 'Leaving it empty means the status with lowest available ' +
                 'ID should be taken.'),
      :value => ''},
    'personal_nametag_format' => {
      :descr => 'The name of the certificate format to use as nametags ' +
      'to be printed by the attendees',
      :value => ''},
    'photo_base_dir' => {
      :descr => 'Server directory in which user photos are to be stored',
      :value => File.join(RAILS_ROOT, 'public/photos') },
    'photo_base_url' => {
      :descr => 'URL in which user photos are to be found (following photo_base_dir)',
      :value => '/photos' },
    'system_layout' => {
      :descr => ('Layout to use for presenting the Comas interface. ' +
                 "Defaults to Rails' default value, 'application'. "),
      :value => 'application'},
    'title_text' => {
      :descr => 'Title for your Comas pages',
      :value => 'Comas - Conference Management System' },
    'tolerance_post' => {
      :descr => ('Default tolerance period after a timeslot has started ' +
                 '(hh:mm:ss)'),
      :value => '00:35:00'},
    'tolerance_pre' => {
      :descr => ('Default tolerance period before a timeslot has started ' +
                 '(hh:mm:ss)'),
      :value => '00:20:00'}
  }

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
    k = key.to_s
    now = Time.now

    return @@cache[k][1] if @@cache[k] and @@cache[k].is_a?(Array) and
      @@cache[k][0] > now - 2.seconds

    if item = self.find_by_key(k)
      @@cache[k] = [now, item.value]
      @@cache[k][1]
    elsif default = DefaultEntries[k]
      self.new(:key => k, :descr => default[:descr],
               :value => default[:value]).save and self.value_for(k)
    else
      nil
    end
  end
end
