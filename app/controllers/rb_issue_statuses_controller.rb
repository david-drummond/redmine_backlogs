# Controller for managing per-project issue statuses.

class RbIssueStatusesController < RbApplicationController
  unloadable

  def edit
    @project = Project.find_by_name(params[:project_id])
    unless @project then
      # TODO: set error.
    end
    @title = "Issue statuses for #{@project.name}"
    @issue_statuses = IssueStatus.find(:all)
  end

  def update
  end

end
