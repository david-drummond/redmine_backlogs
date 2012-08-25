# Tracker used for sprint tasks and for the taskboard.
#
# This class subclasses Tracker and adds some functionality
# to allow us to have more choice in determining the columns
# that show on the taskboard.

class RbSprintTaskTracker < Tracker
  unloadable

  def self.id
    Backlogs.setting[:task_tracker]
  end

  # Return an instance of the tracker for backlogs.
  #
  # Use this instead of finding it.
  # We're using a similar naming convention to singleton pattern.

  def self.instance
    self.find(self.id)
  end
end
