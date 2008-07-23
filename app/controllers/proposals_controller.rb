class ProposalsController < ApplicationController
  before_filter :get_proposal, :except => [:new, :create, :list, :by_author]

  def new
    @confs = @user.conferences_for_submitting
    if @confs.empty?
      flash[:warnings] = _('There are currently no conferences for which ' +
                           'you can submit proposals. Please register first.')
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
  end

  def list
  end

  def edit
    return true unless request.post?
    if @proposal.update_attributes(params[:proposal])
      flash[:notice] = _'The proposal has been modified successfully'
    else
      flash[:error] = _('Error updating the proposal: ') +
        @proposal.errors.full_messages.join('<br/>')
    end
  end

  def authors
  end

  def author_up
    redirect_to :action => 'authors', :id => @proposal.id
    auth = Authorship.find_by_id(params[:authorship_id])
    return false unless auth and auth.proposal_id = @proposal.id

    auth.move_higher
  end

  def author_down
    redirect_to :action => 'authors', :id => @proposal.id
    auth = Authorship.find_by_id(params[:authorship_id])
    return false unless auth and auth.proposal_id = @proposal.id

    auth.move_lower
  end

  def by_author
    @author = Person.find_by_id(params[:author_id].to_i)
    unless @author
      redirect_to :action => 'list'
      flash[:error] = _('No author specified - rendering general list')
      return false
    end

    @props = Proposal.list_paginator(:page => params[:page],
                                     :conditions => ['people.id = ?', 
                                                     @author.id])
  end

  protected
  def check_auth
    public = [:show, :list, :by_author]
    return true if public.include? request.path_parameters['action'].to_sym
  end

  def get_proposal
    @proposal = Proposal.find_by_id(params[:id])
    if @proposal.nil?
      flash[:error] = _'Invalid proposal requested'
      redirect_to :action => :list
      return false
    end
  end
end
