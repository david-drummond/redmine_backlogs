require 'set'

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

  # Insert missing workflows, remove unused.
  #
  # Returns array of saved Workflow objects.
  #
  # See missing_workflows for what determines a missing workflow.
  # Unused workflows are also destroyed.

  def synchronize!
    self.unused_workflows.each{|w|
      w = Workflow.find(:first,:conditions => w[0])
      w.destroy if w
    }
    self.missing_workflows.map{|w|
      w = Workflow.new(w[0])
      w.save!
      w
    }
  end

  # Find workflows that exist but which are no longer used.
  #
  # Returns in the same format as workflows_for.
  #
  # TODO: eek, heavy, long, complicated.

  def unused_workflows

    # Create a unique id (wid) for workflows (without using the
    # database id).
    hashw = lambda {|tracker_id,role_id,old_id,new_id|
      "%s-%s-%s-%s" % [tracker_id,role_id,old_id,new_id]
    }

    # Turn a wid into hash.
    unhashw = lambda {|wid|
      arr = wid.split('-')
      {
        :tracker_id => arr[0].to_i,
        :role_id => arr[1].to_i,
        :old_status_id => arr[2].to_i,
        :new_status_id => arr[3].to_i
      }
    }

    # Get all existing workflows for this tracker:
    all = Workflow.find(:all, :conditions => { :tracker_id => self.id })
    all = all.map {|w|
      hashw.call(w.tracker_id,
                 w.role_id,
                 w.old_status_id,
                 w.new_status_id)
    }

    # Get all required workflows for this tracker:
    required = self.required_workflows.map {|w|
      hashw.call(
        w[0][:tracker_id],
        w[0][:role_id],
        w[0][:old_status_id],
        w[0][:new_status_id]
      )
    }

    # Find unused:
    sall = Set.new(all)
    sreq = Set.new(required)
    sdelete = sall-sreq
    sdelete.map {|wid|
      [unhashw.call(wid),true]
    }.compact
    
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

  def required_workflows
    result = []
    ids = RbProjectTaskStatus.all_issue_status_ids.keys
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
