include RbCommonHelper

class RbTaskboardsController < RbApplicationController
  unloadable

  def show
    stories = @sprint.stories
    @story_ids    = stories.map{|s| s.id}

    @settings = Backlogs.settings

    # Determine status columns to show.
    tracker = RbSprintTaskTracker.instance
    statuses = RbProjectTaskStatus.issue_statuses_for(@project)

    # disable columns by default
    if User.current.admin?
      @statuses = statuses
    else
      enabled = {}
      statuses.each{|s| enabled[s.id] = false}
      # enable all statuses held by current tasks, regardless of whether the current user has access
      RbTask.find(:all, :conditions => ['fixed_version_id = ?', @sprint.id]).each {|task| enabled[task.status_id] = true }

      roles = User.current.roles_for_project(@project)
      #@transitions = {}
      statuses.each {|status|

        # enable all statuses the current user can reach from any task status
        [false, true].each {|creator|
          [false, true].each {|assignee|

            allowed = status.new_statuses_allowed_to(roles, tracker, creator, assignee).collect{|s| s.id}
            #@transitions["c#{creator ? 'y' : 'n'}a#{assignee ? 'y' : 'n'}"] = allowed
            allowed.each{|s| enabled[s] = true}
          }
        }
      }
      @statuses = statuses.select{|s| enabled[s.id]}
    end

    # Find tasks that don't have a status in @statuses.
    #
    # This can happen if the preferred task statuses for the project
    # have changed or if the default task statuses have changed and
    # the project is using the defaults. In either case there may be
    # tasks that have an issue status that is no longer used by the
    # project.

    @status_lookup = @statuses.inject({}){ |h,status|
      h[status.id] = true; h
    }
    @tasks_not_shown = @sprint.stories.inject([]){ |arr,story|
      arr = arr.concat(story.descendants.select{ |task|
        !@status_lookup.has_key?(task.status_id)
      })
      arr
    }

    if @sprint.stories.size == 0
      @last_updated = nil
    else
      @last_updated = RbTask.find(:first,
                        :conditions => ['tracker_id = ? and fixed_version_id = ?', RbTask.tracker, @sprint.stories[0].fixed_version_id],
                        :order      => "updated_on DESC")
    end

    respond_to do |format|
      format.html { render :layout => "rb" }
    end
  end

  def update
    unless params[:tasks].kind_of?(Hash) then
      flash[:error] = "Invalid parameters to update function. Did you select at least one task to change the status."
      redirect_to :action => 'show' , :sprint_id => @sprint.id
      return
    end
    issue_status_id = params[:issue_status_id].to_i
    unless issue_status_id > 0 then
      flash[:error] = "Invalid parameters to update function: invalide issue_status_id."
      redirect_to :action => 'show' , :sprint_id => @sprint.id
      return
    end
    issue_status = IssueStatus.find(issue_status_id)
    unless issue_status then
      flash[:error] = "Can't find issue status with issue_status_id #{issue_status_id}."
      redirect_to :action => 'show' , :sprint_id => @sprint.id
      return
    end
    task_ids = params[:tasks].keys.map{|k|k.to_i}
    tasks = RbTask.find(task_ids)
    tasks.each{|task| task.status_id = issue_status_id; task.save! }
    flash[:notice] = "Changed status of checked tasks to #{issue_status.name}."
    redirect_to :action => 'show' , :sprint_id => @sprint.id
  end

  def current
    sprint = @project.active_sprint
    if sprint
      redirect_to :controller => 'rb_taskboards', :action => 'show', :sprint_id => sprint
      return
    end
    respond_to do |format|
      format.html { redirect_back_or_default(project_url(@project)) }
    end
  end

end
