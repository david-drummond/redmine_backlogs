# Controller for managing per-project issue statuses.

class RbIssueStatusesController < RbApplicationController
  unloadable

  # Form for editing per-project sprint task statuses.

  def edit
    setup
  end

  # Update per-project sprint task statuses.
  #
  # If params[:issue_statuses] is empty or not there, then
  # all per-project task statuses will be removed.

  def update
    issue_status_ids = params[:issue_statuses]
    project_name = params[:project_id]
    unless project_name then
      render_error "No project id given."
    end
    @project = Project.find_by_name(params[:project_id])
    unless @project then
      render_error "No project given."
    end
    if issue_status_ids.nil? then
      ids = []
    else
      ids = issue_status_ids.keys.map{|k|k.to_i}
    end
    RbProjectTaskStatus.update!(@project.id,ids)

    setup @project
    render :action => 'edit'
  end

  private

  # For use with edit and update.

  def setup project=nil
    if project.nil? then
      @project = Project.find_by_name(params[:project_id])
    else
      @project = project
    end
    unless @project then
      render_error "No project given."
    end
    @title = "Issue statuses for #{@project.name}"
    @issue_statuses = IssueStatus.find(:all)
    # Create a lookup of issue statuses for a given project.
    @project_statuses = RbProjectTaskStatus.find(
      :all,
      :conditions => {:project_id => @project.id})
    @project_statuses = @project_statuses.inject({}){|s,v|
      s[v[:issue_status_id]] = v
      s
    }
  end

end
