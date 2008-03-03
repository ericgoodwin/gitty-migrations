module SmartMigration
  
  def self.included(base)
    base.extend ClassMethods
    base.class_eval do
      class << self
        alias_method_chain :migrate, :git
      end
    end
  end
  
  module ClassMethods
    
    @@smart_migration ||= {}
    @@smart_migration[:run] = false
        
    def use_git_revision(revision_name)
      g = Git.open("#{RAILS_ROOT}")
      raise "Couldn't find the .git directory. Does this project use git?" if g.nil?
      @@smart_migration[:run] = true
      @@smart_migration[:git] = g
      @@smart_migration[:branch] = "smart_migration_".concat Digest::MD5.hexdigest("#{Time.now}-#{revision_name}")
      @@smart_migration[:revision] = revision_name
      @@smart_migration[:original_branch] = @@smart_migration[:git].branch.name
    end

    def migrate_with_git(direction)
      before_migrate if @@smart_migration[:run] == true
      migrate_without_git(direction)
      after_migrate if @@smart_migration[:run] == true
    end

    def before_migrate
      m = @@smart_migration
      if m[:run]
        say "Migrating with git revision #{m[:revision]}"
        g = m[:git]
        g.branch(m[:original_branch]).stashes.save(m[:revision])
        g.branch(m[:branch]).checkout
        commit = g.gcommit("#{m[:revision]}")

        # If we can't find the commit, 
        # let the user know and revert back to the original branch
        if commit.nil?
          say "Could not find git revision #{m[:revision]}. Using HEAD"
          revert_to_original
        else
          g.reset_hard(commit)
        end
        
      end
    end

    def after_migrate
      revert_to_original
    end

    def revert_to_original
      m = @@smart_migration
      if m[:run]
        say "Done migration. Switching back to your normal branch"
        g = @@smart_migration[:git]
        g.branch(m[:original_branch]).checkout
        g.branch(m[:original_branch]).stashes.apply
        g.branch(m[:branch]).delete
        # If we've already deleted the branch, then don't revert again
        # revert_to_original will be called in the after migrate even if we couldn't find the commit
        @@smart_migration[:run] = false
      end
    end
    
  end
end
