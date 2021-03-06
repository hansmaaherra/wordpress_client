require "spec_helper"
require "tmpdir"

module WordpressClient
  describe Client do
    subject(:client) { Client.new(connection) }
    let(:connection) { instance_double(Connection) }

    describe "finding posts" do
      it "has working pagination" do
        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(page: 2, per_page: 13)
        ).and_return []

        expect(client.posts(per_page: 13, page: 2)).to eq []
      end

      it "embeds linked resources" do
        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(_embed: nil)
        ).and_return []

        expect(client.posts).to eq []
      end

      it "can filter on category slugs" do
        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(filter: {category_name: "my-cat"})
        ).and_return []

        expect(client.posts(category_slug: "my-cat")).to eq []
      end

      it "can filter on tag slugs" do
        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(filter: {tag: "my-cat"})
        ).and_return []

        expect(client.posts(tag_slug: "my-cat")).to eq []
      end

      it "can filter on tag and category slugs" do
        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(filter: {tag: "my-cat", category_name: "my-dog"})
        ).and_return []

        expect(client.posts(tag_slug: "my-cat", category_slug: "my-dog")).to eq []
      end
    end

    describe "fetching a single post" do
      it "embeds linked resources" do
        post = instance_double(Post)

        expect(connection).to receive(:get).with(
          Post, "posts/5", _embed: nil, context: "edit"
        ).and_return post

        expect(client.find_post(5)).to eq post
      end

      it "can find using a slug" do
        post = instance_double(Post)

        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(filter: {name: "my-slug"})
        ).and_return [post]

        expect(client.find_post_by_slug("my-slug")).to eq post
      end

      it "raises NotFoundError when trying to find by slug yields no posts" do
        expect(connection).to receive(:get_multiple).with(
          Post, "posts", hash_including(filter: {name: "my-slug"}, per_page: 1)
        ).and_return []

        expect {
          client.find_post_by_slug("my-slug")
        }.to raise_error(NotFoundError, /my-slug/)
      end
    end

    describe "creating a post" do
      it "embeds linked resources when following redirect" do
        post = instance_double(Post, id: 5)
        attributes = {title: "Foo"}

        expect(connection).to receive(:create).with(
          Post, "posts", attributes, redirect_params: {_embed: nil}
        ).and_return post

        # We don't expect here as the `create` call below could be enough, but
        # it's also very possible that we need to fetch the post again after
        # doing other things to it.
        allow(connection).to receive(:get).with(
          Post, "posts/5", hash_including(_embed: nil)
        ).and_return(post)

        expect(client.create_post(attributes)).to eq post
      end

      it "adds metadata to the post" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:create).and_return(post)

        expect(ReplaceMetadata).to receive(:apply).with(
          connection, post, {"hello" => "world"}
        ).and_return(0)

        client.create_post(title: "Foo", meta: {"hello" => "world"})
      end

      it "sets categories of the post" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:create).and_return(post)

        expect(ReplaceTerms).to receive(:apply_categories).with(
          connection, post, [1, 3, 7]
        ).and_return(0)

        client.create_post(title: "Foo", category_ids: [1, 3, 7])
      end

      it "sets tags of the post" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:create).and_return(post)

        expect(ReplaceTerms).to receive(:apply_tags).with(
          connection, post, [1, 3, 7]
        ).and_return(0)

        client.create_post(title: "Foo", tag_ids: [1, 3, 7])
      end

      it "refreshes the post if terms or categories changed" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:create).and_return(post)

        expect(ReplaceTerms).to receive(:apply_tags).and_return(1)
        expect(ReplaceTerms).to receive(:apply_categories).and_return(1)
        expect(ReplaceMetadata).to receive(:apply).and_return(1)

        expect(connection).to receive(:get).with(
          Post, "posts/5", hash_including(_embed: nil)
        ).and_return(post)

        client.create_post(title: "Foo", tag_ids: [], category_ids: [], meta: {})
      end

      it "does not refresh the post if neither terms nor categories changed" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:create).and_return(post)

        expect(ReplaceTerms).to receive(:apply_tags).and_return(0)
        expect(ReplaceTerms).to receive(:apply_categories).and_return(0)
        expect(ReplaceMetadata).to receive(:apply).and_return(0)

        expect(connection).to_not receive(:get)

        client.create_post(title: "Foo", tag_ids: [], category_ids: [], meta: {})
      end
    end

    describe "updating a post" do
      it "embeds linked resources" do
        post = instance_double(Post)

        expect(connection).to receive(:patch).with(
          Post, "posts/5?_embed", hash_including(title: "Foo")
        ).and_return(post)

        expect(client.update_post(5, title: "Foo")).to eq post
      end

      it "adds metadata to the post" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:patch).and_return(post)

        expect(ReplaceMetadata).to receive(:apply).with(
          connection, post, {"hello" => "world"}
        ).and_return(0)

        client.update_post(5, title: "Foo", meta: {"hello" => "world"})
      end

      it "changes categories of the post" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:patch).and_return(post)

        expect(ReplaceTerms).to receive(:apply_categories).with(
          connection, post, [1, 3, 7]
        ).and_return(0)

        client.update_post(5, title: "Foo", category_ids: [1, 3, 7])
      end

      it "changes tags of the post" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:patch).and_return(post)

        expect(ReplaceTerms).to receive(:apply_tags).with(
          connection, post, [1, 3, 7]
        ).and_return(0)

        client.update_post(5, title: "Foo", tag_ids: [1, 3, 7])
      end

      it "refreshes the post if terms or categories changed" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:patch).and_return(post)

        expect(ReplaceTerms).to receive(:apply_tags).and_return(1)
        expect(ReplaceTerms).to receive(:apply_categories).and_return(1)
        expect(ReplaceMetadata).to receive(:apply).and_return(1)

        expect(connection).to receive(:get).with(
          Post, "posts/5", hash_including(_embed: nil)
        ).and_return(post)

        client.update_post(5, title: "Foo", tag_ids: [], category_ids: [], meta: {})
      end

      it "does not refresh the post if neither terms nor categories changed" do
        post = instance_double(Post, id: 5)
        allow(connection).to receive(:patch).and_return(post)

        expect(ReplaceTerms).to receive(:apply_tags).and_return(0)
        expect(ReplaceTerms).to receive(:apply_categories).and_return(0)
        expect(ReplaceMetadata).to receive(:apply).and_return(0)

        expect(connection).to_not receive(:get)

        client.update_post(5, title: "Foo", tag_ids: [], category_ids: [], meta: {})
      end
    end

    describe "deleting posts" do
      it "deletes a post without force by default" do
        expect(connection).to receive(:delete).with(
          "posts/1", {"force" => false}
        ).and_return true

        expect(client.delete_post(1)).to eq true
      end

      it "deletes a post without force" do
        expect(connection).to receive(:delete).with(
          "posts/1", {"force" => false}
        ).and_return true

        expect(client.delete_post(1, force: false)).to eq true
      end

      it "deletes a post with force" do
        expect(connection).to receive(:delete).with(
          "posts/1", {"force" => true}
        ).and_return true

        expect(client.delete_post(1, force: true)).to eq true
      end
    end

    describe "categories" do
      it "can be listed" do
        expect(connection).to receive(:get_multiple).with(
          Category, "terms/category", hash_including(page: 1, per_page: 10)
        )
        client.categories

        expect(connection).to receive(:get_multiple).with(
          Category, "terms/category", hash_including(page: 2, per_page: 60)
        )
        client.categories(page: 2, per_page: 60)
      end

      it "can be found" do
        category = instance_double(Category)

        expect(connection).to receive(:get).with(
          Category, "terms/category/12"
        ).and_return category

        expect(client.find_category(12)).to eq category
      end

      it "can be created" do
        category = instance_double(Category)

        expect(connection).to receive(:create).with(
          Category, "terms/category", name: "Foo"
        ).and_return category

        expect(client.create_category(name: "Foo")).to eq category
      end

      it "can be updated" do
        category = instance_double(Category)

        expect(connection).to receive(:patch).with(
          Category, "terms/category/45", name: "New"
        ).and_return category

        expect(client.update_category(45, name: "New")).to eq category
      end
    end

    describe "tags" do
      it "can be listed" do
        expect(connection).to receive(:get_multiple).with(
          Tag, "terms/tag", hash_including(page: 1, per_page: 10)
        )
        client.tags

        expect(connection).to receive(:get_multiple).with(
          Tag, "terms/tag", hash_including(page: 2, per_page: 60)
        )
        client.tags(page: 2, per_page: 60)
      end

      it "can be found" do
        tag = instance_double(Tag)

        expect(connection).to receive(:get).with(
          Tag, "terms/tag/12"
        ).and_return tag

        expect(client.find_tag(12)).to eq tag
      end

      it "can be created" do
        tag = instance_double(Tag)

        expect(connection).to receive(:create).with(
          Tag, "terms/tag", name: "Foo"
        ).and_return tag

        expect(client.create_tag(name: "Foo")).to eq tag
      end

      it "can be updated" do
        tag = instance_double(Tag)

        expect(connection).to receive(:patch).with(
          Tag, "terms/tag/45", name: "New"
        ).and_return tag

        expect(client.update_tag(45, name: "New")).to eq tag
      end
    end

    describe "media" do
      it "can be uploaded from IO objects" do
        media = instance_double(Media)
        io = double("io")

        expect(connection).to receive(:upload).with(
          Media, "media", io, mime_type: "text/plain", filename: "foo.txt"
        ).and_return media

        expect(client.upload(io, mime_type: "text/plain", filename: "foo.txt")).to eq media
      end

      it "can be uploaded from files" do
        media = instance_double(Media)

        Dir.mktmpdir do |dir|
          file = File.join(dir, "test.txt")
          File.write(file, "hello world")

          expect(connection).to receive(:upload) do |_, _, io, filename:, mime_type:|
            expect(filename).to eq "test.txt"
            expect(mime_type).to eq "text/plain"

            expect(io.read).to eq "hello world"
            media
          end

          expect(client.upload_file(file, mime_type: "text/plain")).to eq media
        end
      end

      it "can be found" do
        media = instance_double(Media)

        expect(connection).to receive(:get).with(Media, "media/7").and_return(media)

        expect(client.find_media(7)).to eq media
      end

      it "can be listed" do
        media = instance_double(Media)

        expect(connection).to receive(:get_multiple).with(
          Media, "media", per_page: 10, page: 1
        ).and_return([media])

        expect(client.media).to eq [media]
      end

      it "can be updated" do
        media = instance_double(Media)

        expect(connection).to receive(:patch).with(
          Media, "media/7", title: "New"
        ).and_return(media)

        expect(client.update_media(7, title: "New")).to eq media
      end
    end
  end
end
