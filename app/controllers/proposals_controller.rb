class ProposalsController < ApplicationController
  def new
    @confs = @user.conferences_for_submitting
    if @confs.empty?
      flash[:warnings] = _('There are currently no conferences for which ' +
                           'you can submit proposals. You can %s first if ' +
                           'you want to submit a proposal for them') %
        link_to('register for additional conferences', 
                :controller => 'conferences', :action => 'list')
      redirect_to :controller => 'people', :action => 'proposals'
      return false
    end
    @proposal = Proposal.new
    @proposal[:conference_id] = params[:conference_id]
  end

  def create
    if ! request.post?
      redirect_to :action => 'list'
      return false
    end

    begin
      @proposal = Proposal.new(params[:proposal])
      @proposal.transaction do
        @proposal.save or 
          raise ActiveRecord::Rollback, @proposal.errors.full_messages
        auth = Authorship.new(:person => @user, :proposal => @proposal)
        auth.save or raise ActiveRecord::Rollback, auth.errors.full_messages
      end
    rescue ActiveRecord::Rollback => msg
      flash[:error] = _('Error saving your proposal: %s') % msg.join("\n")
      @confs = @user.conferences_for_submitting
      render :action => new
      return false
    end

    flash[:notice] = _'Your proposal was successfully registered'
    redirect_to :action => :show, :id => @proposal.id
  end

  def show
    @proposal = Proposal.find_by_id(params[:id])
    if !@proposal 
      redirect_to :action => :list
      return false
    end
  end

  def list
  end

  def edit
  end

  protected
  def check_auth
    public = [:show, :list]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
