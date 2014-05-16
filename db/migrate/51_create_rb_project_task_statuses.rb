class CreateRbProjectTaskStatuses < ActiveRecord::Migration
  def self.up
    create_table :rb_project_task_statuses do |t|
      t.column :project_id, :integer
      t.column :issue_status_id, :integer
    end
  end

  def self.down
    drop_table :rb_project_task_statuses
  end
end
