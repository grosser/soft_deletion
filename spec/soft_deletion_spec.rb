require 'spec_helper'

describe SoftDeletion do
  def self.successfully_soft_deletes
    context "successfully soft deleted" do
      before do
        @category.soft_delete!
      end

      it "should mark itself as deleted" do
        @category.reload
        @category.should be_deleted
      end

      it "should soft delete its dependent associations" do
        @forum.reload
        @forum.should be_deleted
      end
    end
  end

  def self.successfully_bulk_soft_deletes
    context "successfully bulk soft deleted" do
      before do
        Category.soft_delete_all!(@category)
      end

      it "should mark itself as deleted" do
        @category.reload
        @category.should be_deleted
      end

      it "should soft delete its dependent associations" do
        @forum.reload
        @forum.should be_deleted
      end
    end
  end

  before do
    clear_callbacks Category, :soft_delete

    # Stub dump method calls
    Category.any_instance.stub(:foo)
    Category.any_instance.stub(:bar)
  end

  describe "callbacks" do
    describe ".before_soft_delete" do
      it "is called on soft-deletion" do
        Category.before_soft_delete :foo
        category = Category.create!

        category.should_receive(:foo)

        category.soft_delete!
      end

      it "stops execution chain if false is returned" do
        Category.before_soft_delete :foo, :bar
        category = Category.create!

        category.should_receive(:foo).and_return(false)
        category.should_not_receive(:bar)

        category.soft_delete!.should == false
        category.reload
        category.should_not be_deleted
      end
    end

    describe ".after_soft_delete" do
      it "is called after soft-deletion" do
        Category.after_soft_delete :foo
        category = Category.create!

        category.should_receive(:foo)

        category.soft_delete!
      end

      it "is called after bulk soft-deletion" do
        Category.after_soft_delete :foo
        category = Category.create!

        category.should_receive(:foo)

        Category.soft_delete_all!(category)
      end

      it "is called with a block" do
        Category.after_soft_delete{|c| c.foo }
        category = Category.create!

        category.should_receive(:foo)

        category.soft_delete!
      end

      it "calls multiple after soft-deletion" do
        Category.after_soft_delete :foo, :bar
        category = Category.create!

        category.should_receive(:foo)
        category.should_receive(:bar)

        category.soft_delete!
      end

      it "does not stop deletion when returning false" do
        Category.after_soft_delete :foo
        category = Category.create!

        category.should_receive(:foo).and_return false

        category.soft_delete!

        category.reload
        category.should be_deleted
      end

      it "is not called after normal destroy" do
        Category.after_soft_delete :foo
        category = Category.create!

        category.should_not_receive(:foo)

        category.destroy
      end
    end
  end

  describe "association" do
    context "without dependent associations" do
      it "should only soft-delete itself" do
        category = NACategory.create!
        category.soft_delete!

        category.reload
        category.should be_deleted
      end
    end

    context "with independent associations" do
      it "should not delete associations" do
        category = IDACategory.create!
        forum = category.forums.create!
        category.soft_delete!

        forum.reload
        forum.should be_deleted
      end
    end

    context "with dependent has_one association" do
      before do
        @category = HOACategory.create!
        @forum = @category.create_forum
      end

      successfully_soft_deletes
      successfully_bulk_soft_deletes
    end

    context "with dependent association that doesn't have soft deletion" do
      before do
        @category = DACategory.create!
        @forum = @category.destroyable_forums.create!
      end

      context "successfully soft deleted" do
        before do
          @category.soft_delete!
        end

        it "should mark itself as deleted" do
          @category.reload
          @category.should be_deleted
        end

        it "should not destroy dependent association" do
          DestroyableForum.exists?(@forum.id).should be_true
        end
      end
    end

    context "with dependent has_many associations" do
      before do
        @category = Category.create!
        @forum = @category.forums.create!
      end

      context "failing to soft delete" do
        before do
          @category.stub(:valid?).and_return(false)
          expect{ @category.soft_delete! }.to raise_error(ActiveRecord::RecordInvalid)
        end

        it "should not mark itself as deleted" do
          @category.reload
          @category.should_not be_deleted
        end

        it "should not soft delete its dependent associations" do
          @forum.reload
          @forum.should_not be_deleted
        end
      end

      if ActiveRecord::VERSION::MAJOR == 3
        context "soft deleting its dependent association" do
          before do
            @category.forums.map &:soft_delete!
            @category.reload
            @category.forums.with_deleted.map &:soft_undelete!
          end

          it "should restore its dependent association" do
            @forum.reload
            @forum.should_not be_deleted
          end
        end

        context "soft deleting one of its dependent associations" do
          before do
            @category.forums.create!
            @first_forum = @category.forums.first
            @first_forum.soft_delete!
          end

          it "should return the deleted association" do
            @category.reload
            @category.forums.only_deleted == [@first_forum]
            @category.forums.with_deleted.count.should == 2
          end
        end
      end

      successfully_soft_deletes
      successfully_bulk_soft_deletes

      context "being restored from soft deletion" do
        before do
          @category.soft_delete!
          Category.with_deleted do
            @category.reload
            @category.soft_undelete!
          end
        end

        it "should not mark itself as deleted" do
          @category.reload
          @category.should_not be_deleted
        end

        it "should restore its dependent associations" do
          @forum.reload
          @forum.should_not be_deleted
        end
      end
    end

    context "a soft-deleted has-many category that nullifies forum references on delete" do
      it "should nullify those references" do
        category = NDACategory.create!
        forum = category.forums.create!
        category.soft_delete!

        forum.reload
        forum.should be_deleted
        #forum.category_id.should be_nil # TODO
      end
    end
  end

  context "without deleted_at column" do
    it "should default scope should not provoke an error" do
      expect do
        OriginalCategory.create!
      end.to_not raise_error
    end
  end

  describe ".soft_delete_all!" do
    before do
      @categories = 2.times.map { Category.create! }
    end

    context "by id" do
      before do
        Category.soft_delete_all!(@categories.map(&:id))
      end

      it "should delete all models" do
        @categories.each do |category|
          category.reload
          category.should be_deleted
        end
      end
    end

    context "by model" do
      before do
        Category.soft_delete_all!(@categories)
      end

      it "should delete all models" do
        @categories.each do |category|
          category.reload
          category.should be_deleted
        end
      end
    end
  end

  describe "overwritten default scope" do
    it "should find even with deleted_at" do
      forum = Cat1Forum.create(:deleted_at => Time.now)

      Cat1Forum.find_by_id(forum.id).should_not be_nil
    end

    it "should not find by new scope" do
      # create! does not work here on rails 2
      forum = Cat1Forum.new
      forum.category_id = 2
      forum.save!

      Cat1Forum.find_by_id(forum.id).should be_nil
    end
  end

  describe "validations" do
    it "should fail when validations fail" do
      forum = ValidatedForum.create!(:category_id => 1)
      forum.category_id = nil

      expect do
        forum.soft_delete!
      end.to raise_error(ActiveRecord::RecordInvalid)

      forum.reload
      forum.should_not be_deleted
    end

    it "should pass when validations pass" do
      forum = ValidatedForum.create!(:category_id => 1)
      forum.soft_delete!

      forum.reload
      forum.should be_deleted
    end
  end

  describe "#soft_delete" do
    it "should return true if it succeeds" do
      forum = ValidatedForum.create!(:category_id => 1)

      forum.soft_delete.should be_true
      forum.reload
      forum.should be_deleted
    end

    it "should return false if validations fail" do
      forum = ValidatedForum.create!(:category_id => 1)
      forum.category_id = nil

      forum.soft_delete.should be_false
      forum.reload
      forum.should_not be_deleted
    end

    it "should return true if validations are prevented and it succeeds" do
      forum = ValidatedForum.create!(:category_id => 1)
      forum.category_id = nil
      skip_validations = (ActiveRecord::VERSION::MAJOR == 2 ? false : {:validate => false})

      forum.soft_delete(skip_validations).should be_true
      forum.reload
      forum.should be_deleted
    end
  end
end
