require 'fileutils'
require 'benchmark'

namespace :redmine do
  namespace :backlogs do

    desc "Install and configure Redmine Backlogs"
    task :install => :environment do |t|
      raise "You must specify the RAILS_ENV ('rake redmine:backlogs:install RAILS_ENV=production' or 'rake redmine:backlogs:install RAILS_ENV=development')" unless ENV["RAILS_ENV"]

      raise "You must set the default issue priority in redmine prior to installing backlogs" unless IssuePriority.default

      begin
        Rails.cache.clear
      rescue NoMethodError
        puts "** WARNING: Automatic cache delete not supported by #{Rails.cache.class}, please clear manually **"
      rescue SystemCallError
        puts "Cache directory is not found"
      end

      Backlogs.gems.each_pair {|gem, installed|
        raise "You are missing the '#{gem}' gem" unless installed
      }

      puts Backlogs.platform_support(true)

      # Necessary because adding key-value pairs one by one doesn't seem to work
      Backlogs.setting[:points_burn_direction] ||= 'down'
      Backlogs.setting[:wiki_template] ||= ''

      puts "\n"
      puts "====================================================="
      puts "             Redmine Backlogs Installer"
      puts "====================================================="
      puts "Installing to the #{ENV['RAILS_ENV']} environment."

      if ! ['no', 'false'].include?("#{ENV['labels']}".downcase)
        print "Fetching card labels from http://git.gnome.org..."
        STDOUT.flush
        begin
          BacklogsPrintableCards::CardPageLayout.update
          print "done!\n"
        rescue Exception => fetch_error
          print "\nCard labels could not be fetched (#{fetch_error}). Please try again later. Proceeding anyway...\n"
        end
      else
        if ! File.exist?(File.dirname(__FILE__) + '/../labels.yaml')
          print "Default labels installed\n"
          FileUtils.cp(File.dirname(__FILE__) + '/../labels.yaml.default', File.dirname(__FILE__) + '/../labels.yaml')
        end
      end

      if BacklogsPrintableCards::CardPageLayout.selected.blank? && BacklogsPrintableCards::CardPageLayout.available.size > 0 
        Backlogs.setting[:card_spec] = BacklogsPrintableCards::CardPageLayout.available[0]
      end

      trackers = Tracker.find(:all)

      if ENV['story_trackers'] && ENV['story_trackers'] != ''
        trackers =  ENV['story_trackers'].split(',')
        trackers.each{|name|
          if ! Tracker.find(:first, :conditions => ["name=?", name])
            puts "Creating story tracker '#{name}'"
            tracker = Tracker.new(:name => name)
            tracker.save!
          end
        }
        Backlogs.setting[:story_trackers] = trackers.collect{|n| Tracker.find_by_name(n).id }
      else
        if RbStory.trackers.length == 0
          puts "Configuring story and task trackers..."
          invalid = true
          while invalid
            puts "-----------------------------------------------------"
            puts "Which trackers do you want to use for your stories?"
            trackers.each_with_index { |t, i| puts "  #{ i + 1 }. #{ t.name }" }
            print "Separate values with a space (e.g. 1 3): "
            STDOUT.flush
            selection = (STDIN.gets.chomp!).split(/\D+/)

            # Check that all values correspond to an items in the list
            invalid = false
            invalid_value = nil
            tracker_names = []
            selection.each do |s|
              if s.to_i > trackers.length
                invalid = true
                invalid_value = s
                break
              else
                tracker_names << trackers[s.to_i-1].name
              end
            end

            if invalid
              puts "Oooops! You entered an invalid value (#{invalid_value}). Please try again."
            else
              print "You selected the following trackers: #{tracker_names.join(', ')}. Is this correct? (y/n) "
              STDOUT.flush
              invalid = !(STDIN.gets.chomp!).match("y")
            end
          end

          Backlogs.setting[:story_trackers] = selection.map{ |s| trackers[s.to_i-1].id }
        end
      end

      # Get the default sprint task tracker name.
      #
      # Store it in settings if necessary.
      # TODO: put the ENV setting back?

      default_name = Backlogs.setting[:default_sprint_task_tracker_name]
      if default_name.blank? then
        config_dir  = File.join(File.dirname(__FILE__),'../../config')
        config_file = File.join(config_dir,'config.yml')
        config_file = File.expand_path(config_file)
        if File.exists?(config_file) then
          config = YAML.load_file(config_file)
          default_name = config[:default_sprint_task_tracker_name]
          Backlogs.setting[:default_sprint_task_tracker_name] = default_name
        else
          # This shouldn't happen as we are commiting the yml file.
          puts "Can't find backlogs config.yml (#{config_file})"
          default_name = 'Sprint Task'
          Backlogs.setting[:default_sprint_task_tracker_name] = default_name
        end
      end

      # Create or get sprint task tracker and assign it to

      tracker = create_new_tracker(default_name)
      Backlogs.setting[:task_tracker] = tracker.id

      puts "Story and task trackers are now set."

      print "Migrating the database..."
      STDOUT.flush
      if Backlogs.platform == :redmine && Redmine::VERSION::MAJOR > 1
        db_migrate_task = "redmine:plugins:migrate"
      else
        db_migrate_task = "db:migrate:plugins"
      end
      system("rake #{db_migrate_task} --trace > redmine_backlogs_install.log")
      system('rake redmine:backlogs:fix_positions --trace >> redmine_backlogs_install.log')
      if $?==0
        puts "done!"
        puts "Installation complete. Please restart Redmine."
        puts "Thank you for trying out Redmine Backlogs!"
      else
        puts "ERROR!"
        puts "*******************************************************"
        puts " Whoa! An error occurred during database migration."
        puts " Please see redmine_backlogs_install.log for more info."
        puts "*******************************************************"
      end
    end

    # Create sprint task tracker.

    def create_new_tracker default_name
      yes = proc {|prompt|
        print(prompt + ' [y/n]: ')
        response = STDIN.readline.chomp
        /^y$/i === response
      }
      get_name = proc {|default|
        print "Enter name for sprint task tracker ['#{default}']: "
        response = STDIN.readline.chomp
        if response.blank? then
          default
        else
          response
        end
      }
      create = proc {|name|
        puts "Creating sprint task tracker: '#{name}'"
        tracker = RbSprintTaskTracker.new(:name => name)
        tracker.save!
        tracker
      }

      name = get_name.call(default_name)

      if RbSprintTaskTracker.exists?(:name => name) then
        begin
          puts "Sprint task tracker '#{name}' already exists!"
          if yes.call('Use this?') then
            return RbSprintTaskTracker.find_by_name(name)
          end
          name = get_name.call(default_name)
        end while RbSprintTaskTracker.exists?(:name => name)
      end
      tracker = create.call(name)
    end

    desc "Create the sprint task tracker"
    task :create_sprint_tracker => :environment do |t|
      default_name = Backlogs.setting[:default_sprint_task_tracker_name]
      tracker = create_new_tracker(default_name)
      Backlogs.setting[:task_tracker] = tracker.id

      p tracker
    end

  end
end
