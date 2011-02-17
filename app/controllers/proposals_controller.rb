class ProposalsController < ApplicationController
  before_filter :get_proposal, :except => [:new, :create, :by_author]
  before_filter :get_person_by_login, :only => [:author_add, :author_add_confirm]
  before_filter :ck_document, :only => [:get_document, :delete_document]
  before_filter :ck_ownership, :except => [:new, :create, :show,
                                           :by_author, :get_document]
  before_filter :ck_can_show_proposals, :only => [:show, :get_document]
  class NotPost < Exception; end
  class AlreadyAnAuthor < Exception; end
  ############################################################
  # General operations to perform on a proposal as a whole

  def new
    @confs = @user.conferences_for_submitting
    if @confs.empty?
      flash[:warning] << _('There are currently no conferences for which ' +
                           'you can submit proposals. Please register first.')
      redirect_to :controller => 'people', :action => 'proposals'
      return false
    end
    @proposal = Proposal.new
    # If a conference_id is received, set it in the newly created object
    @proposal[:conference_id] = params[:conference_id]
  end

  def create
    if ! request.post?
      redirect_to :controller => 'people', :action => 'proposals'
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
        flash[:error] << _('Error saving your proposal: %s') % msg.message
        @confs = @user.conferences_for_submitting
        render :action => 'new'
        return false
      end
    end

    flash[:notice] << _('Your proposal was successfully registered')
    redirect_to :action => :show, :id => @proposal.id
  end

  def show
  end

  def edit
    return true unless request.post?
    if @proposal.update_attributes(params[:proposal])
      flash[:notice] << _('The proposal has been modified successfully')
      redirect_to :action => 'show', :id => @proposal
    else
      flash[:error] << _('Error updating the proposal: ') +
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
    unless request.post?
      redirect_to :action => :authors, :id => @proposal
      return true
    end

    auth = Authorship.find_by_id(params[:authorship_id].to_i)
    person = auth.person

    if auth and @proposal.authorships.include?(auth)
      if @proposal.authorships.delete(auth)
        flash[:notice] << _('Requested author (%s) was successfully removed ' +
                            'from this proposal') % person.name
      else
        flash[:error] << _('Unexpected error removing requested author. ' +
                           'Please try again, or contact system administrator')
      end

      if Proposal.find_by_id(@proposal).nil?
        flash[:warning] << _('The requested proposal has been deleted as its ' +
                            'last author was removed.')
        redirect_to :controller => 'conferences', :action => 'list'
        return true
      end

      flash[:error] << _('Requested author does not exist or is not listed ' +
                         'in this proposal. Maybe you already deleted him?')
    end

    redirect_to :action => :authors, :id => @proposal
  end

  def author_add_confirm
    confirmed = false
    begin
      raise NotPost unless request.post?
      raise AlreadyAnAuthor if @proposal.people.include? @person
      confirmed = true
    rescue AlreadyAnAuthor
      flash[:notice] << _('The requested author (%s) was already registered ' +
                          'as an author for this proposal') % @person.name
    rescue NotPost
    end

    redirect_to(:action => :authors, :id => @proposal) unless confirmed
  end

  def author_add
    redirect_to :action => :authors, :id => @proposal
    return true unless request.post?

    if @proposal.people.include? @person
      flash[:notice] << _('The requested author (%s) was already registered ' +
                          'as an author for this proposal') % @person.name
      return true
    end

    unless auth = Authorship.new(:proposal => @proposal,
                                 :person => @person) and
        auth.save
      flash[:error] << (_('Error adding person (%s) to requested proposal: ') %
                        @person.name) +
        auth.errors.full_messages.join('<br/>')
      return false
    end

    flash[:notice] << _('%s was successfully added as an author to this ' +
                       'proposal') % @person.name

    Notification.deliver_added_as_coauthor(@person, @proposal, @user)
  end

  def by_author
    @author = Person.find_by_id(params[:author_id].to_i)
    unless @author
      # What can we do? Well, nothing - Back to the conferences listing.
      redirect_to :controller => 'conferences', :action => 'list'
      return false
    end

    # You can always see all of your own conferences. You can always
    # see all conferences if you are part of the academic
    # committee. Otherwise, filter out those which are not yet
    # publicly showable.
    @show_all = (@user and (@author.id == @user.id or
                            @user.has_admin_task?(:academic_adm)))
    props = @author.proposals
    props = props.select {|p| p.publicly_showable?} unless @show_all

    @props = props.paginate(:page => params[:page],
                            :per_page => 20,
                            :include => [:people, :conference, :prop_type],
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
        flash[:notice] << _('The document was successfully saved')
      else
        flash[:error] << _('Error receiving the document:') +
          doc.errors.full_messages.join('<br/>')
      end
    end
  end

  def delete_document
    redirect_to :action => :show, :id => @proposal
    return true unless request.post?
    if @document.destroy
      flash[:notice] << _('The document was successfully deleted')
    else
      flash[:error] << _('Error removing requested document. Please try ' +
                         'again later, or contact the system administrator.')
    end
  end

  protected
  def check_auth
    public = [:show, :by_author]
    return true if public.include? request.path_parameters['action'].to_sym
  end

  def get_proposal
    @proposal = Proposal.find_by_id(params[:id])
    if @proposal.nil?
      flash[:error] << _('Invalid proposal requested')
      redirect_to :controller => 'conferences', :action => 'list'
      return false
    end
  end

  def get_person_by_login
    unless @person = Person.find_by_login(params[:login])
      flash[:error] << _('The specified login is not valid or does not match ' +
                         'any valid users')
      redirect_to :action => 'authors', :id => @proposal
      return false
    end
  end

  def ck_document
    # Ensure the requested document belongs to this proposal
    unless @document = @proposal.documents.find_by_id(params[:document_id])
      flash[:error] << _('Invalid document requested for this proposal')
      redirect_to :action => 'show', :id => @proposal
      return false
    end
  end

  def ck_ownership
    unless @user.proposals.include?(@proposal)
      flash[:error] << _('You are not allowed to modify this proposal')
      redirect_to :action => 'show', :id => @proposal
      return false
    end
  end

  def ck_can_show_proposals
    # You can always see all of your own conferences. You can always
    # see all conferences if you are part of the academic
    # committee. Otherwise, filter out those which are not yet
    # publicly showable.
    @can_edit = @proposal.people.include?(@user)
    return true if @can_edit or
      (@user and @user.has_admin_task?(:academic_adm)) or
      @proposal.conference.public_proposals?
    redirect_to(:controller => 'conferences', :action => 'show',
                :id => @proposal.conference)
    flash[:warning] << _("This conference's proposals are not yet public")
  end
end
