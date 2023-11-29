# frozen_string_literal: true

require "parslet/convenience"

class Post < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class User < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class PostTag < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class TagSubscription < ActiveRecord::Base; include ActiveRecordRules::Fact; end

module TestHelper
  cattr_accessor :activated
end

RSpec.describe "examples from README.md" do
  before do
    define_tables do |schema|
      schema.create_table :users do |t|
        t.string :name
        t.string :email
        t.integer :post_count, default: 0
      end

      schema.create_table :posts do |t|
        t.references :author, foreign_key: { to_table: :users }
        t.string :status
        t.string :title
        t.timestamps
      end

      schema.create_table :post_tags do |t|
        t.references :post
        t.integer :tag_id # we don't actually create a tag table, so this can't be a reference
      end

      schema.create_table :tag_subscriptions do |t|
        t.references :user
        t.integer :tag_id # we don't actually create a tag table, so this can't be a reference
      end
    end
  end

  describe "first example" do
    before do
      ActiveRecordRules::Rule.create_from_definition(<<~RULE)
        rule Email users when new post is created
          Post(id = post_id, title, created_at)
          User(id = user_id, name, email)
          PostTag(post_id, tag_id)
          TagSubscription(user_id, tag_id)
        on activation
          # This is just Ruby code
          if created_at > 5.minutes.ago                  # if the post is new
            TestHelper.activated << [name, email, title] # keep track of activations
          end
      RULE
    end

    context "pre-existing user" do
      before do
        TestHelper.activated = []

        user = User.create!(name: "John", email: "john@example.com")
        TagSubscription.create!(user_id: user.id, tag_id: 1)
      end

      context "new post" do
        before do
          post = Post.create!(title: "Hello, world!")
          PostTag.create(post_id: post.id, tag_id: 1)
        end

        it "activates" do
          expect(TestHelper.activated).to include(["John", "john@example.com", "Hello, world!"])
        end
      end

      context "old post" do
        before do
          post = Post.create!(title: "Hello, world!", created_at: 10.days.ago)
          PostTag.create(post_id: post.id, tag_id: 1)
        end

        it "does not activate" do
          expect(TestHelper.activated).not_to include(["John", "john@example.com", "Hello, world!"])
        end
      end
    end

    context "pre-existing new post" do
      before do
        TestHelper.activated = []

        post = Post.create!(title: "Hello, world!")
        PostTag.create(post_id: post.id, tag_id: 1)
      end

      context "user subscription" do
        before do
          user = User.create!(name: "John", email: "john@example.com")
          TagSubscription.create!(user_id: user.id, tag_id: 1)
        end

        it "does not activate" do
          expect(TestHelper.activated).to include(["John", "john@example.com", "Hello, world!"])
        end
      end
    end

    context "pre-existing old post" do
      before do
        TestHelper.activated = []

        post = Post.create!(title: "Hello, world!", created_at: 10.days.ago)
        PostTag.create(post_id: post.id, tag_id: 1)
      end

      context "user subscription" do
        before do
          user = User.create!(name: "John", email: "john@example.com")
          TagSubscription.create!(user_id: user.id, tag_id: 1)
        end

        it "does not activate" do
          expect(TestHelper.activated).not_to include(["John", "john@example.com", "Hello, world!"])
        end
      end
    end
  end

  describe "post count" do
    before do
      ActiveRecordRules::Rule.create_from_definition(<<~RULE)
        rule Update number of posts for user
          Post(id = post_id, author_id, status = "published")
          User(id = author_id)
        on activation
          User.find(author_id).increment!(:post_count)
        on deactivation
          User.find(author_id).decrement!(:post_count)
      RULE
    end

    subject { user.reload.post_count }
    let(:user) { User.create!(name: "John") }

    context "with no posts" do
      it { is_expected.to eq(0) }
    end

    context "with one unpublished post" do
      before { Post.create!(author_id: user.id, status: "unpublished") }
      it { is_expected.to eq(0) }
    end

    context "with one unpublished post" do
      before { Post.create!(author_id: user.id, status: "published") }
      it { is_expected.to eq(1) }
    end

    context "with one post that starts unpublished, but is then published" do
      before do
        post = Post.create!(author_id: user.id, status: "unpublished")
        post.update!(status: "published")
      end

      it { is_expected.to eq(1) }
    end

    context "with one post that starts published, but is then unpublished" do
      before do
        post = Post.create!(author_id: user.id, status: "published")
        post.update!(status: "unpublished")
      end

      it { is_expected.to eq(0) }
    end

    context "moving a published post between two users" do
      let!(:post) { Post.create!(author_id: user.id, status: "published") }
      let(:user2) { User.create!(name: "Jane") }

      it "updates both post counts" do
        expect(user.reload.post_count).to eq(1)
        expect(user2.reload.post_count).to eq(0)
        post.update!(author_id: user2.id)
        expect(user.reload.post_count).to eq(0)
        expect(user2.reload.post_count).to eq(1)
      end
    end
  end
end
