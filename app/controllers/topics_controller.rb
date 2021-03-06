class TopicsController < ApplicationController
  before_filter :store_location, :only => [:show, :new, :edit, :reply]
  before_filter :login_required, :except => [:show]
  before_filter :find_forum
  before_filter :moderator_login_required, :only => [:lock, :unlock]
  before_filter :create_ip, :only => [:create, :update]
  
  def index
    redirect_to forum_path(@forum)
  end
  
  def show
    if logged_in?
      @topic.readers << current_user if !@topic.readers.include?(current_user)
      @subscription = current_user.subscriptions.find_by_topic_id(params[:id])
      @subscription.update_attribute("posts_count", 0) if @subscription
    end
    @posts = @topic.posts.paginate :per_page => per_page, :page => params[:page], :include => { :user => :user_level }
    @topic.increment!("views")
    @post = Post.new
    respond_to do |format|
      format.html
      format.rss
    end
  end
  
  def new
    @topic = @forum.topics.new
    @post = @topic.posts.build
  end
  
  def create
    @topic = current_user.topics.build(params[:topic].merge(:forum => @forum, :ip => @ip))
    @post = @topic.posts.build(params[:post].merge(:user => current_user, :ip => @ip))
    @topic.sticky = true if params[:topic][:sticky] == 1 && current_user.admin?
    @topic.subscriptions.build(:user => current_user) if current_user.auto_subscribe?
    if @topic.save
      flash[:notice] = t(:topic_created)
      redirect_to forum_topic_path(@topic.forum, @topic)
    else
      flash.now[:notice] = t(:topic_not_created)
      render :action => "new"
    end
  end
  
  def edit
    @post = @topic.posts.first
    if !user_has_permission?
      flash[:notice] = t(:not_allowed_to_edit_topic)
      redirect_to forum_topic_path(@forum, @topic)
    end
  end
  
  def update
    if !user_has_permission?
      flash[:notice] = t(:not_allowed_to_edit_topic)
      redirect_to forum_topic_path(@forum, @topic)
    else
      if @topic.update_attributes(params[:topic])
        if @topic.posts.first.update_attributes(params[:topic])
          flash[:notice] = t(:topic_updated)
          redirect_back_or_default forum_topic_path(@forum, @topic)
        else
          flash.now[:notice] = t(:post_not_updated)
          render :action => "edit"
        end
      else
        flash.now[:notice] = t(:topic_not_updated)
        render :action => "edit"
      end
    end
  end
  
  private
  
  def not_found
    flash[:notice] = t(:topic_not_found)
    redirect_to forums_path
  end
  
  private
  
  def find_forum
    topic_options = { :joins => :posts, :include => [:reports, :reports] }
    if params[:forum_id]
      @forum = Forum.find(params[:forum_id], :include => [:topics, :posts])
    else
      @topic = Topic.find(params[:id], topic_options)
      redirect_to forum_topic_path(@topic.forum, @topic) and return
    end
    if @forum.viewable?(current_user)
      @topic = @forum.topics.find(params[:id], topic_options) if params[:id]
    else
      flash[:notice] = t(:not_allowed_to_view_topics)
      redirect_to root_path
    end
    rescue ActiveRecord::RecordNotFound
      not_found
  end
  
  def user_has_permission?
    @topic.belongs_to?(current_user) || current_user.admin?
  end
    
  def create_ip
    @ip = Ip.find_or_create_by_ip(request.remote_addr)
    IpUser.create(:ip => @ip, :user => current_user)
  end
  
end
