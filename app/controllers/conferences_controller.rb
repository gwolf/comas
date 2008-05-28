class ConferencesController < ApplicationController
  before_filter :get_conference, :except => [:index, :list]

  def index
    redirect_to :action => :list
  end

  def list
    @conferences = Conference.upcoming
  end

  def show
    redirect_to :list if !@conference.active?
  end

  protected
  def get_conference
    begin
      @conference = Conference.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = _'Invalid conference requested'
      redirect_to :action => :list
      return false
    end
  end

  def check_auth
    public = [:index, :list, :show]
    return true if public.include? request.path_parameters['action'].to_sym
  end
end
