include RbCommonHelper
include ProjectsHelper

class RbProjectSettingsController < RbApplicationController
  unloadable

  def project_settings
    enabled = false
    enabled_scrum_stats = false
    if request.post? and params[:settings]
      enabled = true if params[:settings]["show_stories_from_subprojects"]=="enabled"
      enabled_scrum_stats = true if params[:settings]["show_in_scrum_stats"]=="enabled"
    end
    settings = @project.rb_project_settings
    settings.show_stories_from_subprojects = enabled
    settings.show_in_scrum_stats = enabled_scrum_stats

    if settings.save
      flash[:notice] = t(:rb_project_settings_updated)
    else
      flash[:error] = t(:rb_project_settings_update_error)
    end

    issue_status_ids = params[:issue_statuses]    
    if issue_status_ids.nil? then
      ids = []
      flash[:notice] = "Project no longer specifies issue statuses.  Default issue statuses will be used."
    else
      ids = issue_status_ids.keys.map{|k|k.to_i}
      flash[:notice] = "Task statuses have been set for this project. These will be used instead of the defaults."
    end

    begin
      RbProjectTaskStatus.update!(@project.id,ids)
    rescue => e
      flash.delete(:notice)
      flash[:error] = "There was an error updating sprint task issue statuses for this project: #{e.message}"
    end

    redirect_to :controller => 'projects', :action => 'settings', :id => @project,
                :tab => 'backlogs'
  end

end
