class PropStatus < ActiveRecord::Base
  acts_as_catalog
  has_many :proposals

  # The default #PropStatus (this means, the status a proposal will
  # get upon creation) is the status whose ID is defined as the
  # +new_prop_status_id+ #SysConf entry. 
  # 
  # If no such entry is defined, or if it points to an invalid ID, the
  # #PropStatus entry with lowest ID will be taken as default.
  def self.default
    begin
      default = self.find(SysConf.value_for('new_prop_status_id').to_i)
      raise 
    rescue
      self.find(:first, :order => 'id')
    end
  end

  # A #Proposal is accepted if its status is marked as #accepted? - It
  # will be true for the PropStatus whose ID is defined as the
  # +accepted_prop_status_id+ #SysConf entry.
  # 
  # If no such entry is defined, or if it points to an invalid ID, the
  # #PropStatus entry with highest ID will be taken as default.
  def self.accepted
    begin
      default = self.find(SysConf.value_for('accepted_prop_status_id').to_i)
    rescue
      self.find(:first, :order => 'id DESC')
    end
  end
end
