# Controller for managing per-project issue statuses.

class RbIssueStatusesController < RbApplicationController
  unloadable

  # Form for editing per-project sprint task statuses.

  def edit
    @project = Project.find_by_identifier(params[:project_id])
    unless @project then
      render_to_string "Bad project identifier in url."
      return
    end
    @title = "Issue statuses for #{@project.name}"
    @issue_statuses = IssueStatus.find(:all,:order => 'position')

    # Create a lookup of issue statuses for a given project.
    @project_statuses = RbProjectTaskStatus.find(
      :all,
      :conditions => {:project_id => @project.id})
    @project_statuses = @project_statuses.inject({}){|s,v|
      s[v[:issue_status_id]] = v
      s
    }

  end

  # Update per-project sprint task statuses.
  #
  # If params[:issue_statuses] is empty or not there, then
  # all per-project task statuses will be removed.

  def update
    issue_status_ids = params[:issue_statuses]
    project_name = params[:project_id]
    unless project_name then
      render_to_string "Bad project identifier in url."
      return
    end
    @project = Project.find_by_identifier(params[:project_id])
    unless @project then
      render_to_string "Bad project identifier in url."
      return
    end
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
    redirect_to :action => 'edit' , :project_id => params[:project_id]
  end

end
