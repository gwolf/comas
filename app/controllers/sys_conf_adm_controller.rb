class SysConfAdmController < Admin
  before_filter :get_sysconf, :except => [:list, :create]
  Menu = [[_('Show configuration'), :list]]

  def list
    @confs = SysConf.find(:all, :order => :key)
    @new_conf = SysConf.new()
  end

  def delete
    redirect_to :action => :list
    return false unless request.post?
    @conf.destroy or
      flash[:error] = _('Error destroying requested entry: ') +
      @conf.errors.full_messages.join('<br/>')
  end

  def create
    redirect_to :action => :list
    return false unless request.post?
    conf = SysConf.new(params[:sys_conf])
    conf.save or flash[:error] = _('Error creating requested entry: ') +
      conf.errors.full_messages.join('<br/>')
  end

  def edit
  end

  def update
    redirect_to :action => :list
    return false unless request.post?

    if @conf.update_attributes(params[:sys_conf])
      flash[:notice] = _'The configuration entry was successfully updated'
    else 
      flash[:error] = _('Error updating requested configuration entry: ') +
        @conf.errors.full_messages.join("<br/>")
    end
  end

  protected
  def get_sysconf
    begin
      @conf = SysConf.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error]= _('Invalid configuration entry %d requested')% params[:id]
      redirect_to :action => :list
      return false
    end
  end
end
