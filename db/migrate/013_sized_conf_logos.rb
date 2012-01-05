class SizedConfLogos < ActiveRecord::Migration
  class Logo < ActiveRecord::Base; end
  class SysConf < ActiveRecord::Base; end

  def self.up
    rename_table :conference_logos, :logos
    add_column :logos, :thumb, :binary
    add_column :logos, :medium, :binary
    add_column :logos, :width, :integer
    add_column :logos, :height, :integer
    add_column :logos, :updated_at, :timestamp
    remove_column :logos, :filename

    SysConf.new(:key => 'logo_thumb_height',
                :descr => 'Height for the conference logo thumbnails',
                :value => '65').save
    SysConf.new(:key => 'logo_medium_height',
                :descr => 'Height for the medium resolution conference logo',
                :value => '500').save
  end

  def self.down
    add_column :logos, :filename, :string
    Logo.find(:all).each {|c| c.filename = "#{c.id}.png";c.save}
    [:updated_at, :height, :width, :medium, :thumb].each do |col|
      remove_column :logos, col
    end
    rename_table :logos, :conference_logos

    ['logo_thumb_height', 'logo_medium_height'].map do |k|
      sc = SysConf.find_by_key(k)
      next unless sc
      sc.destroy
    end
  end
end
