require 'spec_helper'

describe Garage do
  let(:application) { create(:application) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user )}
  let(:the_post) { create(:post, user: alice, title: "Foo") }
  let(:token) { client_is_authorized(application, requester).token }

  before do
    with_access_token_header token
  end

  describe 'GET request to post' do
    subject {
      get "/posts/#{the_post.id}"
      status
    }

    context 'with alice as a requester' do
      let(:requester) { alice }
      it 'returns 200' do
        subject.should == 200
      end
    end

    context 'with bob as a requester' do
      let(:requester) { bob }
      it 'returns 200' do
        subject.should == 200
      end
    end
  end

  describe 'PUT request to post' do
    subject {
      put "/posts/#{the_post.id}", title: "Bar"
      status
    }

    context 'with alice as a requester' do
      let(:requester) { alice }
      it 'returns 204' do
        subject.should == 204
        the_post.reload.title.should == "Bar"
      end
    end

    context 'with bob as a requester' do
      let(:requester) { bob }
      it 'returns 403' do
        subject.should == 403
        the_post.reload.title.should == "Foo"
      end
    end
  end

  describe 'POST request' do
    subject {
      post "/posts", title: "Hello World"
      last_response
    }

    let(:body) { JSON.parse subject.body }

    context 'with alice as a requester' do
      let(:requester) { alice }
      it 'returns successful' do
        subject.status.should == 201
        Post.find(body['id']).title.should == "Hello World"
      end
    end
  end

  describe 'DELETE request to post' do
    subject {
      delete "/posts/#{the_post.id}"
      status
    }

    context 'with alice as a requester' do
      let(:requester) { alice }
      it 'returns 204' do
        subject.should == 204
        expect { Post.find(the_post.id) }.to raise_error
      end
    end

    context 'with bob as a requester' do
      let(:requester) { bob }
      it 'returns 403' do
        subject.should == 403
        expect { the_post.reload }.not_to raise_error
      end
    end
  end

  describe 'Log notifications' do
    let(:requester) { alice }

    it 'should add application ID' do
      get "/posts/#{the_post.id}"
      last_response.headers['Application-Id'].should == application.uid
    end
  end
end
