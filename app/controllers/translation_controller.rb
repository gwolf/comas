class TranslationController < Admin
  before_filter :get_language, :only =>[:search_for_strings, :pending_for_lang,
                                        :all_for_lang, :done_for_lang]
  before_filter :get_translation, :only => [:update, :delete]
  Menu = [[_('Statistics by language'), :stat_by_lang]]

  def stat_by_lang
    # Create empty translations if/where needed
    Translation.create_blanks
    @languages = Language.find(:all)
  end

  def list
    list = session[:translation_list] || {}
    if ! list.has_key?(:qry)
      pending_for_lang
      return true
    end

    @language = Language.find_by_id(list[:lang])
    @heading = list[:head]

    if list[:qry] == :lang
      data = @language.translations
      data = data.select(&:pending?)  if list[:cond] == :pending
      data = data.reject(&:pending? ) if list[:cond] == :done
    elsif list[:qry] == :str
      data = Translation.search_for(list[:str], @language,
                                    list[:on_trans], list[:on_base])
    end
    @strings = data.sort_by(&:base).paginate(:page => params[:page])
  end

  def pending_for_lang
    all_for_lang
    session[:translation_list][:cond] = :pending
  end

  def done_for_lang
    all_for_lang
    session[:translation_list][:cond] = :done
  end

  def all_for_lang
    session[:translation_list] = {:qry => :lang,
      :lang => @language.id,
      :head => _('Pending strings for %s') %
               Translation.for('Language|' + @language.name)}
    redirect_to :action => :list, :page => params[:page] || 1
  end

  def search_for_strings
    session[:translation_list] = {:qry => :str,
      :str => params[:string],
      :lang => @language.id,
      :on_trans => [:trans, :both].include?(params[:search_in].to_sym),
      :on_base => [:base, :both].include?(params[:search_in].to_sym),
      :head => _('Searching for strings in <em>%s</em> matching <em>%s</em>'
                 ) % [@language.name, params[:string]]
    }
    redirect_to :action => :list, :page => params[:page] || 1
  end

  def update
    redirect_to :action => 'list'
    return true unless request.post?
    @trans.update_attributes(params[:translation])
    flash[:notice] << _('Translation successfully registered')
  end

  def delete
    redirect_to :action => 'list'
    return true unless request.post?
    # Delete all the translations for this base string - otherwise,
    # they will all reappear as soon as stat_by_lang is next invoked
    Translation.find(:all, :conditions =>
                     ['base = ?', @trans.base]).each(&:destroy)
    flash[:notice] << _('Translation successfully removed')
  end

  protected
  def get_language
    begin
      @language = Language.find(params[:language_id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Invalid language specified')
      redirect_to :action => :stat_by_lang
      return false
    end
  end

  def get_translation
    begin
      @trans = Translation.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] << _('Invalid translation specified')
      redirect_to :action => :stat_by_lang
      return false
    end
  end
end
