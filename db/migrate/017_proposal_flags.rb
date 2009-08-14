class ProposalFlags < ActiveRecord::Migration
  class Conference < ActiveRecord::Base; end

  def self.up
    add_column(:conferences, :manages_proposals, :boolean, :default => true)
    add_column(:conferences, :public_proposals, :boolean, :default => false)
    # Set the default values for existing records
    Conference.find(:all).map do |c|
      c.manages_proposals = true
      c.public_proposals = false
      c.save
    end
  end

  def self.down
    remove_column :conferences, :manages_proposals
    remove_column :conferences, :public_proposals
  end
end
