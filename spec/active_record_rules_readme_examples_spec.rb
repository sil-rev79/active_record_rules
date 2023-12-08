# frozen_string_literal: true

require "parslet/convenience"

class Post < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class User < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class PostTag < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class TagSubscription < ActiveRecord::Base; include ActiveRecordRules::Fact; end

RSpec.describe ActiveRecordRules do
  subject(:matches) { TestHelper.matches }

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

  describe "example rule matches" do
    before do
      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule Email users when new post is created
          Post(id = post_id, title, created_at)
          User(id = user_id, name, email)
          PostTag(post_id, tag_id)
          TagSubscription(user_id, tag_id)
        on match
          # This is just Ruby code
          if created_at > 5.minutes.ago                # if the post is new
            TestHelper.matches << [name, email, title] # keep track of matches
          end
      RULE

      TestHelper.matches = []
    end

    context "with user John" do
      before do
        user = User.create!(name: "John", email: "john@example.com")
        TagSubscription.create!(user_id: user.id, tag_id: 1)
      end

      context 'with new post "Hello World!"' do
        before do
          post = Post.create!(title: "Hello, world!")
          PostTag.create!(post_id: post.id, tag_id: 1)
        end

        it { is_expected.to include(["John", "john@example.com", "Hello, world!"]) }
      end

      context 'with old post "Hello World!"' do
        before do
          post = Post.create!(title: "Hello, world!", created_at: 10.days.ago)
          PostTag.create!(post_id: post.id, tag_id: 1)
        end

        it { is_expected.not_to include(["John", "john@example.com", "Hello, world!"]) }
      end

      context 'with new post "Wassup!" on irrelevant tag' do
        before do
          post = Post.create!(title: "Hello, world!")
          PostTag.create!(post_id: post.id, tag_id: 2)
        end

        it { is_expected.not_to include(["John", "john@example.com", "Hello, world!"]) }
      end
    end

    context 'with new post "Hello World!"' do
      before do
        post = Post.create!(title: "Hello, world!")
        PostTag.create!(post_id: post.id, tag_id: 1)
      end

      context "with user John, subscribed to relevant tag" do
        before do
          user = User.create!(name: "John", email: "john@example.com")
          TagSubscription.create!(user_id: user.id, tag_id: 1)
        end

        it { is_expected.to include(["John", "john@example.com", "Hello, world!"]) }
      end

      context "with user John, subscribed to irrelevant tag" do
        before do
          user = User.create!(name: "John", email: "john@example.com")
          TagSubscription.create!(user_id: user.id, tag_id: 2)
        end

        it { is_expected.not_to include(["John", "john@example.com", "Hello, world!"]) }
      end
    end

    context 'with old post "Hello World!"' do
      before do
        post = Post.create!(title: "Hello, world!", created_at: 10.days.ago)
        PostTag.create!(post_id: post.id, tag_id: 1)
      end

      context "with user John, subscribed to relevant tag" do
        before do
          user = User.create!(name: "John", email: "john@example.com")
          TagSubscription.create!(user_id: user.id, tag_id: 1)
        end

        it { is_expected.not_to include(["John", "john@example.com", "Hello, world!"]) }
      end
    end
  end

  describe "user post count" do
    subject { user.reload.post_count }

    before do
      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule Update number of posts for user
          Post(id = post_id, author_id, status = "published")
          User(id = author_id)
        on match
          User.find(author_id).increment!(:post_count)
        on unmatch
          User.find(author_id).decrement!(:post_count)
      RULE
    end

    let(:user) { User.create!(name: "John") }

    context "with no posts" do
      it { is_expected.to eq 0 }
    end

    context "with one unpublished post" do
      before { Post.create!(author_id: user.id, status: "unpublished") }

      it { is_expected.to eq 0 }
    end

    context "with one published post" do
      before { Post.create!(author_id: user.id, status: "published") }

      it { is_expected.to eq 1 }
    end

    context "with one post that starts unpublished, but is then published" do
      before do
        post = Post.create!(author_id: user.id, status: "unpublished")
        post.update!(status: "published")
      end

      it { is_expected.to eq 1 }
    end

    context "with one post that starts published, but is then unpublished" do
      before do
        post = Post.create!(author_id: user.id, status: "published")
        post.update!(status: "unpublished")
      end

      it { is_expected.to eq 0 }
    end

    describe "moving a published post between two users" do
      let!(:post) { Post.create!(author_id: user.id, status: "published") }
      let(:user2) { User.create!(name: "Jane") }

      before { post.update!(author_id: user2.id) }

      it "decrements the old user count" do
        expect(user.reload.post_count).to eq 0
      end

      it "increments the new user count" do
        expect(user2.reload.post_count).to eq 1
      end
    end
  end
end
