# = Language - A given language for dynamic translations
#
# Language is a simple catalog, representing the list of known
# languages for the dynamic database-backed translations (see
# Translation for further details).
#
# The languages' names are only stored as their Locale abbreviations
# (two letters).
class Language < ActiveRecord::Base
  acts_as_catalog
  has_many :translations, :dependent => :destroy

  # Returns the Language corresponding to the current systemwide
  # (GetText) setting. Creates a new Language if it is not already
  # defined.
  def self.current
    self.for_locale(Locale.current.language)
  end

  # Returns the corresponding language for a locale string ('en',
  # 'es', and so on). If no such language exists yet, it is created.
  def self.for_locale(name)
    lang = self.find_by_name(name)
    if lang.nil?
      lang = self.create(:name => name)
      lang.save!
    end

    lang
  end

  def translation_stats
    Translation.create_blanks
    pending = translations.select {|trans| trans.pending?}.size
    total = translations.size
    done = total - pending
    perc = 100.0 * done / total

    { :total => total, :pending => pending, :done => done, :perc => perc }
  end
end
