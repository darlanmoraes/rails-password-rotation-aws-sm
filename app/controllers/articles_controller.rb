class ArticlesController < ApplicationController
  def index
    @articles = Article.all
  end

  def show
    @article = Article.find(params[:id])
    logger.info "Closing connections"
    ActiveRecord::Base.connection_pool.release_connection
  end
  
  def new
  end

  def create
    @article = Article.new(article_params)
    
    @article.save
    redirect_to @article
  end
      
  private
    def article_params
      params.require(:article).permit(:title, :text)
    end
end
