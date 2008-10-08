class CreateSysConfs < ActiveRecord::Migration
  def self.up
    create_table :sys_confs do |t|
      t.column :key, :string, :null => false, :unique => true
      t.column :descr, :string
      t.column :value, :string
    end

    [ [ 'title_text', 
        'Title for your Comas pages', 
        'Comas - Conference Management System'], 
      [ 'footer_text', 
        'Text to display as your page footer', 
        'Powered by <a href="http://www.comas-code.org/">Comas</a>'], 
      [ 'mail_from', 
        'E-mail address that should be used for system-generated mails', 
        'invalid_mail_address@lazy-comas-admin.org'], 
      [ 'tolerance_post', 
        'Default tolerance period after a timeslot has started (hh:mm:ss)', 
        '00:35:00'], 
      [ 'tolerance_pre', 
        'Default tolerance period before a timeslot has started (hh:mm:ss)', 
        '00:20:00'],
      [ 'new_prop_status_id',
        'The proposal status ID a new proposal should be assigned. Leaving ' +
        'it empty means the status with lowest available ID should be taken.',
        ''],
      [ 'accepted_prop_status_id',
        'The proposal status ID that means a proposal has been accepted. ' +
        'Leaving it empty means the status with highest available ID should ' +
        'be taken.',
        '']
    ].each do |conf| 
      SysConf.new(:key => conf[0], :descr => conf[1], :value => conf[2]).save!
    end
  end

  def self.down
    drop_table :sys_confs
  end
end
