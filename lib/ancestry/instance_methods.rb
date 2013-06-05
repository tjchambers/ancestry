module Ancestry
  module InstanceMethods
    # Validate that the ancestors don't include itself
    def ancestry_exclude_self
      errors.add(:base, "#{self.class.name.humanize} cannot be a descendant of itself.") if ancestor_ids.include? self.id
    end

    # Update descendants with new ancestry
    def update_descendants_with_new_ancestry
      # Skip this if callbacks are disabled
      unless ancestry_callbacks_disabled?
        # If node is not a new record and ancestry was updated and the new ancestry is sane ...
        if changed.include?(self.base_class.ancestry_column.to_s) && !new_record? && sane_ancestry?
          # ... for each descendant ...
          unscoped_descendants.each do |descendant|
            # ... replace old ancestry with new ancestry
            descendant.without_ancestry_callbacks do
              descendant.update_attribute(
                self.base_class.ancestry_column,
                descendant.read_attribute(descendant.class.ancestry_column).gsub(
                  /^#{self.child_ancestry}/,
                  if read_attribute(self.class.ancestry_column).blank? then id.to_s else "#{read_attribute self.class.ancestry_column }/#{id}" end
                )
              )
            end
          end
        end
      end
    end
     
    # Apply orphan strategy
    def apply_orphan_strategy
      # Skip this if callbacks are disabled
      unless ancestry_callbacks_disabled?
        # If this isn't a new record ...
        unless new_record?
          # ... make all children root if orphan strategy is rootify
          if self.base_class.orphan_strategy == :rootify
            unscoped_descendants.each do |descendant|
              descendant.without_ancestry_callbacks do
                descendant.update_attribute descendant.class.ancestry_column, (if descendant.ancestry == child_ancestry then nil else descendant.ancestry.gsub(/^#{child_ancestry}\//, '') end)
              end
            end
          # ... destroy all descendants if orphan strategy is destroy
          elsif self.base_class.orphan_strategy == :destroy
            unscoped_descendants.each do |descendant|
              descendant.without_ancestry_callbacks do
                descendant.destroy
              end
            end
          # ... make child elements of this node, child of its parent if orphan strategy is adopt
          elsif self.base_class.orphan_strategy == :adopt
            descendants.all.each do |descendant|
              descendant.without_ancestry_callbacks do
                new_ancestry = descendant.ancestor_ids.delete_if { |x| x == self.id }.join('/')
                descendant.update_attribute descendant.class.ancestry_column, new_ancestry || nil
              end
            end
          # ... throw an exception if it has children and orphan strategy is restrict
          elsif self.base_class.orphan_strategy == :restrict
            raise Ancestry::AncestryException.new('Cannot delete record because it has descendants.') unless is_childless?
          end
        end
      end
    end

    # The ancestry value for this record's children
    def child_ancestry
      # New records cannot have children
      raise Ancestry::AncestryException.new('No child ancestry for new record. Save record before performing tree operations.') if new_record?

      if self.send("#{self.base_class.ancestry_column}_was").blank? then id.to_s else "#{self.send "#{self.base_class.ancestry_column}_was"}".split(',').first + "/#{id}" end
    end

    # Ancestors
    def ancestor_ids
      read_attribute(self.base_class.ancestry_column).to_s.split(%r|[,/]|).uniq.map { |id| cast_primary_key(id) }
    end

    def ancestor_conditions
      {self.base_class.primary_key => ancestor_ids}
    end

    def ancestors(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).scoped :conditions => ancestor_conditions
    end

    def path_ids
      ancestor_ids + [id]
    end

    def path_conditions
      {self.base_class.primary_key => path_ids}
    end

    def path(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).scoped :conditions => path_conditions
    end

    def lineage_ids
      ancestor_ids + subtree_ids
    end

    def lineage_conditions
      {self.base_class.primary_key => lineage_ids}
    end

    def lineage(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).scoped :conditions => lineage_conditions
    end

    def depth
      ancestor_ids.size
    end

    def cache_depth
      write_attribute self.base_class.depth_cache_column, depth
    end

    # Parent
    def parent=(parent)
      write_attribute(self.base_class.ancestry_column, if parent.blank? then
                                                         nil
                                                       else
                                                         parent.child_ancestry
                                                       end)
    end

    def parent_id=(parent_id)
      self.parent = if parent_id.blank? then
                      nil
                    else
                      unscoped_find(parent_id)
                    end
    end

    def branches
      if ancestor_ids.empty? then nil else read_attribute(self.base_class.ancestry_column).to_s.split(',') end
    end

    def parent_ids
      if ancestor_ids.empty? then nil else branches.map { |branch| cast_primary_key(branch.split('/').last) } end
    end

    def parents
      if is_root? then nil else unscoped_find(parent_ids) end
    end

    def has_parent?
      !is_root?
    end

    # Root
    def root_id
      if ancestor_ids.empty? then id else branches.first.split('/').first end
    end

    def root
      if root_id == id then self else unscoped_find(root_id) end
    end

    def is_root?
      read_attribute(self.base_class.ancestry_column).blank?
    end


    # Descendants
    def descendant_conditions
      column = "#{self.base_class.table_name}.#{self.base_class.ancestry_column}"
      lookup = if has_parent? then "%/#{id}" else "#{id}" end
      ["#{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} = ?", "#{lookup}","#{lookup}/%", "#{lookup},%", ",#{id}", "#{id}"]
    end

    def descendants(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).scoped :conditions => descendant_conditions
    end

    def descendant_ids(depth_options = {})
      descendants(depth_options).all(:select => self.base_class.primary_key).collect(&self.base_class.primary_key.to_sym)
    end

    # Subtree
    def subtree_conditions
      column = "#{self.base_class.table_name}.#{self.base_class.ancestry_column}"
      lookup = if has_parent? then "%/#{id}" else "#{id}" end
      ["#{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} like ?
        or #{column} = ?
        or #{self.base_class.table_name}.#{self.base_class.primary_key} = ?", "#{lookup}","#{lookup}/%", "#{lookup},%", ",#{id}", "#{id}", "#{id}"]
     end

    def subtree(depth_options = {})
      self.base_class.scope_depth(depth_options, depth).scoped :conditions => subtree_conditions
    end

    def subtree_ids(depth_options = {})
      subtree(depth_options).all(:select => self.base_class.primary_key).collect(&self.base_class.primary_key.to_sym)
    end

    # Callback disabling
    def without_ancestry_callbacks
      @disable_ancestry_callbacks = true
      yield
      @disable_ancestry_callbacks = false
    end

    def ancestry_callbacks_disabled?
      !!@disable_ancestry_callbacks
    end

  private

    def cast_primary_key(key)
      if primary_key_type == :string
        key
      else
        key.to_i
      end
    end

    def primary_key_type
      @primary_key_type ||= column_for_attribute(self.class.primary_key).type
    end
    def unscoped_descendants
      self.base_class.unscoped do
        self.base_class.all(:conditions => descendant_conditions) 
      end
    end
    
    # basically validates the ancestry, but also applied if validation is
    # bypassed to determine if children should be affected
    def sane_ancestry?
      ancestry.nil? || (ancestry.to_s =~ Ancestry::ANCESTRY_PATTERN && !ancestor_ids.include?(self.id))
    end
    
    def unscoped_find(id)
      self.base_class.unscoped { self.base_class.find(id) }
    end
  end
end
