require "environment"

class HasAncestryTreeTest < ActiveSupport::TestCase
  
  def test_default_ancestry_column
    AncestryTestDatabase.with_model do |model|
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_non_default_ancestry_column
    AncestryTestDatabase.with_model :ancestry_column => :alternative_ancestry do |model|
      assert_equal :alternative_ancestry, model.ancestry_column
    end
  end

  def test_setting_ancestry_column
    AncestryTestDatabase.with_model do |model|
      model.ancestry_column = :ancestors
      assert_equal :ancestors, model.ancestry_column
      model.ancestry_column = :ancestry
      assert_equal :ancestry, model.ancestry_column
    end
  end

  def test_default_orphan_strategy
    AncestryTestDatabase.with_model do |model|
      assert_equal :destroy, model.orphan_strategy
    end
  end
 

  def test_setting_orphan_strategy
    AncestryTestDatabase.with_model do |model|
      model.orphan_strategy = :destroy
      assert_equal :destroy, model.orphan_strategy
    end
  end
 
  def test_scoping_in_callbacks
    AncestryTestDatabase.with_model do |model|
      $random_object = model.create

      model.instance_eval do
        after_create :after_create_callback
      end
      model.class_eval do
        def after_create_callback
          # We don't want to be in the #children scope here when creating the child
           
          self.parent_id = $random_object.id if $random_object
          self.root
        end
      end

      parent = model.create
      assert child = parent.descendants.create
    end
  end

  def test_setup_test_nodes
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      assert_equal Array, roots.class
      assert_equal 3, roots.length
      roots.each do |node, children|
        assert_equal model, node.class
        assert_equal Array, children.class
        assert_equal 3, children.length
        children.each do |node, children|
          assert_equal model, node.class
          assert_equal Array, children.class
          assert_equal 3, children.length
          children.each do |node, children|
            assert_equal model, node.class
            assert_equal Array, children.class
            assert_equal 0, children.length
          end
        end
      end
    end
  end

  def test_tree_navigation
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        # Ancestors assertions
        assert_equal [], lvl0_node.ancestor_ids
        assert_equal [], lvl0_node.ancestors
        assert_equal [lvl0_node.id], lvl0_node.path_ids
        assert_equal [lvl0_node], lvl0_node.path
        assert_equal 0, lvl0_node.depth
        # Parent assertions
        assert_equal nil, lvl0_node.parents

        # lineage assertions
        assert_equal lvl0_node.subtree_ids, lvl0_node.lineage_ids
        assert_equal lvl0_node.subtree.to_a, lvl0_node.lineage.to_a

        # Root assertions
        assert_equal lvl0_node.id, lvl0_node.root_id
        assert_equal lvl0_node, lvl0_node.root
        assert lvl0_node.is_root?
 
      
        # Descendants assertions
        descendants = model.all.find_all do |node|
          node.ancestor_ids.include? lvl0_node.id
        end
        assert_equal descendants.map(&:id), lvl0_node.descendant_ids
        assert_equal descendants, lvl0_node.descendants
        assert_equal [lvl0_node] + descendants, lvl0_node.subtree

        lvl0_children.each do |lvl1_node, lvl1_children|
          # Ancestors assertions
          assert_equal [lvl0_node.id], lvl1_node.ancestor_ids
          assert_equal [lvl0_node], lvl1_node.ancestors
          assert_equal [lvl0_node.id, lvl1_node.id], lvl1_node.path_ids
          assert_equal [lvl0_node, lvl1_node], lvl1_node.path
          assert_equal 1, lvl1_node.depth

          # lineage assertions
      

          # Parent assertions
          
          assert_equal lvl0_node, lvl1_node.parents.first
          # Root assertions
          assert_equal lvl0_node.id, lvl1_node.root_id.to_i
          assert_equal lvl0_node, lvl1_node.root
          assert !lvl1_node.is_root?
 
          # Descendants assertions
          descendants = model.all.find_all do |node|
            node.ancestor_ids.include? lvl1_node.id
          end
          assert_equal descendants.map(&:id), lvl1_node.descendant_ids
          assert_equal descendants, lvl1_node.descendants
          assert_equal [lvl1_node] + descendants, lvl1_node.subtree

          lvl1_children.each do |lvl2_node, lvl2_children|
            # Ancestors assertions
            assert_equal [lvl0_node.id, lvl1_node.id], lvl2_node.ancestor_ids
            assert_equal [lvl0_node, lvl1_node], lvl2_node.ancestors
            assert_equal [lvl0_node.id, lvl1_node.id, lvl2_node.id], lvl2_node.path_ids
            assert_equal [lvl0_node, lvl1_node, lvl2_node], lvl2_node.path
            assert_equal 2, lvl2_node.depth
            # Parent assertions
             
            assert_equal lvl1_node, lvl2_node.parents.first
            # Root assertions
            assert_equal lvl0_node.id, lvl2_node.root_id.to_i
            assert_equal lvl0_node, lvl2_node.root
            assert !lvl2_node.is_root?
          
            # Descendants assertions
            descendants = model.all.find_all do |node|
              node.ancestor_ids.include? lvl2_node.id
            end
            assert_equal descendants.map(&:id), lvl2_node.descendant_ids
            assert_equal descendants, lvl2_node.descendants
            assert_equal [lvl2_node] + descendants, lvl2_node.subtree
          end
        end
      end
    end
  end

  def test_scopes
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      # Roots assertion
      assert_equal roots.map(&:first), model.roots

      model.where('1=1').each do |test_node|
        # Assertions for ancestors_of named scope
        assert_equal test_node.ancestors.load, model.ancestors_of(test_node).load
        assert_equal test_node.ancestors, model.ancestors_of(test_node.id)
        # Assertions for descendants_of named scope
        assert_equal test_node.descendants, model.descendants_of(test_node)
        assert_equal test_node.descendants, model.descendants_of(test_node.id)
        # Assertions for subtree_of named scope
        assert_equal test_node.subtree, model.subtree_of(test_node)
        assert_equal test_node.subtree, model.subtree_of(test_node.id)  
      end
    end
  end

  def test_ancestry_column_validation
    AncestryTestDatabase.with_model do |model|
      node = model.create
      ['3', '10/2', '1/4/30', nil].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert node.errors[model.ancestry_column].blank?
      end
      ['1/3/', '/2/3', 'a', 'a/b', '-34', '/54'].each do |value|
        node.send :write_attribute, model.ancestry_column, value
        node.valid?; assert !node.errors[model.ancestry_column].blank?
      end
    end
  end

  def test_orphan_destroy_strategy
    AncestryTestDatabase.with_model :depth => 3, :width => 3 do |model, roots|
      model.orphan_strategy = :destroy
      root = roots.first.first
      assert_difference 'model.count', -root.subtree.size do
        root.destroy
      end
      node = model.roots.first.descendants.first
      assert_difference 'model.count', -node.subtree.size do
        node.destroy
      end
    end
  end

  def test_depth_caching
    AncestryTestDatabase.with_model :depth => 3, :width => 3, :cache_depth => true, :depth_cache_column => :depth_cache do |model, roots|
      roots.each do |lvl0_node, lvl0_children|
        assert_equal 0, lvl0_node.depth_cache
        lvl0_children.each do |lvl1_node, lvl1_children|
          assert_equal 1, lvl1_node.depth_cache
          lvl1_children.each do |lvl2_node, lvl2_children|
            assert_equal 2, lvl2_node.depth_cache
          end
        end
      end
    end
  end
 

  def test_invalid_has_ancestry_options
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :this_option_doesnt_exist => 42
    end
    assert_raise Ancestry::AncestryException do
      Class.new(ActiveRecord::Base).has_ancestry :not_a_hash
    end
  end

   

  def test_exception_on_unknown_depth_column
    AncestryTestDatabase.with_model :cache_depth => true do |model|
      assert_raise Ancestry::AncestryException do
        model.create!.subtree(:this_is_not_a_valid_depth_option => 42)
      end
    end
  end

  def test_sti_support
    AncestryTestDatabase.with_model :extra_columns => {:type => :string} do |model|
      subclass1 = Object.const_set 'Subclass1', Class.new(model)
      (class << subclass1; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore).new 'Subclass1', 'subclass1'; end
      subclass2 = Object.const_set 'Subclass2', Class.new(model)
      (class << subclass2; self; end).send :define_method, :model_name do; Struct.new(:human, :underscore).new 'Subclass1', 'subclass1'; end

      node1 = subclass1.create!
      node2 = subclass2.create! :parent => node1
      node3 = subclass1.create! :parent => node2
      node4 = subclass2.create! :parent => node3
      node5 = subclass1.create! :parent => node4

      model.all.each do |node|
        assert [subclass1, subclass2].include?(node.class)
      end

      assert_equal [node2.id, node3.id, node4.id, node5.id], node1.descendants.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node1.subtree.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id], node5.ancestors.map(&:id)
      assert_equal [node1.id, node2.id, node3.id, node4.id, node5.id], node5.path.map(&:id)
    end
  end

  def test_arrange_order_option
    AncestryTestDatabase.with_model :width => 3, :depth => 3 do |model, roots|
      descending_nodes_lvl0 = model.arrange :order => 'id desc'
      ascending_nodes_lvl0 = model.arrange :order => 'id asc'

      descending_nodes_lvl0.keys.zip(ascending_nodes_lvl0.keys.reverse).each do |descending_node, ascending_node|
        assert_equal descending_node, ascending_node
        descending_nodes_lvl1 = descending_nodes_lvl0[descending_node]
        ascending_nodes_lvl1 = ascending_nodes_lvl0[ascending_node]
        descending_nodes_lvl1.keys.zip(ascending_nodes_lvl1.keys.reverse).each do |descending_node, ascending_node|
          assert_equal descending_node, ascending_node
          descending_nodes_lvl2 = descending_nodes_lvl1[descending_node]
          ascending_nodes_lvl2 = ascending_nodes_lvl1[ascending_node]
          descending_nodes_lvl2.keys.zip(ascending_nodes_lvl2.keys.reverse).each do |descending_node, ascending_node|
            assert_equal descending_node, ascending_node
            descending_nodes_lvl3 = descending_nodes_lvl2[descending_node]
            ascending_nodes_lvl3 = ascending_nodes_lvl2[ascending_node]
            descending_nodes_lvl3.keys.zip(ascending_nodes_lvl3.keys.reverse).each do |descending_node, ascending_node|
              assert_equal descending_node, ascending_node
            end
          end
        end
      end
    end
  end
  
  def test_sort_by_ancestry
    AncestryTestDatabase.with_model do |model|
      n1 = model.create!
      n2 = model.create!(:parent => n1)
      n3 = model.create!(:parent => n2)
      n4 = model.create!(:parent => n2)
      n5 = model.create!(:parent => n1)
      
      arranged = model.sort_by_ancestry(model.all.sort_by(&:id).reverse)
      assert_equal [n1, n2, n4, n3, n5].map(&:id), arranged.map(&:id)
    end
  end
  
  def test_node_excluded_by_default_scope_should_still_move_with_parent
    AncestryTestDatabase.with_model(
      :width => 3, :depth => 3, :extra_columns => {:deleted_at => :datetime}, 
      :default_scope_params => {:conditions => {:deleted_at => nil}}
    ) do |model, roots|
      grandparent = model.roots.all[0]
      new_grandparent = model.roots.all[1]
      parent = grandparent.descendants.first
      child = parent.descendants.first
      
      child.update_attributes :deleted_at => Time.now
      parent.update_attributes :parent => new_grandparent
      child.update_attributes :deleted_at => nil

      assert child.reload.ancestors.include? new_grandparent
    end
  end

  def test_node_excluded_by_default_scope_should_be_destroyed_with_parent
    AncestryTestDatabase.with_model(
      :width => 1, :depth => 2, :extra_columns => {:deleted_at => :datetime}, 
      :default_scope_params => {:conditions => {:deleted_at => nil}},
      :orphan_strategy => :destroy
    ) do |model, roots|
      parent = model.roots.first
      child = parent.descendants.first
      
      child.update_attributes :deleted_at => Time.now
      parent.destroy
      child.update_attributes :deleted_at => nil
      
      assert model.count.zero?
    end
  end

 
 
end
