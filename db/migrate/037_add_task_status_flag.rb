require 'benchmark'

# Add column to issue_statuses table to flag which issue_statuses will
# be used for tasks on the taskboard.

class AddTaskStatusFlag < ActiveRecord::Migration
  def self.up
    add_column :issue_statuses, :rb_task_status, :boolean
  end

  def self.down
    remove_column :issue_statuses, :rb_task_status
  end
end
