module GittyMigrator
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
