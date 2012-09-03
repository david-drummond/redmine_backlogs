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
  # TODO: we just fetch all non-builtins atm; we don't really
  # worry about what non-builtins can or can't do at this point;
  # we just do a blanket update.

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

    # Grab default ids.
    if project.nil? then
      defaults = Backlogs.setting[:default_task_statuses]
      ids = defaults.keys.map{|k| k.to_i }
      IssueStatus.find(ids)

    # Grab project specific status.
    else
      # TODO
      []
    end

  end

  # Insert missing workflows.
  #
  # Returns array of saved Workflow objects.
  #
  # See missing_workflows for what determines a missing workflow.
  # 
  # TODO: delete workflows that should no longer apply (if they
  # are not included in the defaults or in any projects that override
  # the defaults)?

  def update_workflows
    missing_workflows.map{|w|
      w = Workflow.new(w[0])
      w.save!
      w
    }
  end

  # Return array of any workflows that should be added to the tracker.
  #
  # Returns in the same format as workflows_for.

  def missing_workflows
    self.required_workflows.select{|w|!w[1]}
  end

  # Returns all the workflows we *should* have.
  #
  # Returns in the same format as workflows_for.
  #
  # We require workflows for:
  # - The default tracker statuses (which get altered
  #   on the main backlogs settings page).
  #   See Backlogs.setting[:default_task_statuses].
  # - A project has overridden the defaults and has
  #   specified its own issue statuses.
  # This is done for all roles at the moment.
  # 
  # TODO: check for per-project statuses.

  def required_workflows
    result = []
    # Check for missing default task statuses:
    ids = self.issue_statuses.map{|i|i.id}
    ids.combination(2).each{|comb2|
      result.concat(workflows_for(*comb2))
    }
    result
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
