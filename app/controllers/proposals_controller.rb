class ProposalsController < ApplicationController
  before_filter :get_proposal, :except => [:new, :create, :list, :by_author]
  before_filter :ck_document, :only => [:get_document, :delete_document]
  before_filter :ck_ownership, :except => [:new, :create, :show, :list, 
                                           :by_author, :get_document]
  ############################################################
  # General operations to perform on a proposal as a whole

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

    @proposal = Proposal.new(params[:proposal])
    @proposal.transaction do
      begin
        @proposal.save or 
          raise ActiveRecord::Rollback, @proposal.errors.full_messages
        auth = Authorship.new(:person => @user, :proposal => @proposal)
        auth.save or raise ActiveRecord::Rollback, auth.errors.full_messages
      rescue ActiveRecord::Rollback => msg
        flash[:error] = _('Error saving your proposal: %s') % msg.message
        @confs = @user.conferences_for_submitting
        render :action => 'new'
        return false
      end
    end

    flash[:notice] = _'Your proposal was successfully registered'
    redirect_to :action => :show, :id => @proposal.id
  end

  def show
    @can_edit = @proposal.people.include?(@user)
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

  ############################################################
  # Operations regarding the proposal's authors
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

  def author_delete
    redirect_to :action => :authors, :id => @proposal
    return true unless request.post?

    auth = Authorship.find_by_id(params[:authorship_id].to_i)
    unless auth and @proposal.authorships.include? auth
      flash[:error] = _('Requested author does not exist or is not listed ' +
                        'in this proposal. Maybe you already deleted him?')
      return false
    end

    if @proposal.authorships.delete(auth) and @proposal.save
      flash[:notice] = _('Requested author was successfully removed')
    else
      flash[:error] = _('Unexpected error removing requested author. Please ' +
                        'try again, or contact system administrator')
    end
  end

  def author_add
    redirect_to :action => :authors, :id => @proposal
    return true unless request.post?

    unless new_auth = Person.find_by_login(params[:login])
      flash[:error] = _('The specified login is not valid or does not match ' +
                        'any valid users')
      return false
    end

    return true if @proposal.people.include? new_auth

    unless auth = Authorship.new(:proposal => @proposal, 
                                 :person => new_auth) and
        auth.save
      flash[:message] = _'Error adding person to requested proposal: ' +
        auth.errors.full_messages.join('<br/>')
      return false
    end

    flash[:message] = _'The specified author was successfully added to ' +
      'this proposal'

    Notification.deliver_added_as_coauthor(new_auth, @proposal, @user)
  end

  def by_author
    @author = Person.find_by_id(params[:author_id].to_i)
    unless @author
      redirect_to :action => 'list'
      flash[:error] = _('No author specified - rendering general list')
      return false
    end

    @props = @author.proposals.
      paginate(:page => params[:page],
               :per_page => 20,
               :include => [:people, :conference, :prop_type, :prop_status],
               :order => 'title, authorships.position')
  end

  ############################################################
  # Operations regarding the proposal's files
  def get_document
    send_data(@document.data,
              :filename => @document.filename,
              :type => @document.content_type || 'application/octet-stream',
              :disposition => 'inline')
  end

  def new_document
    redirect_to(:action => :show, :id => @proposal)
    if upload = params[:data] and !upload.is_a? String
      doc = Document.new(:proposal => @proposal,
                         :descr => params[:descr],
                         :filename => upload.original_filename,
                         :content_type => upload.content_type,
                         :data => upload.read)

      if doc.save
        flash[:notice] = _('The document was successfully saved')
      else
        flash[:error] = _('Error receiving the document:') +
          doc.errors.full_messages.join('<br/>')
      end
    end
  end

  def delete_document
    redirect_to :action => :show, :id => @proposal
    return true unless request.post?
    if @document.destroy
      flash[:notice] = _'The document was successfully deleted'
    else
      flash[:error] = _'Error removing requested document. Please try ' +
        'again later, or contact the system administrator.'
    end
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
      redirect_to :action => 'list'
      return false
    end
  end

  def ck_document
    unless @document = Document.find_by_id(params[:document_id]) and
        @document.proposal == @proposal
      flash[:error] = _'Invalid document requested for this proposal'
      redirect_to :action => 'show', :id => @proposal
      return false
    end
  end

  def ck_ownership
    unless @user.proposals.include?(@proposal)
      flash[:error] = _'You are not allowed to modify this proposal'
      redirect_to :action => 'show', :id => @proposal
      return false
    end
  end
end
