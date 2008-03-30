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
    base.class_eval do
      class << self
        alias_method_chain :migrate, :git
      end
    end
  end
  
  module ClassMethods
    
    @@gitty_migration ||= {}
    @@gitty_migration[:enabled] = false
        
    def use_git_revision(revision_name=nil)
      g = Git.open("#{RAILS_ROOT}")
      raise "Couldn't find the .git directory. Does this project use git?" if g.nil?
  
      # TODO
      # See if there are any stashes already. If there arent' then set a flag to clear the stash after we are done.
      @@gitty_migration[:git] = g
      @@gitty_migration[:enabled] = true
      @@gitty_migration[:stash] = (g.status.changed.size > 0) ? true : false
      @@gitty_migration[:clear_stash] = (g.branch.stashes.size > 0) ? true : false
      @@gitty_migration[:branch] = "smart_migration_".concat Digest::MD5.hexdigest("#{Time.now}-#{revision_name}")
      @@gitty_migration[:revision] = revision_name
      @@gitty_migration[:original_branch] = g.branch.name
    end

    def migrate_with_git(direction, migration_version)      
      before_migrate(migration_version) if @@gitty_migration[:enabled] == true
      migrate_without_git(direction)
      after_migrate if @@gitty_migration[:enabled] == true
    end

    def before_migrate(migration_version)
      m = @@gitty_migration
      if m[:enabled]
        g = m[:git]
        
        if m[:revision].nil?
          filename = "#{migration_version}_#{self.to_s.underscore}.rb"
          file = Dir["db/migrate/0*#{filename}"].first
          commit = g.log(1000).object(file).each{|c|c}.reverse.first
          #puts commit.author.name
          #puts commit.author.email
          #puts commit.author.date.to_s
          #puts commit.sha
          @@gitty_migration[:revision] = commit.sha
        end
        
        say "Migrating with git revision #{m[:revision]}"
        
        g.branch(m[:original_branch]).stashes.save(m[:revision]) if @@gitty_migration[:stash]
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
      m = @@gitty_migration
      if m[:enabled]
        say "Done migration. Switching back to your normal branch"
        g = @@gitty_migration[:git]
        g.branch(m[:original_branch]).checkout
        g.branch(m[:original_branch]).stashes.apply if @@gitty_migration[:stash]
        # g.branch(m[:original_branch]).stashes.clear if @@gitty_migration[:clear_stash]
        g.branch(m[:branch]).delete
        # If we've already deleted the branch, then don't revert again
        # revert_to_original will be called in the after migrate even if we couldn't find the commit
        @@gitty_migration[:enabled] = false
      end
    end
    
  end
end
