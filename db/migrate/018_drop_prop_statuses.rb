class DropPropStatuses < ActiveRecord::Migration
  class SysConf < ActiveRecord::Base;end
  class Proposal < ActiveRecord::Base
    New, Pending, Rejected, Accepted = 1, 2, 3, 4
    Status = {New => _('New'), Pending => _('Details pending'),
      Rejected => _('Rejected'), Accepted => _('Accepted')}
  end

  def self.up
    # add/copy/delete in order to lose the FK relation
    add_column :proposals, :status, :integer
    Proposal.find(:all).map do |p|
      p.status = p.prop_status_id || Proposal::New
      p.save!
    end
    remove_column :proposals, :prop_status_id
    drop_catalogs :prop_statuses

    begin
      SysConf.find_by_key('new_prop_status_id').destroy
      SysConf.find_by_key('accepted_prop_status_id').destroy
    rescue NoMethodError
      # Does not exist? Don't destroy it.
    end
  end

  def self.down
    create_catalogs :prop_statuses
    add_reference :proposals, :prop_statuses
    Proposal.find(:all).map do |p|
      if PropStatus.find_by_id(p.status).nil?
        PropStatus.new(:id => p.status,
                       :name => Proposal::Status[p.status] ||
                       p.status.to_s).save!
      end
      p.prop_status_id = p.prop_status
      p.save!
    end
    remove_column :proposals, :status
  end
end
