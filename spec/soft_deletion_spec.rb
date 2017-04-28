require 'spec_helper'

SingleCov.covered!
SingleCov.covered! file: 'lib/soft_deletion/setup.rb'
SingleCov.covered! file: 'lib/soft_deletion/core.rb', uncovered: 2 # AR version if/else
SingleCov.covered! file: 'lib/soft_deletion/dependency.rb'

describe SoftDeletion do
  def abort_callback(category)
    if ActiveRecord::VERSION::MAJOR < 5
      expect(category).to receive(:foo).and_return(false)
    else
      expect(category).to receive(:foo).and_throw(:abort)
    end
  end

  def self.successfully_soft_deletes
    context "successfully soft deleted" do
      before do
        @category.soft_delete!
      end

      it "marks itself as deleted" do
        @category.reload
        expect(@category).to be_deleted
      end

      it "soft deletes its dependent associations" do
        @forum.reload
        expect(@forum).to be_deleted
      end
    end
  end

  def self.successfully_bulk_soft_deletes
    context "successfully bulk soft deleted" do
      before do
        Category.soft_delete_all!(@category)
      end

      it "marks itself as deleted" do
        @category.reload
        expect(@category).to be_deleted
      end

      it "soft deletes its dependent associations" do
        @forum.reload
        expect(@forum).to be_deleted
      end
    end
  end

  before do
    clear_callbacks Category, :soft_delete
    clear_callbacks Category, :soft_undelete

    # Stub dump method calls
    allow_any_instance_of(Category).to receive(:foo)
    allow_any_instance_of(Category).to receive(:bar)
  end

  it "refuses to be included in a non-AR" do
    expect do
      Class.new { include SoftDeletion::Core }
    end.to raise_error(RuntimeError, /only include this/)
  end

  describe "callbacks" do
    describe ".before_soft_delete" do
      it "is called on soft-deletion" do
        Category.before_soft_delete :foo
        category = Category.create!

        expect(category).to receive(:foo)

        category.soft_delete!
      end

      describe "when saving is aborted" do
        let(:category) { Category.create! }

        before do
          Category.before_soft_delete :foo, :bar
          abort_callback(category)
          expect(category).not_to receive(:bar)
        end

        it "stops execution chain if false is returned" do
          expect(category.soft_delete).to be(false)
          category.reload
          expect(category).not_to be_deleted
        end

        it "blows up execution if false is returned with soft_delete!" do
          expect { category.soft_delete! }.to raise_error(
            ActiveRecord::RecordNotSaved,
            "before_soft_delete hook failed, errors: None"
          )
          category.reload
          expect(category).not_to be_deleted
        end

        it "shows errors if false is returned with soft_delete!" do
          category.errors[:base] << "This is bad!"
          category.errors[:base] << "This too!"
          expect { category.soft_delete! }.to raise_error(
            ActiveRecord::RecordNotSaved,
            "before_soft_delete hook failed, errors: This is bad!, This too!"
          )
        end
      end
    end

    describe ".after_soft_delete" do
      it "is called after soft-deletion" do
        Category.after_soft_delete :foo
        category = Category.create!

        expect(category).to receive(:foo)

        category.soft_delete!
      end

      it "is called after bulk soft-deletion" do
        Category.after_soft_delete :foo
        category = Category.create!

        expect(category).to receive(:foo)

        Category.soft_delete_all!(category)
      end

      it "is called with a block" do
        Category.after_soft_delete{|c| c.foo }
        category = Category.create!

        expect(category).to receive(:foo)

        category.soft_delete!
      end

      it "calls multiple after soft-deletion" do
        Category.after_soft_delete :foo, :bar
        category = Category.create!

        expect(category).to receive(:foo)
        expect(category).to receive(:bar)

        category.soft_delete!
      end

      it "does not stop deletion when returning false" do
        Category.after_soft_delete :foo
        category = Category.create!

        expect(category).to receive(:foo).and_return(false)

        category.soft_delete!

        category.reload
        expect(category).to be_deleted
      end

      it "is not called after normal destroy" do
        Category.after_soft_delete :foo
        category = Category.create!

        expect(category).not_to receive(:foo)

        category.destroy
      end
    end

    describe ".before_soft_undelete" do
      it "is called on soft-undeletion" do
        Category.before_soft_undelete :foo
        category = Category.create!(:deleted_at => Time.now)

        expect(category).to receive(:foo)

        category.soft_undelete!
      end

      describe "when saving is aborted" do
        let(:category) { Category.create!(deleted_at: Time.now) }

        before do
          Category.before_soft_undelete :foo, :bar
          abort_callback(category)
          expect(category).not_to receive(:bar)
        end

        it "stops execution chain if false is returned" do
          expect(category.soft_undelete).to be(false)
          category.reload
          expect(category).to be_deleted
        end

        it "blows up execution if false is returned with soft_undelete!" do
          expect { category.soft_undelete! }.to raise_error(
            ActiveRecord::RecordNotSaved,
            "before_soft_undelete hook failed, errors: None"
          )
          category.reload
          expect(category).to be_deleted
        end
      end
    end

    describe ".after_soft_undelete" do
      it "is called after soft-undeletion" do
        Category.after_soft_undelete :foo
        category = Category.create!(:deleted_at => Time.now)

        expect(category).to receive(:foo)

        category.soft_undelete!
      end

      it "is called with a block" do
        Category.after_soft_undelete{|c| c.foo }
        category = Category.create!(:deleted_at => Time.now)

        expect(category).to receive(:foo)

        category.soft_undelete!
      end

      it "calls multiple after soft-undeletion" do
        Category.after_soft_undelete :foo, :bar
        category = Category.create!(:deleted_at => Time.now)

        expect(category).to receive(:foo)
        expect(category).to receive(:bar)

        category.soft_undelete!
      end

      it "does not stop undeletion when returning false" do
        Category.after_soft_undelete :foo
        category = Category.create!(:deleted_at => Time.now)

        expect(category).to receive(:foo).and_return(false)

        category.soft_undelete!

        category.reload
        expect(category).not_to be_deleted
      end

      it "is not called after normal destroy" do
        Category.after_soft_undelete :foo
        category = Category.create!(:deleted_at => Time.now)

        expect(category).not_to receive(:foo)

        category.destroy
      end
    end
  end

  describe "association" do
    context "without dependent associations" do
      it "only soft-deletes itself" do
        category = NACategory.create!
        category.soft_delete!

        category.reload
        expect(category).to be_deleted
      end
    end

    context "with independent associations" do
      it "does not delete associations" do
        category = IDACategory.create!
        forum = category.forums.create!
        category.soft_delete!

        forum.reload
        expect(forum).to be_deleted
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

        it "marks itself as deleted" do
          @category.reload
          expect(@category).to be_deleted
        end

        it "does not destroy dependent association" do
          expect(DestroyableForum.exists?(@forum.id)).to be(true)
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
          allow(@category).to receive(:valid?).and_return(false)
          expect{ @category.soft_delete! }.to raise_error(ActiveRecord::RecordInvalid)
        end

        it "does not mark itself as deleted" do
          @category.reload
          expect(@category).not_to be_deleted
        end

        it "does not soft delete its dependent associations" do
          @forum.reload
          expect(@forum).not_to be_deleted
        end
      end

      successfully_soft_deletes
      successfully_bulk_soft_deletes

      context "being restored from soft deletion" do
        def undelete!
          Category.with_deleted do
            @category.reload
            @category.soft_undelete!
          end
        end

        before do
          @category.soft_delete!
          Category.with_deleted { @category = Category.find(@category.id) }
        end

        it "does not mark itself as deleted" do
          undelete!
          @category.reload
          expect(@category).not_to be_deleted
        end

        it "restores its dependent associations" do
          undelete!
          @forum.reload
          expect(@forum).not_to be_deleted
        end

        it "does not fail if dependent associations are not deleted" do
          @forum.reload.soft_undelete!
          undelete!
          @forum.reload
          expect(@forum).not_to be_deleted
        end

        it "does not restore far previous deletions" do
          @forum.update_attributes(:deleted_at => 1.year.ago)
          undelete!
          expect(@forum.reload).to be_deleted
        end
      end
    end

    context "a soft-deleted has-many category that nullifies forum references on delete" do
      it "nullifies those references" do
        category = NDACategory.create!
        forum = category.forums.create!
        category.soft_delete!

        forum.reload
        expect(forum).not_to be_deleted
        expect(forum.category_id).to be_nil
      end
    end

    context "a soft-deleted has-many category that delete_all forum references on delete" do
      it "use update_all to delete references" do
        category = DDACategory.create!
        forum = category.forums.create!
        category.soft_delete!

        expect(forum).not_to be_deleted # just did an update_all
        expect(Forum.find(forum.id)).to be_deleted
      end

      it "custom sql to delete all" do
        category = DDACategory.create!
        forum = category.forums.create!
        expect(Forum).to receive(:mark_as_soft_deleted_sql).and_return "fooo"
        expect_any_instance_of(category.forums.class).to receive(:update_all).with("fooo")
        category.soft_delete!
      end
    end

    context "a soft-deleted has-many category that defaults dependent forum references on delete" do
      it "does nothing to those references" do
        category = XDACategory.create!
        forum = category.forums.create!
        category.soft_delete!

        forum.reload
        expect(forum).not_to be_deleted
        expect(forum.category_id).not_to be_nil
      end
    end

    context "a soft-deleted has-many category that nullifies forum references on delete without foreign_key" do
      it "nullifies those references" do
        organization = Organization.create!
        forum = organization.forums.create!
        organization.soft_delete!

        forum.reload
        expect(forum).not_to be_deleted
        expect(forum.organization_id).to be_nil
      end
    end
  end

  context "without deleted_at column" do
    it "does not provoke an error" do
      OriginalCategory.create!
    end
  end

  context "default_scope" do
    let(:forum) { Cat2Forum.create!(deleted_at: Time.now) }

    it "prevents find when deleted" do
      expect(Cat2Forum.find_by_id(forum.id)).to be_nil
    end

    it "can find without deleted" do
      forum.update_attributes(:deleted_at => nil)
      expect(Cat2Forum.find_by_id(forum.id)).not_to be_nil
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

      it "deletes all models" do
        @categories.each do |category|
          category.reload
          expect(category).to be_deleted
        end
      end
    end

    context "by model" do
      before do
        Category.soft_delete_all!(@categories)
      end

      it "deletes all models" do
        @categories.each do |category|
          category.reload
          expect(category).to be_deleted
        end
      end
    end
  end

  describe "overwritten default scope" do
    it "finds even with deleted_at" do
      forum = Cat1Forum.create(:deleted_at => Time.now)

      expect(Cat1Forum.find_by_id(forum.id)).not_to be_nil
    end

    it "does not find by new scope" do
      # create! does not work here on rails 2
      forum = Cat1Forum.new
      forum.category_id = 2
      forum.save!

      expect(Cat1Forum.find_by_id(forum.id)).to be_nil
    end
  end

  describe "validations" do
    let(:forum) { ValidatedForum.create!(category_id: 1) }

    it "fails when validations fail" do
      forum.category_id = nil

      expect do
        forum.soft_delete!
      end.to raise_error(ActiveRecord::RecordInvalid)

      forum.reload
      expect(forum).not_to be_deleted
    end

    it "passes when validations pass" do
      forum.soft_delete!

      forum.reload
      expect(forum).to be_deleted
    end

    it "can skip validations" do
      forum.category_id = nil
      forum.soft_delete!(validate: false)

      forum.reload
      expect(forum).to be_deleted
    end
  end

  describe "#soft_delete" do
    it "returns true if it succeeds" do
      forum = ValidatedForum.create!(:category_id => 1)

      expect(forum.soft_delete).to be(true)
      forum.reload
      expect(forum).to be_deleted
    end

    it "returns false if validations fail" do
      forum = ValidatedForum.create!(:category_id => 1)
      forum.category_id = nil

      expect(forum.soft_delete).to be(false)
      forum.reload
      expect(forum).not_to be_deleted
    end

    it "returns true if validations are prevented and it succeeds" do
      forum = ValidatedForum.create!(:category_id => 1)
      forum.category_id = nil

      expect(
        forum.soft_delete(:validate => false)
      ).to be(true)
      forum.reload
      expect(forum).to be_deleted
    end

    it "does not change deleted_at if already soft deleted" do
      forum = ValidatedForum.create!(:category_id => 1)

      expect(forum.soft_delete).to be(true)
      forum.reload
      deleted_at = forum.deleted_at

      expect(forum.soft_delete).to be(true)
      forum.reload
      expect(forum.deleted_at).to eq(deleted_at)
    end
  end

  describe ".with_deleted" do
    let(:forum) { Cat2Forum.create! }

    it "finds deleted records" do
      forum.soft_delete!
      Cat2Forum.with_deleted { Cat2Forum.find(forum.id) }
    end

    it "finds deleted records of STI subclass" do
      forum = Cat2ForumChild.create!
      forum.soft_delete!
      Cat2Forum.with_deleted { Cat2ForumChild.find(forum.id) }
      Cat2Forum.with_deleted { Cat2Forum.find(forum.id) }
    end

    it "does not find deleted records of other classes" do
      forum.soft_delete!
      expect do
        CategoryWithDefault.with_deleted { Cat2Forum.find(forum.id) }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "finds normal records" do
      Cat2Forum.with_deleted { Cat2Forum.find(forum.id) }
    end

    it "keeps other where clauses" do
      expect do
        Cat2Forum.where('1=2').with_deleted { Cat2Forum.find(forum.id) }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can find while joining" do
      category = CategoryWithDefault.create!
      forum.update_column(:category_id, category.id)
      forum.soft_delete!
      Cat2Forum.with_deleted do
        expect(
          CategoryWithDefault.includes(:forums).first.forums
        ).to eq([forum])
      end
    end
  end
end
