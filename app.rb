require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'open-uri'
require "sinatra/json"
require './models/models.rb'
require 'sinatra/activerecord'
require 'json'

before do
    Dotenv.load
    Cloudinary.config do |config|
        config.cloud_name =ENV['CLOUC_NAME']
        config.api_key = ENV['CLOUDINARY_API_KEY']
        config.api_secret = ENV['CLOUDINARY_API_SECRET']
    end
end

not_found do
    status 404
end

error do
    status 500
end

#全てのtipsを返すルーティング
get '/tips/all' do
    tips = Tip.all
    if tips.empty?
        status 204
    else
        tips.to_json
    end
end

# 自分が投稿したTipsを返すルーティング
get '/tips/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        tips = Tips.where(user_id: user_id)
        tips.to_json
    else
        status 400
        json({ ok: false })
    end
end

#tipsを作るルーティング
post '/tips/create/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        Tip.create(
            user_id: user_id,
            comment: params[:comment],
            title: params[:title]
        )
        status 200
        json({ ok: true })
    else
        status 400
        json({ ok: false })
    end
end

#likesを作る
post '/tips/like/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        like = Like.find_by(id: params[:id])
        if like.nil?
            Like.create(
                user_id: user_id,
                tips_id: params[:tips_id],
                good: true
            )
            status 200
            json({ ok: true })
        else
            like.update(
                good: !good
            )
        end
    else
        status 400
        json({ ok: false })
    end
end

#questionsを全て返す
get '/questions/all' do
    questions = Question.all
    if questions.empty?
        status 204
    else
        questions.to_json
    end
end

# 自分が質問したquestionsを全て返す
get '/questions/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        questions = Question.where(user_id: user_id)
        questions.to_json
    else
        status 400
        json({ ok: false })
    end
end

#questionsを作るルーティング
post '/questions/create/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        img_url = ''
        if params[:image]
            img = params[:file]
            tempfile = img[:tempfile]
            upload = Cloudinary::Uploader.upload(tempfile.path)
            img_url = upload['url']
        end
        Question.create(
            user_id: user_id,
            comment: params[:comment],
            title: params[:title],
            image: img_url,
            bestanswer_id: 0
        )
        status 200
        json({ ok: true })
    else
        status 400
        json({ ok: false })
    end
end

#referテーブルを作成するルーティング
post '/questions/create/refers/:id' do
    category = Category.find_by(name: params[:name])
    if category.nil?
        Category.create(
            name: params[:name]
        )
    end
    Refer.create(
        post_id: params[:id],
        category_id: Category.find_by(name: params[:name]).id
    )
    json({ ok: true })
end

#usersを作るルーティング
post '/user/create' do
    user = User.find_by(firebase_uid: params[:firebase_uid])
    if user != nil
        user.update(
            firebase_uid: params[:firebase_uid],
            name: params[:name]
        )
    else
        User.create(
            firebase_uid: params[:firebase_uid],
            name: params[:name]
        )
    end
    status 200
    json({ ok: true})
end

# テスト用
get '/test/:content' do
    status 200
    json({ ok: true, content: params[:content] })
end

post '/test' do
    status
    json({ ok: true, params: params })
end

# firebaseのUIDからuserIDを探す
def firebase_uid_to_uid(firebase_uid)
    user = User.find_by(firebase_uid: firebase_uid)
    if user != nil
        return user.id
    else
        return nil
    end
end