class CreateLikes < ActiveRecord::Migration[5.2]
  def change
    create_table :favorites do |t|
      t.integer :user_id
      t.integer :tips_id
      t.boolean :good
    end
  end
end
