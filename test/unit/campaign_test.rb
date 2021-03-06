require 'test_helper'

class CampaignTest < ActiveSupport::TestCase
  def setup
    Post.index_name('test_' + Post.model_name.plural)
    Post.index.delete
    Post.create_elasticsearch_index

    @leader = posts(:leader)
    @leader2 = posts(:leader2)
    @leader3 = posts(:leader3)

    Post.index.import [@leader, @leader2, @leader3]
    Post.index.refresh
  end

  test "verify basic" do
    assert_equal companies(:apple).campaigns.length, 1, "apple does not have the correct number of campaigns"
    assert_equal companies(:microsoft).campaigns.length, 1, "microsoft does not have the correct number of campaigns"
  end

  test "verify post relation" do
    assert_equal campaigns(:one).posts.length, 2, "Campaign one doesn't have the appropriate number of associated posts" 
  end 

  test "verify validations" do
    endtime = Time.now.utc + 120
    campaign = Campaign.new(:title => "test", :description => "test", :company_id => 1, :starttime => Time.now.utc )
    assert !campaign.save, "Able to save without endtime"

    campaign = Campaign.new(:title => "test", :description => "test", :company_id => 1, :endtime => Time.now.utc )
    assert !campaign.save, "Able to save without starttime"

    campaign = Campaign.new(:title => "test", :description => "test", :starttime => Time.now.utc, :endtime => endtime )
    assert !campaign.save, "Able to save without company_id"

    campaign = Campaign.new(:title => "test", :company_id => 1, :starttime => Time.now.utc, :endtime => endtime)
    assert !campaign.save, "Able to save without description"

    campaign = Campaign.new(:description => "test", :company_id => 1, :starttime => Time.now.utc, :endtime => endtime)
    assert !campaign.save, "Able to save without title"

  end
  test "verify time validations" do
    campaign = Campaign.new(:title => "test", 
      :description => "test", :company_id => 1, 
      :starttime => (Time.now.utc - 120), :endtime => Time.now.utc)

    assert !campaign.save, "Able to save a starttime that begins before the current time period" 
  
    campaign = Campaign.new(:title => "test", 
      :description => "test", :company_id => 1, 
      :starttime => Time.now.utc, :endtime => (Time.now.utc - 1))
    assert !campaign.save, "Able to save an endtime that is <= the given starttime"
  end

  test "verify top posts" do
    posts = campaigns(:two).top_posts(:min_votes => 1) 
    assert_equal 0, posts.results.length, "No posts with vote of 1" 

    users(:one).vote_for(@leader)   
    @leader.save
    Post.index.refresh

    posts = campaigns(:two).top_posts
    assert_equal @leader.id, posts.results[0].id.to_i, "Posts not sorted properly"

    posts = campaigns(:two).top_posts(:min_votes => 1)
    assert_equal 1, posts.results.length, "Incorrect minimum vote filter, should be 1 post"
    
    #posts submitted at identical times will be sorted by metrics controlled by the internals of elastic search and not by us. 
    # so we need to sleep to test different post times
    sleep(1) 

    users(:one).vote_for(@leader2)
    @leader2.save
    Post.index.refresh    
    
    posts = campaigns(:two).top_posts
    # Verify that oldest upvoted posts retain their position until they
    # have been overtaken in upvotes by another post
    assert_equal @leader.id, posts.results[0].id.to_i, "Posts not sorted"
    assert_equal @leader2.id, posts.results[1].id.to_i, "Posts not sorted"

    sleep(1)
     
    users(:two).vote_for(@leader2)
    @leader2.save
    Post.index.refresh

    posts = campaigns(:two).top_posts
    assert_equal @leader2.id, posts.results[0].id.to_i, "Posts not sorted"
    assert_equal @leader.id, posts.results[1].id.to_i, "Posts not sorted"
  end  
end
