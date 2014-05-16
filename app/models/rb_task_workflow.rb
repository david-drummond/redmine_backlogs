require 'set'

# This subclass of Workflow represents workflows for
# RbSprintTaskTracker.
#
# It's RbTaskWorkflow's job to ensure we have the right number of
# workflows to support 1) the default task statuses and 2) per-project
# task statuses that override the defaults in 1). See
# RbProjectTaskStatus model.

class RbTaskWorkflow < WorkflowRule

  # Generate a uniquely characterising id for a workflow.

  def self.wid tracker_id,role_id,old_id,new_id
    "%s-%s-%s-%s" % [tracker_id,role_id,old_id,new_id]
  end

  # Unpack a wid into a hash that could be used with 'find'.
  #
  # See self.wid.

  def self.wid_unpack wid
    arr = wid.split('-')
    {
      :tracker_id => arr[0].to_i,
      :role_id => arr[1].to_i,
      :old_status_id => arr[2].to_i,
      :new_status_id => arr[3].to_i
    }
  end

  # Fetch all existing workflows for RbSprintTaskTracker.

  def self.all
    self.find(:all,
              :conditions => {
                :tracker_id => RbSprintTaskTracker.id})
  end

  # Return wid for this workflow.
  #
  # See self.wid.

  def wid
    self.class.wid(
      self.tracker_id,
      self.role_id,
      self.old_status_id,
      self.new_status_id
    )
  end

  # Insert missing workflows, remove unused for RbSprintTaskTracker.
  #
  # Returns array of saved Workflow objects.
  #
  # See missing_workflows for what determines a missing workflow.
  # Unused workflows are also destroyed.

  def self.synchronize!
    self.unused_workflows.each{|w|
      w = WorkflowRule.find(:first,:conditions => w)
      w.destroy if w
    }
    self.missing_workflows.map{|w|
      w = WorkflowRule.new(w)
      w.save!
      w
    }
  end

  # Find workflows that exist but which are no longer used.
  #
  # Returns array of hashes in 'wid_unpack' format.

  def self.unused_workflows
    all = self.all.map{|w|w.wid}
    required = self.required_workflows.map{|w|w[:wid]}
    sall = Set.new(all)
    sreq = Set.new(required)
    sdelete = sall-sreq
    sdelete.map {|wid|
      self.wid_unpack(wid)
    }.compact
    
  end

  # Return array of any workflows that should be added to the tracker.
  #
  # Returns array of hashes in 'wid_unpack' format.

  def self.missing_workflows
    all = self.all.map{|w|w.wid}
    required = self.required_workflows.map{|w|w[:wid]}
    sall = Set.new(all)
    sreq = Set.new(required)
    smissing = sreq-sall
    smissing.map {|wid|
      self.wid_unpack(wid)
    }.compact

  end

  # Returns all the workflows we *should* have for
  # RbSprintTaskTracker.
  #
  # Returns in same format as self.permute_workflows (including the
  # additional wid key).
  #
  # We require workflows for:
  # - The default tracker statuses (which get altered
  #   on the main backlogs settings page).
  #   See Backlogs.setting[:default_task_statuses].
  # - A project has overridden the defaults and has
  #   specified its own issue statuses.
  # This is done for all roles defined required by RbSprintTaskTracker.

  def self.required_workflows
    ids = RbProjectTaskStatus.all_issue_status_ids.keys
    roles = RbSprintTaskTracker.roles
    role_ids = roles.map{|r|r.id}
    tracker_id = RbSprintTaskTracker.id
    self.permute_workflows(tracker_id,ids,role_ids)
  end

  # Generate all combinations of workflows for a given tracker id,
  # role ids and an array of possible states.
  #
  # Returns array of hashes in 'wid_unpack' format BUT with additional
  # 'wid' key added.

  def self.permute_workflows tracker_id,status_ids,role_ids

    gen = proc{|status_id1,status_id2|
      role_ids.map {|role_id|
        attr = {
          :tracker_id => tracker_id,
          :old_status_id => status_id1,
          :new_status_id => status_id2,
          :role_id => role_id,
          :wid => self.wid(tracker_id,role_id,status_id1,status_id2)
        }
      }
    }

    status_ids.permutation(2).inject([]){|arr,comb2|
      arr.concat(gen.call(comb2[0],comb2[1]))
    }

  end

end
