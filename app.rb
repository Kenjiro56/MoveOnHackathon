require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'open-uri'
require "sinatra/json"
require './models/models.rb'
require 'sinatra/activerecord'
require "json"

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
    json({ ok:false })
end

error do
    status 500
    json({ ok:false })
end

# ----------------
# Tips
# ----------------

#全てのtipsを返すルーティング
get '/tips/all' do
    tips = Tip.all
    if tips.empty?
        status 204
    else
        tips = add_user_name(tips)
        tips = add_category(tips, "t")
        tips.to_json
    end
end

# 自分が投稿したTipsを返すルーティング
get '/tips/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        tips = Tips.where(user_id: user_id)
        tips = add_user_name(tips)
        tips = add_category(tips, "t")
        tips.to_json
    else
        status 400
        json({ ok: false })
    end
end

#カテゴリーでTipsを絞って返すルーティング
get '/tips/category/:category_id' do
    tips = Tip.find(Refer.find_by(category_id: params[:category_id], c_type: "t").post_id)
    if tips.empty?
        status 204
        json({ ok: false })
    else
        tips.to_json
    end
end

#tipsを作るルーティング
post '/tips/create/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        print(user_id, params[:comment], params[:title])
        created = Tip.create(
            user_id: user_id,
            comment: params[:comment],
            title: params[:title]
        )
        write_category(created.id, params[:categories], "t")
        status 200
        json({ ok: true })
    else
        status 400
        json({ ok: false })
    end
end

#likesを作る
post '/tips/like/create/:user_id' do
    if user_id = firebase_uid_to_uid(params[:user_id])
        if like = Favorite.find_by(tips_id: params[:tips_id])
            like.update(
                good: !like.good
            )
        else
            Favorite.create(
                user_id: user_id,
                tips_id: params[:tips_id],
                good: true
            )
        end
        status 200
        json({ ok: true })
    else
        status 400
        json({ ok: false })
    end
end

# いいね押したか押してないか
get '/tips/like/check/:tips_id/:user_id' do
    if user_id = firebase_uid_to_uid(params[:user_id])
        if like = Favorite.where(tips_id: params[:tips_id].to_i).where(user_id: user_id)
            print(like.to_json,"\n")
            status 200
            json({ like: like[0].good })
        else
            status 200
            json({ like: false })
        end
    else
        status 400
        json({ ok: false })
    end
end

# いいねの数
get '/tips/like/count/:tips_id' do
    if like = Favorite.where(tips_id: params[:tips_id].to_i).where(good: true)
        status 200
        json({ like_count: like.length })
    else
        status 204
        json({ like_count: 0 })
    end
end

# ----------------
# Questions
# ----------------

#questionsを全て返す
get '/questions/all' do
    questions = Question.all
    if questions.empty?
        status 204
    else
        questions = add_user_name(questions)
        questions = add_category(questions, "q")
        questions.to_json
    end
end

# 自分が質問したquestionsを全て返す
get '/questions/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        questions = Question.where(user_id: user_id)
        questions = add_user_name(questions, "q")
        questions.to_json
    else
        status 400
        json({ ok: false })
    end
end

#カテゴリーでQuestionsを絞って返すルーティング
get '/questions/category/:category_id' do
    questions = Question.find(Refer.find_by(category_id: params[:category_id], c_type: "q").post_id)
    if questions.empty?
        status 204
        json({ ok: false })
    else
        tips.to_json
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
        created = Question.create(
            user_id: user_id,
            comment: params[:comment],
            title: params[:title],
            image: img_url,
            bestanswer_id: 0
        )
        write_category(created.id, params[:categories], "q")
        status 200
        json({ ok: true })
    else
        status 400
        json({ ok: false })
    end
end

# answerテーブルを返す
get '/questions/answer/:question_id' do
    if answers = Answer.find_by(question_id: params[:question_id])
        json_f = answers.to_json
        hash_f = JSON.parse json_f
        hash_f["user_name"] = user_name(hash_f['user_id'])
        status 200
        hash_f.to_json
    else
        status 204
        json({ ok: false, status: 204})
    end
end


# answerを作るルーティング
post '/questions/answer/create/:user_id' do
    if firebase_uid_to_uid(params[:user_id])
        user_id = firebase_uid_to_uid(params[:user_id])
        img_url = ''
        if params[:image]
            img = params[:file]
            tempfile = img[:tempfile]
            upload = Cloudinary::Uploader.upload(tempfile.path)
            img_url = upload['url']
        end
        Answer.create(
            user_id: user_id,
            comment: params[:comment],
            question_id: params[:question_id],
            image: img_url
        )
        status 200
        json({ ok: true })
    else
        status 400
        json({ ok: false })
    end
end

#ベストアンサーを作るルーティング
post '/questions/bestanswer/create/:question_id' do
    question = Question.find_by(id: params[:question_id])
    question.update(
        bestanswer_id: params[:answer_id]
    )
    status 200
    json({ ok: true })
end

# ----------------
# User
# ----------------

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
    json({ ok: true })
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

# ----------------
# Test
# ----------------

# テスト用
get '/test/:content' do
    status 200
    json({ ok: true, content: params[:content] })
end

post '/test' do
    status
    json({ ok: true, params: params })
end

# ----------------
# User name
# ----------------

# get user name
def add_user_name(contents)
    json_f = contents.to_json
    hash_f = JSON.parse json_f
    content_f = []
    for doc in hash_f do
        doc["user_name"] = user_name(doc['user_id'])
        content_f.append(doc)
    end
    return content_f
end

def user_name(id)
    user = User.find(id)
    if user != nil
        return user.name
    else
        return nil
    end
end

# ----------------
# Category
# ----------------

#カテゴリー一覧を返す
get '/category/all' do
    categories = Category.all
    if categories.empty?
        status 204
        json({ ok: false })
    else
        categories.to_json
    end
end
# カテゴリーを登録
def write_category(question_id, contents, type)
    if contents == nil
        return
    end
    content_format = contents.split(",")
    for content in content_format do
        check_content = Category.find_by(name: content)
        if check_content == nil
            check_content = Category.create(name: content)
        end
        Refer.create(
            category_id: check_content.id,
            post_id: question_id.to_i,
            c_type: type
        )
    end
end

# カテゴリーを出力
def add_category(contents, type)
    json_format = contents.to_json
    hash_format = JSON.parse json_format
    content_f = []
    for doc in hash_format do
        doc["category"] = create_category_list(doc["id"], type)
        content_f.append(doc)
    end
    return content_f
end

def create_category_list(post_id, type)
    categories_d = Refer.where(post_id: post_id.to_i).where(c_type: type)
    category_output = ""
    if categories_d == nil
        return
    end
    for category in categories_d do
        if search_category_name(category.category_id) != nil
            category_output = category_output + ',' + search_category_name(category.category_id)
        end
    end
    return category_output.slice!(1,1000000000000000000)
end

def search_category_name(id)
    category = Category.find(id)
    if category != nil
        return category.name
    else
        return nil
    end
end