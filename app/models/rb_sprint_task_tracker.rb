# Tracker used for sprint tasks and for the taskboard.
#
# This class subclasses Tracker and adds some functionality
# to allow us to have more choice in determining the columns
# that show on the taskboard.

class RbSprintTaskTracker < Tracker
  unloadable

  def self.id
    Backlogs.setting[:task_tracker].to_i
  end

  # Return an instance of the tracker for backlogs.
  #
  # Use this instead of finding it.
  # We're using a similar naming convention to singleton pattern.

  def self.instance
    self.find(self.id)
  end

  # Fetch all roles that can have workflows for sprint task statuses.
  #
  # TODO: we just fetch all non-builtins atm.

  def roles
    roles = ::Role.all.delete_if{|r| r.builtin? }
  end

  # Fetch the "used" issue statuses for this tracker.
  #
  # If project is not specified, then the default sprint task statuses
  # will be returned. If project is specified, then return the
  # statuses used for this project. If the project doesn't override
  # the default statuses, then these will be returned.

  def issue_statuses project=nil
    if project.nil? then
      defaults = Backlogs.setting[:default_task_statuses]
      ids = defaults.keys.map{|k| k.to_i }
      IssueStatus.find(ids)
    else
      # TODO
      []
    end
  end

  # Insert missing workflows.

  def update_workflows
    missing_workflows.each{|w|
      w.save!
    }
  end

  # Return array of any workflows that should be added to the tracker.
  #
  # The workflows are instantiated but not saved to database.
  #
  # Additions may be required because:
  # - the default tracker statuses have been altered
  #   See Backlogs.setting[:default_task_statuses]
  # - a project has overridden the defaults
  # This is done for all roles at the moment.

  def missing_workflows
    result = []

    # Check for missing default task statuses:
    ids = self.issue_statuses.map{|i|i.id}
    ids.combination(2).each{|comb2|
      result.concat(workflows_for(*comb2))
    }

    # TODO: check for per-project statuses.
    # for each project
    # - find sprint task issue statuses
    #   which aren't already in default
    #   or each other

    result.select{|w|!w[1]}.map{|w| Workflow.new(w[0])}
  end

  # Determine all possible workflows for 2 issue statuses (for all
  # roles) and if they need to be inserted into the database.
  # 
  # Returns:
  #   [wflow1,wflow2,...]
  # where
  #   wflowN is [{:tracker_id => ...,...},bool]
  # If bool is false, record is NOT in database.

  def workflows_for status_id1,status_id2
    workflows = []
    roles = self.roles
    add = proc{|status_id1,status_id2|
      roles.map {|role|
        attr = {
          :tracker_id => self.id,
          :old_status_id => status_id1,
          :new_status_id => status_id2,
          :role_id => role.id
        }
        if Workflow.exists?(attr) then
          [attr,true]
        else
          [attr,false] # Not in database.
        end
      }
    }
    workflows.concat(add.call(status_id1,status_id2))
    workflows.concat(add.call(status_id2,status_id1))
    workflows
  end

end
