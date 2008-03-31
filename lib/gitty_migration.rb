module ActiveRecord
  class Migrator
    def migrate
      migration_classes.each do |migration_class|
        if reached_target_version?(migration_class.version)
          Base.logger.info("Reached target version: #{@target_version}")
          break
        end
        next if irrelevant_migration?(migration_class.version)
        Base.logger.info "Migrating to #{migration_class} (#{migration_class.version})"
        migration_class.migrate(@direction, migration_class.version)
        set_schema_version(migration_class.version)
      end
    end
  end
end

module GittyMigration
  
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
        
    def use_git(options={})
      @@options = options
      class_eval do
        class << self
          alias_method_chain :migrate, :git
        end
      end
    end

    def migrate_with_git(direction, version)
      settings = MigrationSettings.new(
        :version => version,
        :klass => self.to_s.underscore,
        :revision => @@options[:revision]
      )
      before_migrate(settings) 
      migrate_without_git(direction)
      after_migrate(settings)
    end

    def before_migrate(settings)
      begin
        g = settings.git
        # Find the commit that matches your sha1
        commit = g.gcommit("#{settings.revision}")
        # Will throw an error if the commit isn't known. Bit of a hack :(
        commit.gtree
        
        say "Migrating with git"
        say "SHA1: #{settings.revision}"
        say "AUTHOR: #{settings.revision_author}"
        say "DATE: #{settings.revision_date}"
        say "MESSAGE: #{settings.revision_message}"
      rescue
        say "WARNING => Could not find git sha1 that matches '#{settings.revision}'. The migration will continue without gitty migrations"
      else
        # Stash any changes that you may have in your current branch
        g.branch(settings.original_branch).stashes.save(settings.revision) if settings.stash?
        # Checkout a new branch to use for your migration
        g.branch(settings.migration_branch).checkout
        # Rollback to the commit that you wanted
        g.reset_hard(commit)
      end
    end
    
    def after_migrate(settings)
      say "Done migration. Switching back to your normal branch"
      g = settings.git
      # Checkout your original branch
      g.branch(settings.original_branch).checkout
      # Apply your stash if you have one
      g.branch(settings.original_branch).stashes.apply if settings.stash?
      # Clear your stashes if you have only the one that we used
      # g.branch(m[:original_branch]).stashes.clear if @@gitty_migration[:clear_stash]
      # Delete the branch that you used for the migration
      g.branch(settings.migration_branch).delete
      # If we've already deleted the branch, then don't revert again
      # revert_to_original will be called in the after migrate even if we couldn't find the commit
    end
    
  end
end
