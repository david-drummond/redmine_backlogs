# Model to represent a project's preferred sprint task statuses
# for use on the taskboard.
#
# By default, projects start with none and will use the default task
# statuses that are specified in the main Backlogs plugin
# configuration page. See self.default_issue_status_ids.

class RbProjectTaskStatus < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :issue_status

  # Update (sprint) task statuses for a given project.
  #
  # Old statuses are removed. New ones are inserted. If
  # issue_status_ids is empty, then you are removing all such statuses
  # for the project. Such projects will need to use
  # default_issue_status_ids.

  def self.update! project_id, issue_status_ids=[]
    self.delete_all({:project_id => project_id})
    unless issue_status_ids.empty? then
      issue_status_ids.each {|i|
        self.create!(:project_id => project_id,:issue_status_id => i)
      }
    end
  end

  # Callback for updating workflows for RbSprintTaskTracker.
  #
  # Whenever a project sets preferences, we will need to update
  # the workflow for the sprint task tracker.
  # TODO: use observer?

  def after_save
    RbTaskWorkflow.synchronize!
  end

  # Fetch a hash of default issue status ids that projects will use if
  # they don't specify any using this model.

  def self.default_issue_status_ids
    hash = {}
    defaults = Backlogs.setting[:default_task_statuses]
    defaults.keys.each{|k| hash[k.to_i] = true }
    hash
  end

  # Fetch a hash of preferred issue status ids for a project.
  #
  # If none, an empty hash is returned.
  # (Use default_issue_status_ids if that is the case.)
  #
  # project_ids can be an integer (id) or an array of ids.

  def self.issue_status_ids_for project_ids
    self.all(
      :select => "issue_status_id",
      :conditions => {:project_id => project_ids}
    ).inject({}){|h,v|
      h[v.issue_status_id] = true
      h
    }
  end

  # Fetch hash of all relevant issue status ids for all projects
  # including defaults.
  #
  # Useful for determining which workflows we must have.

  def self.all_issue_status_ids
    project_ids = Project.all(:select => 'id').map{|p| p.id}
    ids = self.default_issue_status_ids
    ids2 = self.issue_status_ids_for(project_ids)
    ids.merge(ids2)
  end

  # Fetch the preferred IssueStatus models for a project model.
  #
  # If there are none (in this model), fetch the default ones.

  def self.issue_statuses_for project
    ids = self.issue_status_ids_for(project.id)
    if ids.empty? then
      ids = self.default_issue_status_ids
    end
    IssueStatus.find(ids.keys)
  end

end
