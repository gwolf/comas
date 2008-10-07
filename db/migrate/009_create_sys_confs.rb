class CreateSysConfs < ActiveRecord::Migration
  def self.up
    create_table :sys_confs do |t|
      t.column :key, :string, :null => false, :unique => true
      t.column :descr, :string
      t.column :value, :string
    end

    [ [ 'footer_text', 
        'Text to display as your page footer', 
        'Powered by <a href="http://www.comas-code.org/">Comas</a>'], 
      [ 'mail_from', 
        'E-mail address that should be used for system-generated mails', 
        'comas@iiec.unam.mx'], 
      [ 'title_text', 
        'Title for your Comas pages', 
        'Comas - Conference Management System'], 
      [ 'tolerance_post', 
        'Default tolerance period after a timeslot has started (hh:mm:ss)', 
        '00:35:00'], 
      [ 'tolerance_pre', 
        'Default tolerance period before a timeslot has started (hh:mm:ss)', 
        '00:20:00']
    ].each do |conf| 
      SysConf.new(:key => conf[0], :descr => conf[1], :value => conf[2]).save!
    end
  end

  def self.down
    drop_table :sys_confs
  end
end
