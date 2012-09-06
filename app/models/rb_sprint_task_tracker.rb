# Tracker used for sprint tasks and for the taskboard.
#
# It represents the sprint task tracker used in Backlogs.
# Call RbSprintTaskTracker.instance to get it.

class RbSprintTaskTracker < Tracker
  unloadable

  def self.id
    Backlogs.setting[:task_tracker].to_i
  end
  
  # Return an instance of the tracker for backlogs.

  def self.instance
    self.find(self.id)
  end

  # Fetch all roles that can have workflows for sprint task statuses.
  #
  # TODO: we just fetch all non-builtins atm; 
  # we just assume all non-builtins have equal rights in managing
  # the workflow.

  def self.roles
    roles = ::Role.all.delete_if{|r| r.builtin? }
  end


end
