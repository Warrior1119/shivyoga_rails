class CreateSyFormFieldTypes < ActiveRecord::Migration
  def change
    create_table :sy_form_field_types do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
