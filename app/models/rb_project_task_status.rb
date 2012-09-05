# Model to represent a project's preferred sprint task statuses
# for use on the taskboard.
#
# By default, projects start with none and will use the default
# task statuses that are specified in the main Backlogs pluging
# configuration page.
#
# Note: RbSprintTaskTracker will need to be told when a project
# changes its preferred task statuses here so that it can update
# itself.

class RbProjectTaskStatus < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :issue_status

  # Update (sprint) task statuses for a given project.

  def self.update! project_id, issue_status_ids=[]
    self.delete_all({:project_id => project_id})
    unless issue_status_ids.empty? then
      issue_status_ids.each {|i|
        self.create!(:project_id => project_id,:issue_status_id => i)
      }
    end
  end
end
